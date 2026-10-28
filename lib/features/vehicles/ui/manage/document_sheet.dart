import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/actor.dart';
import '../../domain/enums.dart';
import '../../domain/fleet_dates.dart';
import '../../domain/vehicle_document.dart';
import '../../services/fleet_service.dart';
import '../feedback.dart';
import '../widgets/availability_calendar.dart';

/// Ajout ou modification d'un document du véhicule (assurance, visite
/// technique, vignette, carte grise).
Future<void> showDocumentSheet(
  BuildContext context, {
  required String vehicleId,
  VehicleDocument? existing,
  required Set<DocumentType> usedTypes,
}) {
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => _DocumentSheet(
      vehicleId: vehicleId,
      existing: existing,
      usedTypes: usedTypes,
      messenger: messenger,
    ),
  );
}

class _DocumentSheet extends StatefulWidget {
  const _DocumentSheet({
    required this.vehicleId,
    required this.existing,
    required this.usedTypes,
    required this.messenger,
  });

  final String vehicleId;
  final VehicleDocument? existing;
  final Set<DocumentType> usedTypes;
  final ScaffoldMessengerState messenger;

  @override
  State<_DocumentSheet> createState() => _DocumentSheetState();
}

class _DocumentSheetState extends State<_DocumentSheet> {
  late final TextEditingController _reference;
  late final TextEditingController _note;
  DocumentType? _type;
  DateTime? _expiry;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.existing != null;

  List<DocumentType> get _availableTypes => _editing
      ? [widget.existing!.type]
      : DocumentType.values
          .where((t) => !widget.usedTypes.contains(t))
          .toList();

  @override
  void initState() {
    super.initState();
    final doc = widget.existing;
    _reference = TextEditingController(text: doc?.reference ?? '');
    _note = TextEditingController(text: doc?.note ?? '');
    _type = doc?.type ??
        (_availableTypes.isEmpty ? null : _availableTypes.first);
    _expiry = doc?.expiryDate;
  }

  @override
  void dispose() {
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final picked = await showFrenchDatePicker(
      context,
      title: "Date d'expiration",
      initial: _expiry,
    );
    if (picked != null && mounted) setState(() => _expiry = picked);
  }

  Future<void> _save() async {
    final type = _type;
    if (type == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final document = VehicleDocument(
      id: widget.existing?.id,
      vehicleId: widget.vehicleId,
      type: type,
      reference: _reference.text.trim(),
      expiryDate: _expiry,
      note: _note.text.trim(),
    );
    try {
      await FleetService.instance
          .saveDocument(document, const Actor.admin());
      if (!mounted) return;
      Navigator.of(context).pop();
      showFleetSnack(widget.messenger, '${type.label} enregistrée');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = fleetErrorMessage(e);
      });
    }
  }

  Future<void> _delete() async {
    final doc = widget.existing;
    if (doc?.id == null) return;
    final ok = await confirmAction(
      context,
      title: 'Supprimer ce document ?',
      message: '${doc!.type.label} — cette action est définitive.',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await FleetService.instance
          .deleteDocument(doc.id!, const Actor.admin());
      if (!mounted) return;
      Navigator.of(context).pop();
      showFleetSnack(widget.messenger, '${doc.type.label} supprimée');
    } catch (e) {
      if (mounted) setState(() => _error = fleetErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = _type;
    if (type == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 30),
        child: Text('Tous les types de documents sont déjà enregistrés.'),
      );
    }
    final state = _expiry == null
        ? null
        : VehicleDocument(
            vehicleId: widget.vehicleId,
            type: type,
            expiryDate: _expiry,
          ).stateAt(DateTime.now());

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _editing ? 'Modifier le document' : 'Ajouter un document',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _availableTypes)
                ChoiceChip(
                  label: Text(t.label),
                  selected: t == type,
                  showCheckmark: false,
                  selectedColor: AppColors.primaryNavy,
                  labelStyle: TextStyle(
                    color: t == type ? Colors.white : AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                  onSelected: _editing
                      ? null
                      : (_) => setState(() => _type = t),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _reference,
            decoration: _decoration('Référence / numéro'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickExpiry,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              alignment: Alignment.centerLeft,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.event_outlined),
            label: Text(
              _expiry == null
                  ? (type.blocksRentalWhenExpired
                      ? "Date d'expiration (obligatoire)"
                      : "Date d'expiration (facultative)")
                  : 'Expire le ${FleetDates.display(_expiry!)}',
            ),
          ),
          if (state != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: state.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  state.label,
                  style: TextStyle(
                    color: state.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
          if (_expiry != null && !type.blocksRentalWhenExpired)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _expiry = null),
                child: const Text('Sans expiration'),
              ),
            ),
          if (type.blocksRentalWhenExpired) ...[
            const SizedBox(height: 8),
            const Text(
              "Si ce document expire, le véhicule passe automatiquement "
              '« Hors service » et ne peut plus être loué.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLines: 2,
            decoration: _decoration('Note (facultatif)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.redDark, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
          ),
          if (_editing) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _saving ? null : _delete,
              style: TextButton.styleFrom(foregroundColor: AppColors.red),
              child: const Text('Supprimer ce document'),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      );
}
