import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/agency.dart';
import '../../domain/fleet_exceptions.dart';
import '../../domain/validators.dart';
import '../../services/demo_session.dart';
import '../../services/fleet_service.dart';
import '../feedback.dart';
import 'admin_widgets.dart';

/// Villes proposées (gouvernorats + villes touristiques).
const List<String> tunisianCities = [
  'Ariana', 'Béja', 'Ben Arous', 'Bizerte', 'Djerba', 'Gabès', 'Gafsa',
  'Hammamet', 'Jendouba', 'Kairouan', 'Kasserine', 'Kébili', 'La Manouba',
  'Le Kef', 'Mahdia', 'Médenine', 'Monastir', 'Nabeul', 'Sfax',
  'Sidi Bouzid', 'Siliana', 'Sousse', 'Tataouine', 'Tozeur', 'Tunis',
  'Zaghouan',
];

/// Ajout ([agency] null) ou modification d'une agence.
/// Renvoie l'agence enregistrée, ou null si l'utilisateur ferme.
Future<Agency?> showAgencyFormSheet(BuildContext context, {Agency? agency}) {
  return showModalBottomSheet<Agency>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.background,
    builder: (_) => _AgencyFormSheet(agency: agency),
  );
}

class _AgencyFormSheet extends StatefulWidget {
  const _AgencyFormSheet({this.agency});

  final Agency? agency;

  @override
  State<_AgencyFormSheet> createState() => _AgencyFormSheetState();
}

class _AgencyFormSheetState extends State<_AgencyFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _city;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  final FocusNode _cityFocus = FocusNode();

  /// Erreurs renvoyées par le service, affichées sous le bon champ.
  final Map<String, String> _serverErrors = {};
  String? _error;
  bool _saving = false;

  bool get _isEdit => widget.agency != null;

  @override
  void initState() {
    super.initState();
    final a = widget.agency;
    _name = TextEditingController(text: a?.name ?? '');
    _city = TextEditingController(text: a?.city ?? '');
    _address = TextEditingController(text: a?.address ?? '');
    _phone = TextEditingController(text: a?.phone ?? '');
    _email = TextEditingController(text: a?.email ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _address.dispose();
    _phone.dispose();
    _email.dispose();
    _cityFocus.dispose();
    super.dispose();
  }

  void _clearServerError(String field) {
    if (_serverErrors.remove(field) != null) setState(() {});
  }

  Future<void> _save() async {
    setState(() {
      _serverErrors.clear();
      _error = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final service = FleetService.instance;
    final actor = DemoSession.instance.actor;
    try {
      final Agency saved;
      final current = widget.agency;
      if (current == null) {
        saved = await service.createAgency(
          name: _name.text,
          city: _city.text,
          address: _address.text,
          phone: _phone.text,
          email: _email.text,
          actor: actor,
        );
      } else {
        saved = await service.updateAgency(
          current.copyWith(
            name: _name.text,
            city: _city.text,
            address: _address.text,
            phone: _phone.text,
            email: _email.text,
          ),
          actor,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } on FleetValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _serverErrors[e.field] = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = fleetErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminSheetTitle(
              _isEdit ? "Modifier l'agence" : 'Nouvelle agence',
              subtitle: _isEdit
                  ? null
                  : 'Le compte de connexion de l\'agence est créé par le '
                      'module Utilisateurs.',
            ),
            const AdminFieldLabel("Nom de l'agence *"),
            TextFormField(
              controller: _name,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              decoration: adminInputDecoration(
                hint: 'Ex. : Cap Bon Cars',
                errorText: _serverErrors['name'],
              ),
              validator: (v) => FleetValidators.name(v, "Nom de l'agence"),
              onChanged: (_) => _clearServerError('name'),
            ),
            const AdminFieldLabel('Ville *'),
            _CityField(
              controller: _city,
              focusNode: _cityFocus,
              enabled: !_saving,
              errorText: _serverErrors['city'],
              onChanged: () => _clearServerError('city'),
            ),
            const AdminFieldLabel('Adresse'),
            TextFormField(
              controller: _address,
              enabled: !_saving,
              decoration:
                  adminInputDecoration(hint: 'Ex. : Avenue Habib Bourguiba'),
            ),
            const AdminFieldLabel('Téléphone'),
            TextFormField(
              controller: _phone,
              enabled: !_saving,
              keyboardType: TextInputType.phone,
              decoration: adminInputDecoration(
                hint: '+216 71 200 340',
                errorText: _serverErrors['phone'],
              ),
              validator: FleetValidators.phone,
              onChanged: (_) => _clearServerError('phone'),
            ),
            const AdminFieldLabel('E-mail'),
            TextFormField(
              controller: _email,
              enabled: !_saving,
              keyboardType: TextInputType.emailAddress,
              decoration: adminInputDecoration(
                hint: 'contact@agence.tn',
                errorText: _serverErrors['email'],
              ),
              validator: FleetValidators.email,
              onChanged: (_) => _clearServerError('email'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              AdminBanner.error(text: _error!),
            ],
            const SizedBox(height: 20),
            AdminPrimaryButton(
              label: _isEdit ? 'Enregistrer' : "Ajouter l'agence",
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// Champ ville avec suggestions.
class _CityField extends StatelessWidget {
  const _CityField({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.errorText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final String? errorText;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => RawAutocomplete<String>(
        textEditingController: controller,
        focusNode: focusNode,
        optionsBuilder: (value) {
          final query = value.text.trim().toLowerCase();
          if (query.isEmpty) return const Iterable<String>.empty();
          return tunisianCities
              .where((c) => c.toLowerCase().startsWith(query));
        },
        onSelected: (_) => onChanged(),
        fieldViewBuilder: (context, fieldController, fieldFocus, submit) =>
            TextFormField(
          controller: fieldController,
          focusNode: fieldFocus,
          enabled: enabled,
          textCapitalization: TextCapitalization.words,
          decoration:
              adminInputDecoration(hint: 'Ex. : Nabeul', errorText: errorText),
          validator: (v) => FleetValidators.name(v, 'Ville'),
          onChanged: (_) => onChanged(),
          onFieldSubmitted: (_) => submit(),
        ),
        optionsViewBuilder: (context, select, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 220,
                maxWidth: constraints.maxWidth,
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
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
