import 'package:flutter/material.dart';

import '../../domain/enums.dart';

/// Pastille de statut : point de couleur + libellé.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    required this.background,
    this.compact = false,
  });

  /// Statut côté gestion : réservé, loué et contrôle retour s'affichent
  /// tous « Occupé » (le détail appartient au module Réservations).
  factory StatusChip.vehicle(VehicleStatus status, {bool compact = false}) =>
      StatusChip(
        label: status.fleetLabel,
        color: status.fleetColor,
        background: status.fleetBackground,
        compact: compact,
      );

  /// Statut côté client : libre ou occupé en ce moment.
  factory StatusChip.forClient(VehicleStatus status, {bool compact = false}) =>
      status.isOccupied
          ? StatusChip(
              label: 'Occupé en ce moment',
              color: status.fleetColor,
              background: status.fleetBackground,
              compact: compact,
            )
          : StatusChip.vehicle(status, compact: compact);

  factory StatusChip.validation(ValidationStatus validation,
          {bool compact = false}) =>
      StatusChip(
        label: validation.label,
        color: validation.color,
        background: validation.color.withValues(alpha: 0.12),
        compact: compact,
      );

  final String label;
  final Color color;
  final Color background;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
