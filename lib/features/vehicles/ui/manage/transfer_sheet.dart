import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../users/domain/user.dart';
import '../../domain/actor.dart';
import '../../domain/fleet_vehicle.dart';
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

  List<User> _targets = const [];
  Map<int, int> _counts = const {};
  User? _source;
  int? _selectedId;
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
      User? source;
      for (final a in all) {
        if (a.id == widget.vehicle.agencyId) source = a;
      }
      setState(() {
        _source = source;
        _targets = all
            .where((a) => a.id != widget.vehicle.agencyId && a.isActif)
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
        const Actor.admin(),
        comment: comment.isEmpty ? null : comment,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      showFleetSnack(widget.messenger,
          '${widget.vehicle.fullName} transféré vers ${target.displayName}');
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
                '${_source == null ? '' : '\nAgence actuelle : ${_source!.displayName}'}',
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (occupied)
            const AdminBanner(
              color: AppColors.orange,
              background: AppColors.orangeLight,
              icon: Icons.lock_clock_outlined,
              text: 'Ce véhicule est occupé (réservation ou location en cours). '
                  'Attendez son retour pour le transférer.',
            )
          else if (_targets.isEmpty)
            const AdminBanner(
              color: AppColors.textMuted,
              background: AppColors.sectionBg,
              icon: Icons.storefront_outlined,
              text: 'Aucune autre agence active disponible.',
            )
          else ...[
            const Text(
              'Choisir la nouvelle agence',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),
            for (final agency in _targets) ...[
              _AgencyOption(
                agency: agency,
                vehicleCount: _counts[agency.id] ?? 0,
                selected: _selectedId == agency.id,
                onTap: _saving
                    ? null
                    : () => setState(() => _selectedId = agency.id),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _comment,
              decoration: InputDecoration(
                labelText: 'Motif du transfert (facultatif)',
                hintText: 'Ex. renfort haute saison, rééquilibrage de flotte…',
                filled: true,
                fillColor: AppColors.cardSubtleBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.redDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: (_selectedId == null || _saving) ? null : _transfer,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Confirmer le transfert',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ],
          const SizedBox(height: 10),
          if (occupied || _targets.isEmpty)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
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

  final User agency;
  final int vehicleCount;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final initials = agency.displayName.isNotEmpty
        ? agency.displayName.substring(0, 1).toUpperCase()
        : 'A';
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
                  initials,
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
                      agency.displayName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${agency.adresseAgence ?? ''} · $vehicleCount véhicule(s)',
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
