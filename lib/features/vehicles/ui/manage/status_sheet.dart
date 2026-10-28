import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/actor.dart';
import '../../domain/enums.dart';
import '../../domain/fleet_vehicle.dart';
import '../../services/fleet_service.dart';
import '../feedback.dart';

/// Ce que signifie chaque statut, affiché dans le choix.
String statusDescription(VehicleStatus status) => switch (status) {
      VehicleStatus.disponible => 'Le véhicule peut être loué.',
      VehicleStatus.reserve ||
      VehicleStatus.loue ||
      VehicleStatus.controleRetour =>
        'Réservation ou location en cours (module Réservations).',
      VehicleStatus.maintenance => 'Entretien ou réparation en cours.',
      VehicleStatus.horsService => 'Ne peut pas être loué pour le moment.',
      VehicleStatus.archive =>
        "Retiré de la flotte (conservé dans l'historique).",
    };

/// Feuille « Changer le statut » : seuls les statuts autorisés par le
/// cycle de vie sont proposés. « Occupé » (réservé, loué, contrôle retour)
/// n'est jamais proposé : il est posé par le module Réservations.
Future<void> showStatusSheet(BuildContext context, FleetVehicle vehicle) {
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => _StatusSheet(vehicle: vehicle, messenger: messenger),
  );
}

class _StatusSheet extends StatefulWidget {
  const _StatusSheet({required this.vehicle, required this.messenger});

  final FleetVehicle vehicle;
  final ScaffoldMessengerState messenger;

  @override
  State<_StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends State<_StatusSheet> {
  final TextEditingController _comment = TextEditingController();
  VehicleStatus? _selected;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final next = _selected;
    if (next == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await FleetService.instance.changeStatus(
        widget.vehicle.id,
        next,
        const Actor.admin(),
        comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      showFleetSnack(widget.messenger,
          '${widget.vehicle.fullName} : statut « ${next.fleetLabel} »');
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
    final current = widget.vehicle.status;
    final options = current.isOccupied
        ? <VehicleStatus>[]
        : (current.allowedNext.where((s) => !s.isOccupied).toList()
          ..sort((a, b) => a.index.compareTo(b.index)));
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Changer le statut',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Statut actuel : ${current.fleetLabel}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          if (current.isOccupied) ...[
            const _OccupiedNotice(),
            const SizedBox(height: 14),
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
          ] else ...[
            for (final status in options)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _StatusOption(
                  status: status,
                  selected: _selected == status,
                  onTap: () => setState(() => _selected = status),
                ),
              ),
            const SizedBox(height: 6),
            TextField(
              controller: _comment,
              decoration: InputDecoration(
                labelText: 'Commentaire (facultatif)',
                hintText: 'Ex. : vidange faite, pneu crevé…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.redDark, fontSize: 12),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _selected == null || _saving ? null : _apply,
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
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Appliquer'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Explication affichée quand le véhicule est occupé.
class _OccupiedNotice extends StatelessWidget {
  const _OccupiedNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.blueLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.event_available_rounded, color: AppColors.primaryBlue),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ce véhicule est occupé (réservation ou location en cours). '
              'Le module Réservations le libérera automatiquement à la fin.',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusOption extends StatelessWidget {
  const _StatusOption({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final VehicleStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? status.background : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? status.color : AppColors.cardBorderSubtle,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: status.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.label,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusDescription(status),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: status.color),
            ],
          ),
        ),
      ),
    );
  }
}
