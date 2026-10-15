import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/maintenance_repository.dart';
import '../../models/maintenance_item.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/vehicle_image.dart';
import 'maintenance_form_screen.dart';

class MaintenanceDetailsScreen extends StatefulWidget {
  final MaintenanceItem item;

  const MaintenanceDetailsScreen({
    super.key,
    required this.item,
  });

  @override
  State<MaintenanceDetailsScreen> createState() => _MaintenanceDetailsScreenState();
}

class _MaintenanceDetailsScreenState extends State<MaintenanceDetailsScreen> {
  late MaintenanceItem _item;
  final MaintenanceRepository _repo = MaintenanceRepository();

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _repo.addListener(_onRepoUpdate);
  }

  @override
  void dispose() {
    _repo.removeListener(_onRepoUpdate);
    super.dispose();
  }

  void _onRepoUpdate() {
    final updated = _repo.findById(_item.id);
    if (updated != null && mounted) {
      setState(() {
        _item = updated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            CustomHeader(
              title: 'Détails maintenance',
              subtitle: '#${_item.id}',
              showBackButton: true,
              onBack: () => Navigator.of(context).pop(),
              trailing: PopupMenuButton<String>(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                icon: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cardBorderSubtle, width: 1),
                    boxShadow: const [AppColors.softShadow],
                  ),
                  child: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.primaryNavy,
                    size: 22,
                  ),
                ),
                onSelected: (val) {
                  if (val == 'edit') {
                    _editMaintenance();
                  } else if (val == 'delete') {
                    _confirmDelete();
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 20, color: AppColors.primaryBlue),
                        SizedBox(width: 10),
                        Text('Modifier'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.red),
                        SizedBox(width: 10),
                        Text('Supprimer', style: TextStyle(color: AppColors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero Vehicle Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        height: 200,
                        width: double.infinity,
                        child: VehicleImage(
                          modelName: _item.vehicleModel,
                          height: 200,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Vehicle Identity Card
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StatusBadge.completed(label: _item.statusLabel),
                          const SizedBox(height: 8),
                          Text(
                            _item.vehicleModel,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_item.vehiclePlate} • ${_item.vehicleCategory}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Informations Card (Table style)
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Informations',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildInfoRow('Type', _item.type),
                          const Divider(height: 20),
                          _buildInfoRow('Date', _item.date),
                          const Divider(height: 20),
                          _buildInfoRow(
                            'Kilométrage',
                            '${_item.mileage.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} km',
                          ),
                          const Divider(height: 20),
                          _buildInfoRow(
                            'Coût total',
                            '${_item.cost.toStringAsFixed(0)} DT',
                            isBoldValue: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Travaux effectués Card
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Travaux effectués',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _item.description,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Garage Card
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Garage',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.cyanLight,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.location_on_outlined,
                                  color: AppColors.cyanIcon,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _item.garageName,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _item.garageContact,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // PROCHAINE MAINTENANCE Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.nextMaintenanceBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.nextMaintenanceBorder, width: 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: const [AppColors.softShadow],
                            ),
                            child: const Icon(
                              Icons.calendar_today_rounded,
                              color: AppColors.orangeDark,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PROCHAINE MAINTENANCE',
                                  style: TextStyle(
                                    color: AppColors.orangeDark,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _item.nextMaintenanceDate,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  '${_item.nextMaintenanceMileage.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} km',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge.upcoming(label: 'À venir'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Photos Section
                    const Text(
                      'Photos',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 110,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          SizedBox(
                            width: 160,
                            child: VehicleImage(
                              modelName: _item.vehicleModel,
                              height: 110,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 160,
                            child: VehicleImage(
                              modelName: 'Clio',
                              height: 110,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Edit Action Button at bottom
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _editMaintenance,
                        child: const Text(
                          'Modifier la maintenance',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder, width: 1),
        boxShadow: const [AppColors.softShadow],
      ),
      child: child,
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBoldValue = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: isBoldValue ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _editMaintenance() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaintenanceFormScreen(maintenanceToEdit: _item),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer la maintenance #${_item.id} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              _repo.deleteMaintenance(_item.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Maintenance supprimée')),
              );
            },
            child: const Text('Supprimer', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }
}
