import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/maintenance_repository.dart';
import '../../models/maintenance_item.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/vehicle_image.dart';
import 'maintenance_details_screen.dart';
import 'maintenance_form_screen.dart';

class MaintenanceListScreen extends StatefulWidget {
  const MaintenanceListScreen({super.key});

  @override
  State<MaintenanceListScreen> createState() => _MaintenanceListScreenState();
}

class _MaintenanceListScreenState extends State<MaintenanceListScreen> {
  final MaintenanceRepository _repo = MaintenanceRepository();
  String _searchQuery = '';
  String _selectedFilter = 'Tous';

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
    var items = _repo.maintenances;

    if (_selectedFilter == 'À venir') {
      items = items.where((m) => m.status == MaintenanceStatus.upcoming).toList();
    } else if (_selectedFilter == 'En retard') {
      items = items.where((m) => m.status == MaintenanceStatus.overdue).toList();
    } else if (_selectedFilter == 'Terminée') {
      items = items.where((m) => m.status == MaintenanceStatus.completed).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      items = items.where((m) {
        return m.vehicleModel.toLowerCase().contains(query) ||
            m.type.toLowerCase().contains(query) ||
            m.vehiclePlate.toLowerCase().contains(query);
      }).toList();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            CustomHeader(
              title: 'Liste des maintenances',
              subtitle: '${items.length} opérations enregistrées',
              showBackButton: true,
              onBack: () => Navigator.of(context).pop(),
              trailing: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MaintenanceFormScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 24),
                ),
              ),
            ),
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorderSubtle),
                  boxShadow: const [AppColors.softShadow],
                ),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher véhicule, type, immatriculation...',
                    hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            // Filter Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
              child: Row(
                children: ['Tous', 'En retard', 'À venir', 'Terminée'].map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedFilter = filter);
                      },
                      selectedColor: AppColors.primaryBlue,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isSelected ? AppColors.primaryBlue : AppColors.cardBorderSubtle,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
            // Maintenance items list
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Text(
                        'Aucune maintenance trouvée',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: InkWell(
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
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.cardBorder),
                                boxShadow: const [AppColors.softShadow],
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 58,
                                    height: 52,
                                    child: VehicleImage(
                                      modelName: item.vehicleModel,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _getStatusBadge(item.status),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.vehicleModel,
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${item.type} • ${item.date}',
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${item.cost.toStringAsFixed(0)} DT',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.textSecondary,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getStatusBadge(MaintenanceStatus status) {
    switch (status) {
      case MaintenanceStatus.overdue:
        return StatusBadge.overdue();
      case MaintenanceStatus.upcoming:
        return StatusBadge.upcoming();
      case MaintenanceStatus.completed:
        return StatusBadge.completed();
      case MaintenanceStatus.inProgress:
        return StatusBadge(label: 'En réparation', type: BadgeType.inRepair);
    }
  }
}
