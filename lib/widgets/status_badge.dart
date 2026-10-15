import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

enum BadgeType {
  overdue, // Entretien en retard (Red)
  upcoming, // À venir (Orange)
  completed, // Terminée (Green)
  available, // Disponible (Green)
  critical, // Critique (Red)
  inRepair, // En réparation (Cyan/Blue)
}

class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeType type;

  const StatusBadge({
    super.key,
    required this.label,
    required this.type,
  });

  factory StatusBadge.overdue({String label = 'Entretien en retard'}) {
    return StatusBadge(label: label, type: BadgeType.overdue);
  }

  factory StatusBadge.upcoming({String label = 'À venir'}) {
    return StatusBadge(label: label, type: BadgeType.upcoming);
  }

  factory StatusBadge.completed({String label = 'Terminée'}) {
    return StatusBadge(label: label, type: BadgeType.completed);
  }

  factory StatusBadge.available({String label = 'Disponible'}) {
    return StatusBadge(label: label, type: BadgeType.available);
  }

  factory StatusBadge.critical({String label = 'Critique'}) {
    return StatusBadge(label: label, type: BadgeType.critical);
  }

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color dotColor;
    Color textColor;

    switch (type) {
      case BadgeType.overdue:
      case BadgeType.critical:
        bg = AppColors.redLight;
        dotColor = AppColors.redDark;
        textColor = AppColors.redDark;
        break;
      case BadgeType.upcoming:
        bg = AppColors.orangePillBg;
        dotColor = AppColors.orangeDark;
        textColor = AppColors.orangeDark;
        break;
      case BadgeType.completed:
      case BadgeType.available:
        bg = AppColors.greenLight;
        dotColor = AppColors.greenDark;
        textColor = AppColors.greenDark;
        break;
      case BadgeType.inRepair:
        bg = AppColors.cyanLight;
        dotColor = AppColors.cyanIcon;
        textColor = AppColors.cyanIcon;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
