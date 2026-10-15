import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/vehicle_image.dart';
import 'repair_details_screen.dart';

class RepairHistoryItem {
  final String id;
  final String vehicleModel;
  final String repairType;
  final String date;
  final int mileage;
  final String garageName;
  final double cost;
  final String status;

  const RepairHistoryItem({
    required this.id,
    required this.vehicleModel,
    required this.repairType,
    required this.date,
    required this.mileage,
    required this.garageName,
    required this.cost,
    this.status = 'Terminé',
  });
}

class RepairHistoryScreen extends StatefulWidget {
  const RepairHistoryScreen({super.key});

  @override
  State<RepairHistoryScreen> createState() => _RepairHistoryScreenState();
}

class _RepairHistoryScreenState extends State<RepairHistoryScreen> {
  String _selectedVehicle = 'Tous';
  String _selectedDateFilter = 'Toutes';

  final List<RepairHistoryItem> _allRepairs = [
    const RepairHistoryItem(
      id: 'REP-001',
      vehicleModel: 'Peugeot 208',
      repairType: 'Remplacement batterie',
      date: '08/10/2026',
      mileage: 92600,
      garageName: 'Garage Auto Plus',
      cost: 320.0,
      status: 'Terminé',
    ),
    const RepairHistoryItem(
      id: 'REP-002',
      vehicleModel: 'Renault Clio',
      repairType: 'Remplacement pneu',
      date: '06/10/2026',
      mileage: 84850,
      garageName: 'Pneu Express',
      cost: 180.0,
      status: 'Terminé',
    ),
    const RepairHistoryItem(
      id: 'REP-003',
      vehicleModel: 'BMW Série 3',
      repairType: 'Changement plaquettes freins',
      date: '28/09/2026',
      mileage: 81200,
      garageName: 'Garage Auto Plus',
      cost: 450.0,
      status: 'Terminé',
    ),
  ];

  String _formatMileage(int km) {
    return km.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]} ',
    );
  }

  void _showVehicleFilter() {
    final vehicles = ['Tous', 'Peugeot 208', 'Renault Clio', 'BMW Série 3'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
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
              ...vehicles.map(
                (v) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
                  title: Text(
                    v,
                    style: TextStyle(
                      color: _selectedVehicle == v ? AppColors.primaryBlue : AppColors.textPrimary,
                      fontWeight: _selectedVehicle == v ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  trailing: _selectedVehicle == v
                      ? const Icon(Icons.check_rounded, color: AppColors.primaryBlue)
                      : null,
                  onTap: () {
                    setState(() => _selectedVehicle = v);
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDateFilter() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2025),
      lastDate: DateTime(2027),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.headerNavyStart,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDateFilter = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var filtered = _allRepairs;
    if (_selectedVehicle != 'Tous') {
      filtered = filtered.where((r) => r.vehicleModel == _selectedVehicle).toList();
    }
    if (_selectedDateFilter != 'Toutes') {
      filtered = filtered.where((r) => r.date == _selectedDateFilter).toList();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            CustomHeader(
              title: 'Historique des réparations',
              subtitle: 'Toutes les réparations',
              showBackButton: true,
              onBack: () => Navigator.of(context).pop(),
            ),

            const SizedBox(height: 6),

            // Two Filter Buttons Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildFilterChip(
                      icon: Icons.directions_car_outlined,
                      label: _selectedVehicle == 'Tous' ? 'Véhicule' : _selectedVehicle,
                      onTap: _showVehicleFilter,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFilterChip(
                      icon: Icons.calendar_today_outlined,
                      label: _selectedDateFilter == 'Toutes' ? 'Date' : _selectedDateFilter,
                      onTap: _showDateFilter,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Repairs List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'Aucune réparation trouvée',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                      physics: const BouncingScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return _buildRepairCard(item);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorderSubtle, width: 1),
          boxShadow: const [AppColors.softShadow],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: AppColors.textPrimary,
              size: 19,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepairCard(RepairHistoryItem item) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const RepairDetailsScreen(),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vehicle Thumbnail
            SizedBox(
              width: 105,
              height: 105,
              child: VehicleImage(
                modelName: item.vehicleModel,
                height: 105,
                width: 105,
                borderRadius: BorderRadius.circular(16),
              ),
            ),

            const SizedBox(width: 14),

            // Details Column
            Expanded(
              child: SizedBox(
                height: 105,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Green "Terminé" badge with dot
                        _buildStatusBadge(item.status),
                        const SizedBox(height: 5),
                        // Vehicle Model
                        Text(
                          item.vehicleModel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Repair Type
                        Text(
                          item.repairType,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Date and Mileage
                        Text(
                          '${item.date} · ${_formatMileage(item.mileage)} km',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),

                    // Bottom Row: Garage name & Price
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          item.garageName,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        Text(
                          '${item.cost.toStringAsFixed(0)} DT',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
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
    );
  }

  Widget _buildStatusBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: Color(0xFF16A34A),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF16A34A),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
