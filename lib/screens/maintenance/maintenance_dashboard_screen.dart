import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/maintenance_repository.dart';
import '../../models/maintenance_item.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/vehicle_image.dart';
import 'maintenance_details_screen.dart';
import 'maintenance_history_screen.dart';
import 'maintenance_alerts_screen.dart';
import 'maintenance_list_screen.dart';
import 'vehicle_mileage_screen.dart';
import '../incidents/incident_list_screen.dart';
import '../incidents/incident_details_screen.dart';
import '../incidents/repair_details_screen.dart';
import '../incidents/repair_history_screen.dart';

class MaintenanceDashboardScreen extends StatefulWidget {
  const MaintenanceDashboardScreen({super.key});

  @override
  State<MaintenanceDashboardScreen> createState() => _MaintenanceDashboardScreenState();
}

class _MaintenanceDashboardScreenState extends State<MaintenanceDashboardScreen> {
  final MaintenanceRepository _repo = MaintenanceRepository();

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onRepoUpdate);
  }

  @override
  void dispose() {
    _repo.removeListener(_onRepoUpdate);
    super.dispose();
  }

  void _onRepoUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final urgentItem = _repo.urgentMaintenance;
    final upcomingList = _repo.upcomingMaintenances;
    final recentIncident = _repo.incidents.isNotEmpty ? _repo.incidents.first : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              CustomHeader(
                title: 'Maintenance',
                subtitle: 'Gestion des véhicules',
                trailing: NotificationBellButton(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MaintenanceAlertsScreen(),
                      ),
                    );
                  },
                ),
              ),

              // Fleet Status Banner Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: _buildFleetStatusCard(),
              ),

              // 2x2 Stats Grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: _buildStatsGrid(),
              ),

              const SizedBox(height: 12),

              // Urgent Maintenance Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: _buildSectionHeader(
                  title: 'Maintenance urgente',
                  actionText: 'Toutes les alertes',
                  onAction: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MaintenanceAlertsScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              if (urgentItem != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: _buildUrgentMaintenanceCard(urgentItem),
                ),

              const SizedBox(height: 24),

              // Upcoming Maintenances Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: _buildSectionHeader(
                  title: 'Prochaines maintenances',
                  actionText: 'Voir tout',
                  onAction: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MaintenanceListScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              _buildUpcomingList(upcomingList),

              const SizedBox(height: 24),

              // Recent Incidents Section (Screenshot 2)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: _buildSectionHeader(
                  title: 'Incidents récents',
                  actionText: 'Tous les incidents',
                  onAction: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const IncidentListScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              if (recentIncident != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: _buildRecentIncidentCard(recentIncident),
                ),

              const SizedBox(height: 16),

              // 3 Quick Action Cards (Historique, Kilométrage, Réparations)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: _buildQuickActionRow(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFleetStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.headerNavyStart,
            AppColors.headerNavyEnd,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x25163758),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left texts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'ÉTAT DE LA FLOTTE',
                  style: TextStyle(
                    color: AppColors.textFleetLabel,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_repo.operationalVehicles} véhicules\nopérationnels',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_repo.fleetAvailabilityPercentage}% de votre flotte est disponible',
                  style: const TextStyle(
                    color: AppColors.textFleetSub,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Circular progress ring
          SizedBox(
            width: 74,
            height: 74,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 74,
                  height: 74,
                  child: CircularProgressIndicator(
                    value: _repo.fleetAvailabilityPercentage / 100,
                    strokeWidth: 6.5,
                    backgroundColor: AppColors.tealTrack,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.tealAccent),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_repo.fleetAvailabilityPercentage}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '%',
                      style: TextStyle(
                        color: AppColors.textFleetLabel,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.build_rounded,
                iconColor: AppColors.primaryBlue,
                iconBgColor: AppColors.blueLight,
                value: '${_repo.totalMaintenances}',
                label: 'Maintenances',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MaintenanceListScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                icon: Icons.access_time_rounded,
                iconColor: AppColors.orange,
                iconBgColor: AppColors.orangeLight,
                value: '${_repo.upcomingCount}',
                label: 'À venir',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MaintenanceListScreen()),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.warning_amber_rounded,
                iconColor: AppColors.red,
                iconBgColor: AppColors.redLight,
                value: '${_repo.overdueCount}',
                label: 'En retard',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MaintenanceAlertsScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                icon: Icons.directions_car_rounded,
                iconColor: AppColors.cyanIcon,
                iconBgColor: AppColors.cyanLight,
                value: '${_repo.inRepairCount}',
                label: 'En réparation',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RepairDetailsScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String actionText,
    required VoidCallback onAction,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        InkWell(
          onTap: onAction,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              actionText,
              style: const TextStyle(
                color: AppColors.primaryBlue,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUrgentMaintenanceCard(MaintenanceItem item) {
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
          border: Border.all(color: AppColors.redBorder.withValues(alpha: 0.5), width: 1),
          boxShadow: const [AppColors.softShadow],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Car thumbnail
                SizedBox(
                  width: 64,
                  height: 52,
                  child: VehicleImage(
                    modelName: item.vehicleModel,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 12),
                // Title and badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusBadge.overdue(),
                      const SizedBox(height: 4),
                      Text(
                        item.vehicleModel,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.vehiclePlate,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Metrics row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kilométrage',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.mileage.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} km',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Prévu à',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(item.targetMileage ?? 90000).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} km',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Text(
                  '+${(item.mileage - (item.targetMileage ?? 90000)).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} km',
                  style: const TextStyle(
                    color: AppColors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Dual-color progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 5,
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Container(color: AppColors.red),
                    ),
                    Expanded(
                      flex: 6,
                      child: Container(color: AppColors.cardBorderSubtle),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingList(List<MaintenanceItem> items) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final item = items[index];
          return _buildUpcomingCard(item);
        },
      ),
    );
  }

  Widget _buildUpcomingCard(MaintenanceItem item) {
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
        width: 220,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder, width: 1),
          boxShadow: const [AppColors.softShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with badge overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: SizedBox(
                    height: 100,
                    width: double.infinity,
                    child: VehicleImage(
                      modelName: item.vehicleModel,
                      height: 100,
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x15000000),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: AppColors.orangeDark,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'À venir',
                          style: TextStyle(
                            color: AppColors.orangeDark,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.vehicleModel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.build_rounded,
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.type,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 13,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                item.date,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${item.mileage.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} km',
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentIncidentCard(dynamic incident) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IncidentDetailsScreen(incident: incident),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder, width: 1),
          boxShadow: const [AppColors.softShadow],
        ),
        child: Row(
          children: [
            // Warning Red Box
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.redLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.red,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            // Title and status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusBadge.critical(),
                  const SizedBox(height: 4),
                  Text(
                    incident.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${incident.vehicleModel} • ${incident.timeAgo}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionRow() {
    return Row(
      children: [
        Expanded(
          child: _buildActionPill(
            icon: Icons.history_rounded,
            label: 'Historique',
            iconColor: AppColors.primaryBlue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MaintenanceHistoryScreen(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionPill(
            icon: Icons.speed_rounded,
            label: 'Kilométrage',
            iconColor: AppColors.cyanIcon,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const VehicleMileageScreen(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionPill(
            icon: Icons.build_rounded,
            label: 'Réparations',
            iconColor: AppColors.primaryBlue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RepairHistoryScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionPill({
    required IconData icon,
    required String label,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder, width: 1),
          boxShadow: const [AppColors.softShadow],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
