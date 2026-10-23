import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/agency.dart';
import '../../domain/fleet_vehicle.dart';
import '../../services/demo_session.dart';
import '../../services/fleet_service.dart';
import '../admin/admin_widgets.dart';
import '../feedback.dart';

/// Feuille « Transférer vers une autre agence » (administrateur).
///
/// Règles (vérifiées par FleetService.transferVehicle) : véhicule ni occupé
/// ni archivé, aucune réservation à venir, agence de destination active.
/// Le transfert est inscrit dans l'historique du véhicule.
Future<void> showTransferSheet(BuildContext context, FleetVehicle vehicle) {
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => _TransferSheet(vehicle: vehicle, messenger: messenger),
  );
}

class _TransferSheet extends StatefulWidget {
  const _TransferSheet({required this.vehicle, required this.messenger});

  final FleetVehicle vehicle;
  final ScaffoldMessengerState messenger;

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  final FleetService _service = FleetService.instance;
  final TextEditingController _comment = TextEditingController();

  List<Agency> _targets = const [];
  Map<String, int> _counts = const {};
  Agency? _source;
  String? _selectedId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAgencies();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _loadAgencies() async {
    try {
      final all = await _service.agencies();
      final counts = await _service.vehicleCountByAgency();
      if (!mounted) return;
      Agency? source;
      for (final a in all) {
        if (a.id == widget.vehicle.agencyId) source = a;
      }
      setState(() {
        _source = source;
        _targets = all
            .where((a) => a.id != widget.vehicle.agencyId && a.isActive)
            .toList();
        _counts = counts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = fleetErrorMessage(e);
      });
    }
  }

  Future<void> _transfer() async {
    final targetId = _selectedId;
    if (targetId == null) return;
    final target = _targets.firstWhere((a) => a.id == targetId);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final comment = _comment.text.trim();
      await _service.transferVehicle(
        widget.vehicle.id,
        targetId,
        DemoSession.instance.actor,
        comment: comment.isEmpty ? null : comment,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      showFleetSnack(widget.messenger,
          '${widget.vehicle.fullName} transféré vers ${target.name}');
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
    final vehicle = widget.vehicle;
    final occupied = vehicle.status.isOccupied;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminSheetTitle(
            'Transférer le véhicule',
            subtitle: '${vehicle.fullName} · ${vehicle.registrationPlate}'
                '${_source == null ? '' : '\nAgence actuelle : ${_source!.name}'}',
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (occupied)
            const AdminBanner(
              text: 'Ce véhicule est occupé (réservation ou location en '
                  'cours) : le transfert sera possible quand il sera libre.',
            )
          else if (_targets.isEmpty)
            const AdminBanner(
              text: 'Aucune autre agence active pour le moment. Ajoutez ou '
                  'réactivez une agence dans « Agences ».',
            )
          else ...[
            const Text(
              "Choisissez l'agence de destination",
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (final agency in _targets)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AgencyOption(
                  agency: agency,
                  vehicleCount: _counts[agency.id] ?? 0,
                  selected: _selectedId == agency.id,
                  onTap: _saving
                      ? null
                      : () => setState(() => _selectedId = agency.id),
                ),
              ),
            const AdminFieldLabel('Commentaire (facultatif)'),
            TextField(
              controller: _comment,
              enabled: !_saving,
              decoration: adminInputDecoration(
                  hint: 'Ex. : forte demande à Sousse cet été'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            AdminBanner.error(text: _error!),
          ],
          const SizedBox(height: 16),
          if (!_loading && !occupied && _targets.isNotEmpty)
            AdminPrimaryButton(
              label: 'Transférer',
              icon: Icons.swap_horiz_rounded,
              loading: _saving,
              onPressed: _selectedId == null ? null : _transfer,
            )
          else
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Fermer'),
            ),
        ],
      ),
    );
  }
}

class _AgencyOption extends StatelessWidget {
  const _AgencyOption({
    required this.agency,
    required this.vehicleCount,
    required this.selected,
    required this.onTap,
  });

  final Agency agency;
  final int vehicleCount;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.blueLight : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primaryBlue : AppColors.cardBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryNavy,
                child: Text(
                  agency.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agency.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${agency.city} · $vehicleCount véhicule(s)',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? AppColors.primaryBlue : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
