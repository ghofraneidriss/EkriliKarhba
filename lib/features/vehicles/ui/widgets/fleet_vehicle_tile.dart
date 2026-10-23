import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/enums.dart';
import '../../domain/fleet_dates.dart';
import '../../domain/fleet_vehicle.dart';
import 'status_chip.dart';
import 'vehicle_photo.dart';

/// Carte horizontale d'un véhicule (photo à gauche, infos à droite),
/// d'après la maquette « Gestion des véhicules ».
class FleetVehicleTile extends StatelessWidget {
  const FleetVehicleTile({
    super.key,
    required this.vehicle,
    this.categoryName,
    this.agencyName,
    this.showPlate = true,
    this.showValidation = false,
    this.trailing,
    this.onTap,
  });

  final FleetVehicle vehicle;
  final String? categoryName;
  final String? agencyName;
  final bool showPlate;
  final bool showValidation;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (categoryName != null) categoryName!,
      '${vehicle.year}',
      if (showPlate) vehicle.registrationPlate,
    ].join(' · ');

    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: const [AppColors.softShadow],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 118,
                  // Que des enfants positionnés : la photo ne dicte pas la
                  // hauteur de la carte, elle remplit celle des infos.
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: VehiclePhoto(
                          path: vehicle.mainPhoto,
                          height: double.infinity,
                          borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(20)),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: StatusChip.vehicle(vehicle.status,
                              compact: true),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                vehicle.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (trailing != null) trailing!,
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                        if (agencyName != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.storefront_outlined,
                                  size: 12, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  agencyName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _SpecPill('${vehicle.seats} places'),
                            _SpecPill(vehicle.transmission.shortLabel),
                            _SpecPill(vehicle.fuel.label),
                          ],
                        ),
                        if (showValidation &&
                            vehicle.validation != ValidationStatus.valide) ...[
                          const SizedBox(height: 8),
                          StatusChip.validation(vehicle.validation,
                              compact: true),
                        ],
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              FleetFormat.dt(vehicle.pricePerDay),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Text(
                              ' /jour',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              FleetFormat.km(vehicle.mileage),
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpecPill extends StatelessWidget {
  const _SpecPill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.sectionBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
