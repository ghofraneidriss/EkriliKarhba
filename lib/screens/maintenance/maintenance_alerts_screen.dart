import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/maintenance_repository.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/vehicle_image.dart';
import 'maintenance_details_screen.dart';

class MaintenanceAlertsScreen extends StatelessWidget {
  const MaintenanceAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = MaintenanceRepository();
    final urgentItem = repo.urgentMaintenance;
    final upcoming = repo.upcomingMaintenances;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            CustomHeader(
              title: 'Alertes maintenance',
              subtitle: '${repo.overdueCount} entretiens en retard • ${repo.upcomingCount} à venir',
              showBackButton: true,
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                children: [
                  const Text(
                    'Alertes critiques (Kilométrage dépassé)',
                    style: TextStyle(
                      color: AppColors.redDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (urgentItem != null)
                    _buildAlertCard(
                      context: context,
                      item: urgentItem,
                      isOverdue: true,
                      differenceKm: '+2 450 km',
                    ),
                  const SizedBox(height: 20),
                  const Text(
                    'Alertes programmées à surveiller',
                    style: TextStyle(
                      color: AppColors.orangeDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...upcoming.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _buildAlertCard(
                          context: context,
                          item: item,
                          isOverdue: false,
                          differenceKm: 'Dans 5 000 km',
                        ),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard({
    required BuildContext context,
    required dynamic item,
    required bool isOverdue,
    required String differenceKm,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MaintenanceDetailsScreen(item: item),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isOverdue ? AppColors.redBorder : AppColors.cardBorder,
            width: 1,
          ),
          boxShadow: const [AppColors.softShadow],
        ),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 56,
                  height: 48,
                  child: VehicleImage(
                    modelName: item.vehicleModel,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      isOverdue ? StatusBadge.overdue() : StatusBadge.upcoming(),
                      const SizedBox(height: 4),
                      Text(
                        item.vehicleModel,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        item.vehiclePlate,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  differenceKm,
                  style: TextStyle(
                    color: isOverdue ? AppColors.redDark : AppColors.orangeDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
