import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/fleet_dates.dart';
import '../../domain/fleet_exceptions.dart';
import '../../domain/validators.dart';
import '../../domain/vehicle_category.dart';
import '../../services/demo_session.dart';
import '../../services/fleet_service.dart';
import '../feedback.dart';
import 'admin_widgets.dart';

/// Ajout ([category] null) ou modification d'une catégorie.
/// [vehicleCount] : véhicules de la catégorie (affiché en modification).
Future<VehicleCategory?> showCategoryFormSheet(
  BuildContext context, {
  VehicleCategory? category,
  int vehicleCount = 0,
}) {
  return showModalBottomSheet<VehicleCategory>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.background,
    builder: (_) =>
        _CategoryFormSheet(category: category, vehicleCount: vehicleCount),
  );
}

class _CategoryFormSheet extends StatefulWidget {
  const _CategoryFormSheet({this.category, required this.vehicleCount});

  final VehicleCategory? category;
  final int vehicleCount;

  @override
  State<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<_CategoryFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _min;
  late final TextEditingController _max;

  final Map<String, String> _serverErrors = {};
  String? _error;
  bool _saving = false;

  bool get _isEdit => widget.category != null;

  static String _price(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toString().replaceAll('.', ',');

  static double? _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    _name = TextEditingController(text: c?.name ?? '');
    _description = TextEditingController(text: c?.description ?? '');
    _min = TextEditingController(text: c == null ? '' : _price(c.minPricePerDay));
    _max = TextEditingController(text: c == null ? '' : _price(c.maxPricePerDay));
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _clearServerError(String field) {
    if (_serverErrors.remove(field) != null || _error != null) {
      setState(() => _error = null);
    }
  }

  String? _validateMax(String? value) {
    final error = FleetValidators.price(value, label: 'Prix maximum');
    if (error != null) return error;
    final min = _parse(_min.text);
    final max = _parse(value!);
    if (min != null && max != null && max <= min) {
      return 'Doit être supérieur au prix minimum';
    }
    return null;
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
    final min = _parse(_min.text)!;
    final max = _parse(_max.text)!;
    try {
      final VehicleCategory saved;
      final current = widget.category;
      if (current == null) {
        saved = await service.createCategory(
          name: _name.text,
          description: _description.text,
          minPricePerDay: min,
          maxPricePerDay: max,
          actor: actor,
        );
      } else {
        saved = await service.updateCategory(
          current.copyWith(
            name: _name.text,
            description: _description.text,
            minPricePerDay: min,
            maxPricePerDay: max,
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

  Widget _priceField(
    TextEditingController controller, {
    required String field,
    required String hint,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_saving,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: adminInputDecoration(
        hint: hint,
        suffix: 'DT',
        errorText: _serverErrors[field],
      ),
      validator: validator,
      onChanged: (_) => _clearServerError(field),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.category;
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
              _isEdit ? 'Modifier la catégorie' : 'Nouvelle catégorie',
              subtitle: 'La fourchette encadre le prix par jour des '
                  'véhicules de la catégorie.',
            ),
            const AdminFieldLabel('Nom *'),
            TextFormField(
              controller: _name,
              enabled: !_saving,
              textCapitalization: TextCapitalization.sentences,
              decoration: adminInputDecoration(
                hint: 'Ex. : Cabriolet',
                errorText: _serverErrors['name'],
              ),
              validator: (v) => FleetValidators.name(v, 'Nom de la catégorie'),
              onChanged: (_) => _clearServerError('name'),
            ),
            const AdminFieldLabel('Description'),
            TextFormField(
              controller: _description,
              enabled: !_saving,
              maxLines: 2,
              minLines: 1,
              decoration:
                  adminInputDecoration(hint: 'Ex. : Décapotables 2 à 4 places'),
            ),
            const AdminFieldLabel('Prix par jour *'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _priceField(
                    _min,
                    field: 'minPricePerDay',
                    hint: 'Min.',
                    validator: (v) =>
                        FleetValidators.price(v, label: 'Prix minimum'),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                  child: Text('à', style: TextStyle(color: AppColors.textMuted)),
                ),
                Expanded(
                  child: _priceField(
                    _max,
                    field: 'maxPricePerDay',
                    hint: 'Max.',
                    validator: _validateMax,
                  ),
                ),
              ],
            ),
            if (current != null && widget.vehicleCount > 0) ...[
              const SizedBox(height: 12),
              AdminBanner(
                text: '${widget.vehicleCount} véhicule(s) dans cette '
                    'catégorie : la nouvelle fourchette doit inclure leurs '
                    'prix (actuellement ${FleetFormat.dt(current.minPricePerDay)}'
                    ' – ${FleetFormat.dt(current.maxPricePerDay)}).',
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              AdminBanner.error(text: _error!),
            ],
            const SizedBox(height: 20),
            AdminPrimaryButton(
              label: _isEdit ? 'Enregistrer' : 'Ajouter la catégorie',
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
