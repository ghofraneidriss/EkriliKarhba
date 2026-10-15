import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/maintenance_repository.dart';
import '../../models/maintenance_item.dart';
import '../../widgets/custom_app_bar.dart';
import 'maintenance_details_screen.dart';

class MaintenanceHistoryScreen extends StatefulWidget {
  const MaintenanceHistoryScreen({super.key});

  @override
  State<MaintenanceHistoryScreen> createState() => _MaintenanceHistoryScreenState();
}

class _MaintenanceHistoryScreenState extends State<MaintenanceHistoryScreen> {
  final MaintenanceRepository _repo = MaintenanceRepository();
  String _selectedVehicle = 'Tous les véhicules';

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
    var items = _repo.historyMaintenances;
    if (_selectedVehicle != 'Tous les véhicules') {
      items = items.where((m) => m.vehicleModel == _selectedVehicle).toList();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            CustomHeader(
              title: 'Historique des interventions',
              subtitle: 'Toutes les interventions',
              showBackButton: true,
              onBack: () => Navigator.of(context).pop(),
            ),

            const SizedBox(height: 8),

            // Vehicle Selector Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: _buildVehicleFilterCard(),
            ),

            const SizedBox(height: 20),

            // Timeline List of Interventions
            Expanded(
              child: items.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                      physics: const BouncingScrollPhysics(),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final isFirst = index == 0;
                        final isLast = index == items.length - 1;
                        return _buildTimelineItem(
                          item: item,
                          isPrimary: isFirst,
                          isLast: isLast,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleFilterCard() {
    return InkWell(
      onTap: _showVehiclePicker,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.cardBorderSubtle, width: 1),
          boxShadow: const [AppColors.softShadow],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.directions_car_outlined,
              color: AppColors.textPrimary,
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _selectedVehicle,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
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

  void _showVehiclePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final options = ['Tous les véhicules', ..._repo.vehicles.map((v) => v.brandAndModel)];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Text(
                    'Filtrer par véhicule',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Divider(),
                ...options.map((opt) {
                  final isSelected = opt == _selectedVehicle;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
                    leading: Icon(
                      Icons.directions_car_filled_rounded,
                      color: isSelected ? AppColors.primaryBlue : AppColors.textSecondary,
                    ),
                    title: Text(
                      opt,
                      style: TextStyle(
                        color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_rounded, color: AppColors.primaryBlue)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedVehicle = opt;
                      });
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimelineItem({
    required MaintenanceItem item,
    required bool isPrimary,
    required bool isLast,
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
      borderRadius: BorderRadius.circular(16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Timeline Column (Node + Dotted Line)
            SizedBox(
              width: 50,
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isPrimary ? AppColors.darkBlueCard : AppColors.cyanLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.build_rounded,
                      color: isPrimary ? Colors.white : AppColors.cyanIcon,
                      size: 20,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: CustomPaint(
                        painter: _DottedLinePainter(),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Right Information Box
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 28.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.date,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.type,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.mileage.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} km',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.cost.toStringAsFixed(0)} DT',
                            style: const TextStyle(
                              color: AppColors.greenPrice,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: isPrimary ? AppColors.primaryNavy : AppColors.textSecondary,
                        size: 22,
                      ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.history_rounded, size: 64, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Text(
            'Aucune intervention trouvée',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double dashHeight = 4;
    const double dashSpace = 4;
    double startY = 6;
    final paint = Paint()
      ..color = AppColors.cardBorderSubtle
      ..strokeWidth = 2;

    while (startY < size.height - 6) {
      canvas.drawLine(
        Offset(size.width / 2, startY),
        Offset(size.width / 2, startY + dashHeight),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
