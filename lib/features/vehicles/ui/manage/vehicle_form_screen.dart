import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/brand_catalog.dart';
import '../../../users/domain/user.dart';
import '../../domain/actor.dart';
import '../../domain/enums.dart';
import '../../domain/fleet_dates.dart';
import '../../domain/fleet_exceptions.dart';
import '../../domain/fleet_vehicle.dart';
import '../../domain/validators.dart';
import '../../domain/vehicle_category.dart';
import '../../services/fleet_service.dart';
import '../feedback.dart';
import 'photo_picker_field.dart';

/// Résultat renvoyé à l'écran précédent.
enum VehicleFormResult { saved, deleted }

/// Formulaire « Ajouter un véhicule » / « Modifier le véhicule »
/// (agence ou administrateur), d'après la maquette Figma.
class VehicleFormScreen extends StatefulWidget {
  const VehicleFormScreen({super.key, this.vehicleId});

  /// Null pour un ajout.
  final String? vehicleId;

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  static const Set<String> _formFields = {
    'brand',
    'model',
    'registrationPlate',
    'year',
    'categoryId',
    'pricePerDay',
    'deposit',
    'mileage',
    'seats',
    'doors',
  };

  final FleetService _service = FleetService.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _brand = TextEditingController();
  final FocusNode _brandFocus = FocusNode();
  final TextEditingController _model = TextEditingController();
  final FocusNode _modelFocus = FocusNode();
  final TextEditingController _plate = TextEditingController();
  final TextEditingController _year = TextEditingController();
  final TextEditingController _mileage = TextEditingController();
  final TextEditingController _seats = TextEditingController();
  final TextEditingController _doors = TextEditingController();
  final TextEditingController _color = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final TextEditingController _deposit = TextEditingController();
  final TextEditingController _description = TextEditingController();

  String? _categoryId;
  int? _agencyId;
  FuelType _fuel = FuelType.essence;
  Transmission _transmission = Transmission.manuelle;
  VehicleStatus _initialStatus = VehicleStatus.disponible;
  List<String> _photos = [];

  FleetVehicle? _original;
  List<VehicleCategory> _categories = const [];
  List<User> _agencies = const [];
  List<String> _makes = BrandCatalog.popular.keys.toList();
  List<String> _models = const [];

  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _loadError;
  final Map<String, String> _serverErrors = {};
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  Actor get _actor => const Actor.admin();
  bool get _editing => widget.vehicleId != null;

  VehicleCategory? get _selectedCategory {
    for (final c in _categories) {
      if (c.id == _categoryId) return c;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _brandFocus.addListener(() {
      if (!_brandFocus.hasFocus) _loadModels(_brand.text);
    });
    _load();
    BrandCatalog.instance.makes().then((makes) {
      if (mounted) setState(() => _makes = makes);
    });
  }

  @override
  void dispose() {
    for (final c in [
      _brand,
      _model,
      _plate,
      _year,
      _mileage,
      _seats,
      _doors,
      _color,
      _price,
      _deposit,
      _description,
    ]) {
      c.dispose();
    }
    _brandFocus.dispose();
    _modelFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final categories = await _service.categories();
      final agencies = _actor.isAdmin
          ? await _service.agencies(activeOnly: true)
          : const <User>[];
      FleetVehicle? original;
      if (_editing) {
        original = await _service.getVehicleFor(widget.vehicleId!, _actor);
        if (original == null) {
          throw const FleetNotFoundException('Véhicule introuvable.');
        }
      }
      if (!mounted) return;
      setState(() {
        _original = original;
        _categories = categories
            .where((c) => c.isActive || c.id == original?.categoryId)
            .toList();
        _agencies = agencies;
        if (original != null) {
          _fill(original);
        } else {
          _year.text = '${DateTime.now().year}';
          _seats.text = '5';
          _doors.text = '5';
          _mileage.text = '0';
          _agencyId = agencies.isEmpty ? null : agencies.first.id;
        }
        _loading = false;
      });
      if (original != null) _loadModels(original.brand);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = fleetErrorMessage(e);
      });
    }
  }

  void _fill(FleetVehicle v) {
    _brand.text = v.brand;
    _model.text = v.model;
    _plate.text = v.registrationPlate;
    _year.text = '${v.year}';
    _mileage.text = '${v.mileage}';
    _seats.text = '${v.seats}';
    _doors.text = '${v.doors}';
    _color.text = v.color;
    _price.text = _amountText(v.pricePerDay);
    _deposit.text = _amountText(v.deposit);
    _description.text = v.description;
    _categoryId = v.categoryId;
    _agencyId = v.agencyId;
    _fuel = v.fuel;
    _transmission = v.transmission;
    _photos = [...v.photos];
  }

  static String _amountText(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1).replaceAll('.', ',');

  static double _parseAmount(String text) =>
      double.parse(text.trim().replaceAll(',', '.'));

  Future<void> _loadModels(String brand) async {
    if (brand.trim().isEmpty) return;
    final models = await BrandCatalog.instance.models(brand);
    if (!mounted) return;
    if (_brand.text.trim().toLowerCase() != brand.trim().toLowerCase()) return;
    setState(() => _models = models);
  }

  void _clearServerError(String field) {
    if (_serverErrors.remove(field) != null) setState(() {});
  }

  String? _priceValidator(String? value) {
    final server = _serverErrors['pricePerDay'];
    if (server != null) return server;
    final error = FleetValidators.price(value);
    if (error != null) return error;
    final category = _selectedCategory;
    if (category != null &&
        !category.acceptsPrice(_parseAmount(value!))) {
      return 'Entre ${FleetFormat.dt(category.minPricePerDay)} et '
          '${FleetFormat.dt(category.maxPricePerDay)} pour ${category.name}';
    }
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    _serverErrors.clear();
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final original = _original;
    final agencyId = original?.agencyId ??
        (_actor.isAdmin ? _agencyId : _actor.agencyId);
    if (agencyId == null) {
      showFleetSnack(messenger, 'Choisissez une agence.', error: true);
      return;
    }
    final now = DateTime.now();
    final draft = FleetVehicle(
      id: original?.id ?? 'nouveau',
      agencyId: agencyId,
      categoryId: _categoryId!,
      brand: _brand.text.trim(),
      model: _model.text.trim(),
      year: int.parse(_year.text.trim()),
      registrationPlate: _plate.text,
      color: _color.text.trim(),
      fuel: _fuel,
      transmission: _transmission,
      seats: int.parse(_seats.text.trim()),
      doors: int.parse(_doors.text.trim()),
      mileage: int.parse(_mileage.text.replaceAll(' ', '').trim()),
      pricePerDay: _parseAmount(_price.text),
      deposit:
          _deposit.text.trim().isEmpty ? 0 : _parseAmount(_deposit.text),
      status: original?.status ?? _initialStatus,
      validation: original?.validation ?? ValidationStatus.enAttente,
      rejectionReason: original?.rejectionReason,
      description: _description.text.trim(),
      photos: _photos,
      createdAt: original?.createdAt ?? now,
      updatedAt: now,
    );

    setState(() => _saving = true);
    try {
      final saved = original == null
          ? await _service.createVehicle(draft, _actor)
          : await _service.updateVehicle(draft, _actor);
      _dirty = false;
      if (!mounted) return;
      Navigator.of(context).pop(VehicleFormResult.saved);
      final String message;
      if (original != null) {
        message = saved.validation == ValidationStatus.enAttente &&
                original.validation == ValidationStatus.refuse
            ? 'Modifications enregistrées — renvoyé à la validation'
            : 'Modifications enregistrées';
      } else if (saved.validation == ValidationStatus.valide) {
        message = '${saved.fullName} ajouté à la flotte';
      } else {
        message = "${saved.fullName} ajouté — en attente de validation "
            "par l'administrateur";
      }
      showFleetSnack(messenger, message);
    } on FleetValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _serverErrors[e.field] = e.message;
        _autovalidate = AutovalidateMode.onUserInteraction;
      });
      _formKey.currentState!.validate();
      if (!_formFields.contains(e.field)) {
        showFleetSnack(messenger, e.message, error: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showFleetSnack(messenger, fleetErrorMessage(e), error: true);
    }
  }

  Future<void> _delete() async {
    final original = _original;
    if (original == null) return;
    final ok = await confirmAction(
      context,
      title: 'Supprimer ce véhicule ?',
      message: '${original.fullName} (${original.registrationPlate}) sera '
          "retiré de la flotte. L'historique est conservé.",
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.deleteVehicle(original.id, _actor);
      _dirty = false;
      if (!mounted) return;
      Navigator.of(context).pop(VehicleFormResult.deleted);
      showFleetSnack(messenger, '${original.fullName} supprimé');
    } catch (e) {
      showFleetSnack(messenger, fleetErrorMessage(e), error: true);
    }
  }

  Future<void> _confirmLeave() async {
    final leave = await confirmAction(
      context,
      title: 'Quitter sans enregistrer ?',
      message: 'Vos modifications seront perdues.',
      confirmLabel: 'Quitter',
      destructive: true,
    );
    if (leave && mounted) Navigator.of(context).pop();
  }

  // ------------------------------------------------------------- Affichage

  @override
  Widget build(BuildContext context) {
    final title = _editing ? 'Modifier le véhicule' : 'Ajouter un véhicule';
    if (_loading || _loadError != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_loadError!, textAlign: TextAlign.center),
                ),
        ),
      );
    }

    return PopScope<Object?>(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'Informations de la flotte',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        body: Form(
          key: _formKey,
          autovalidateMode: _autovalidate,
          onChanged: () {
            if (!_dirty) setState(() => _dirty = true);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              if (_original?.validation == ValidationStatus.refuse) ...[
                _Banner(
                  text: 'Refusé par l\'administrateur : '
                      '${_original?.rejectionReason ?? ''}\n'
                      'Corrigez puis enregistrez : le véhicule sera renvoyé '
                      'à la validation.',
                ),
                const SizedBox(height: 14),
              ],
              PhotoPickerField(
                photos: _photos,
                onChanged: (photos) => setState(() {
                  _photos = photos;
                  _dirty = true;
                }),
              ),
              const SizedBox(height: 18),
              if (_actor.isAdmin && !_editing) ...[
                _label('Agence *'),
                DropdownButtonFormField<int>(
                  initialValue: _agencyId,
                  isExpanded: true,
                  decoration: _decoration(),
                  items: [
                    for (final a in _agencies)
                      DropdownMenuItem(
                        value: a.id,
                        child: Text('${a.displayName} · ${a.adresseAgence ?? ''}'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _agencyId = v),
                  validator: (v) => v == null ? 'Choisissez une agence' : null,
                ),
                const SizedBox(height: 14),
              ],
              _pair(
                _field(
                  'Marque *',
                  _autocomplete(
                    controller: _brand,
                    focusNode: _brandFocus,
                    hint: 'Ex. : Peugeot',
                    options: () => _makes,
                    validator: (v) =>
                        _serverErrors['brand'] ??
                        FleetValidators.name(v, 'Marque'),
                    onSelected: (value) {
                      _clearServerError('brand');
                      _model.clear();
                      _loadModels(value);
                    },
                  ),
                ),
                _field(
                  'Modèle *',
                  _autocomplete(
                    controller: _model,
                    focusNode: _modelFocus,
                    hint: 'Ex. : 208',
                    options: () => _models,
                    validator: (v) =>
                        _serverErrors['model'] ??
                        FleetValidators.name(v, 'Modèle'),
                    onSelected: (_) => _clearServerError('model'),
                  ),
                ),
              ),
              _field(
                'Matricule *',
                TextFormField(
                  controller: _plate,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[0-9a-zA-Z ]')),
                  ],
                  decoration: _decoration(hint: '234 TUN 1987'),
                  onChanged: (_) => _clearServerError('registrationPlate'),
                  validator: (v) =>
                      _serverErrors['registrationPlate'] ??
                      FleetValidators.registrationPlate(v),
                ),
              ),
              _pair(
                _field(
                  'Catégorie *',
                  DropdownButtonFormField<String>(
                    initialValue: _categoryId,
                    isExpanded: true,
                    decoration: _decoration(),
                    items: [
                      for (final c in _categories)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      _categoryId = v;
                      _serverErrors
                        ..remove('categoryId')
                        ..remove('pricePerDay');
                    }),
                    validator: (v) =>
                        _serverErrors['categoryId'] ??
                        (v == null ? 'Choisissez une catégorie' : null),
                  ),
                ),
                _field(
                  'Année *',
                  _numberField(
                    _year,
                    hint: '2024',
                    validator: (v) =>
                        _serverErrors['year'] ?? FleetValidators.year(v),
                  ),
                ),
              ),
              _pair(
                _field(
                  'Carburant',
                  DropdownButtonFormField<FuelType>(
                    initialValue: _fuel,
                    isExpanded: true,
                    decoration: _decoration(),
                    items: [
                      for (final f in FuelType.values)
                        DropdownMenuItem(value: f, child: Text(f.label)),
                    ],
                    onChanged: (v) => setState(() => _fuel = v ?? _fuel),
                  ),
                ),
                _field(
                  'Transmission',
                  DropdownButtonFormField<Transmission>(
                    initialValue: _transmission,
                    isExpanded: true,
                    decoration: _decoration(),
                    items: [
                      for (final t in Transmission.values)
                        DropdownMenuItem(value: t, child: Text(t.label)),
                    ],
                    onChanged: (v) =>
                        setState(() => _transmission = v ?? _transmission),
                  ),
                ),
              ),
              _pair(
                _field(
                  'Kilométrage *',
                  _numberField(
                    _mileage,
                    hint: '82450',
                    suffix: 'km',
                    validator: (v) =>
                        _serverErrors['mileage'] ?? FleetValidators.mileage(v),
                  ),
                ),
                _field(
                  'Places *',
                  _numberField(
                    _seats,
                    hint: '5',
                    validator: (v) =>
                        _serverErrors['seats'] ?? FleetValidators.seats(v),
                  ),
                ),
              ),
              _pair(
                _field(
                  'Portes *',
                  _numberField(
                    _doors,
                    hint: '5',
                    validator: (v) =>
                        _serverErrors['doors'] ?? FleetValidators.doors(v),
                  ),
                ),
                _field(
                  'Couleur',
                  TextFormField(
                    controller: _color,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _decoration(hint: 'Ex. : Blanc'),
                  ),
                ),
              ),
              _pair(
                _field(
                  'Prix / jour *',
                  TextFormField(
                    controller: _price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
                    ],
                    decoration: _decoration(hint: '180', suffix: 'DT'),
                    onChanged: (_) => _clearServerError('pricePerDay'),
                    validator: _priceValidator,
                  ),
                ),
                _field(
                  'Caution',
                  TextFormField(
                    controller: _deposit,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
                    ],
                    decoration: _decoration(hint: '800', suffix: 'DT'),
                    validator: (v) =>
                        _serverErrors['deposit'] ?? FleetValidators.deposit(v),
                  ),
                ),
              ),
              if (_selectedCategory != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    '${_selectedCategory!.name} : prix autorisé entre '
                    '${FleetFormat.dt(_selectedCategory!.minPricePerDay)} et '
                    '${FleetFormat.dt(_selectedCategory!.maxPricePerDay)} '
                    'par jour.',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
              if (!_editing) ...[
                _label('Statut de départ'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final s in const [
                      VehicleStatus.disponible,
                      VehicleStatus.maintenance,
                      VehicleStatus.horsService,
                    ])
                      ChoiceChip(
                        label: Text(s.label),
                        selected: _initialStatus == s,
                        showCheckmark: false,
                        selectedColor: s.background,
                        side: BorderSide(
                          color: _initialStatus == s
                              ? s.color
                              : AppColors.cardBorderSubtle,
                        ),
                        labelStyle: TextStyle(
                          color: _initialStatus == s
                              ? s.color
                              : AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (_) => setState(() => _initialStatus = s),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              _field(
                'Description',
                TextFormField(
                  controller: _description,
                  maxLines: 4,
                  minLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _decoration(hint: 'Décrivez le véhicule…'),
                ),
              ),
              if (!_editing && !_actor.isAdmin)
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Text(
                    "Le véhicule sera visible des clients après validation "
                    "par l'administrateur.",
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_editing
                        ? 'Enregistrer les modifications'
                        : 'Enregistrer le véhicule'),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
                child: const Text('Annuler'),
              ),
              if (_editing) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _delete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    side: const BorderSide(color: AppColors.redBorder),
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Supprimer le véhicule'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _field(String label, Widget input) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_label(label), input],
        ),
      );

  Widget _pair(Widget left, Widget right) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 12),
          Expanded(child: right),
        ],
      );

  InputDecoration _decoration({String? hint, String? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        suffixText: suffix,
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primaryBlue),
        ),
      );

  Widget _numberField(
    TextEditingController controller, {
    required String hint,
    String? suffix,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: _decoration(hint: hint, suffix: suffix),
      validator: validator,
    );
  }

  Widget _autocomplete({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required List<String> Function() options,
    required String? Function(String?) validator,
    required ValueChanged<String> onSelected,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) => RawAutocomplete<String>(
        textEditingController: controller,
        focusNode: focusNode,
        optionsBuilder: (value) {
          final query = value.text.trim().toLowerCase();
          final all = options();
          if (query.isEmpty) return all.take(30);
          return all.where((o) => o.toLowerCase().contains(query)).take(30);
        },
        onSelected: onSelected,
        fieldViewBuilder: (context, fieldController, fieldFocus, submit) =>
            TextFormField(
          controller: fieldController,
          focusNode: fieldFocus,
          textCapitalization: TextCapitalization.words,
          decoration: _decoration(hint: hint),
          validator: validator,
          onFieldSubmitted: (_) => submit(),
        ),
        optionsViewBuilder: (context, select, items) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 240,
                maxWidth: constraints.maxWidth,
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final option = items.elementAt(index);
                  return InkWell(
                    onTap: () => select(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Text(option),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.redLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.report_gmailerrorred_rounded,
              color: AppColors.redDark, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.redDark,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
