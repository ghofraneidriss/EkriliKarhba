import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../users/domain/user.dart';
import '../../domain/document_alert.dart';
import '../../domain/fleet_vehicle.dart';

/// Couleurs d'une alerte : rouge si expiré, orange sinon.
Color alertColor(DocumentAlert alert) =>
    alert.expired ? AppColors.redDark : AppColors.orange;

Color alertBackground(DocumentAlert alert) =>
    alert.expired ? AppColors.redLight : AppColors.orangeLight;

/// Liste complète des notifications « papiers » : quel véhicule, quel
/// document, et dans combien de jours il expire.
/// [agencies] non vide : le nom de l'agence est affiché (vue admin).
Future<void> showDocumentAlertsSheet(
  BuildContext context, {
  required List<DocumentAlert> alerts,
  Map<int, User> agencies = const {},
  required void Function(FleetVehicle vehicle) onOpenVehicle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: alerts.length > 4 ? 0.85 : 0.6,
      child: _DocumentAlertsSheet(
        alerts: alerts,
        agencies: agencies,
        onOpenVehicle: (vehicle) {
          Navigator.of(sheetContext).pop();
          onOpenVehicle(vehicle);
        },
      ),
    ),
  );
}

class _DocumentAlertsSheet extends StatelessWidget {
  const _DocumentAlertsSheet({
    required this.alerts,
    required this.agencies,
    required this.onOpenVehicle,
  });

  final List<DocumentAlert> alerts;
  final Map<int, User> agencies;
  final void Function(FleetVehicle vehicle) onOpenVehicle;

  @override
  Widget build(BuildContext context) {
    final expired = alerts.where((a) => a.expired).toList();
    final soon = alerts.where((a) => !a.expired).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Text(
            'Papiers des véhicules',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            'Documents expirés ou qui expirent dans les 30 prochains jours.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
        Expanded(
          child: alerts.isEmpty
              ? const _EmptyAlerts()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    if (expired.isNotEmpty) ...[
                      _SectionLabel('Expirés (${expired.length})',
                          color: AppColors.redDark),
                      for (final alert in expired) _row(alert),
                    ],
                    if (soon.isNotEmpty) ...[
                      _SectionLabel('Expirent bientôt (${soon.length})',
                          color: AppColors.orange),
                      for (final alert in soon) _row(alert),
                    ],
                    const SizedBox(height: 8),
                    const Text(
                      'Assurance ou visite technique expirée : le véhicule '
                      'passe automatiquement « Hors service » et ne peut plus '
                      'être loué. Ouvrez le véhicule pour mettre à jour le '
                      'document.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _row(DocumentAlert alert) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DocumentAlertRow(
        alert: alert,
        agencyName: agencies[alert.vehicle.agencyId]?.displayName,
        onTap: () => onOpenVehicle(alert.vehicle),
      ),
    );
  }
}

/// Une notification : véhicule, matricule, document et délai.
class DocumentAlertRow extends StatelessWidget {
  const DocumentAlertRow({
    super.key,
    required this.alert,
    this.agencyName,
    this.onTap,
    this.dense = false,
  });

  final DocumentAlert alert;
  final String? agencyName;
  final VoidCallback? onTap;

  /// Version compacte (dans la carte de notification).
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = alertColor(alert);
    final vehicle = alert.vehicle;
    final title = agencyName == null
        ? '${vehicle.fullName} · ${vehicle.registrationPlate}'
        : '${vehicle.fullName} · ${vehicle.registrationPlate} · $agencyName';
    return Material(
      color: dense ? Colors.transparent : alertBackground(alert),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: dense
              ? const EdgeInsets.symmetric(vertical: 6)
              : const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: dense ? 32 : 38,
                height: dense ? 32 : 38,
                decoration: BoxDecoration(
                  color: dense ? alertBackground(alert) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  alert.expired
                      ? Icons.error_outline_rounded
                      : Icons.schedule_rounded,
                  size: dense ? 18 : 20,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      alert.summary,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyAlerts extends StatelessWidget {
  const _EmptyAlerts();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_outlined, size: 44, color: AppColors.green),
            SizedBox(height: 10),
            Text(
              'Tous les papiers sont à jour',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Aucun document n\'expire dans les 30 prochains jours.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
