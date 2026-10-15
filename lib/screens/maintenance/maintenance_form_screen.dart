import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/maintenance_repository.dart';
import '../../models/maintenance_item.dart';
import '../../models/vehicle.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/vehicle_image.dart';

class MaintenanceFormScreen extends StatefulWidget {
  final MaintenanceItem? maintenanceToEdit;

  const MaintenanceFormScreen({super.key, this.maintenanceToEdit});

  @override
  State<MaintenanceFormScreen> createState() => _MaintenanceFormScreenState();
}

class _MaintenanceFormScreenState extends State<MaintenanceFormScreen> {
  final MaintenanceRepository _repo = MaintenanceRepository();
  final _formKey = GlobalKey<FormState>();

  late bool _isEditing;
  late Vehicle _selectedVehicle;
  late String _maintenanceType;
  late DateTime _maintenanceDate;
  late TextEditingController _mileageController;
  late TextEditingController _descriptionController;
  late TextEditingController _costController;
  late TextEditingController _garageController;
  late TextEditingController _nextDateController;
  late TextEditingController _nextMileageController;

  final List<String> _typeOptions = [
    'Vidange moteur',
    'Remplacement pneus',
    'Batterie',
    'Freins',
    'Courroie de distribution',
    'Climatisation',
    'Amortisseurs',
    'Révision générale',
  ];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.maintenanceToEdit != null;
    final item = widget.maintenanceToEdit;

    // Pick matching vehicle or default to BMW
    if (item != null) {
      _selectedVehicle = _repo.vehicles.firstWhere(
        (v) => v.id == item.vehicleId || v.brandAndModel == item.vehicleModel,
        orElse: () => _repo.vehicles.first,
      );
      _maintenanceType = item.type;
      _maintenanceDate = DateTime(2026, 10, 12);
      _mileageController = TextEditingController(text: '${item.mileage} km');
      _descriptionController = TextEditingController(text: item.description);
      _costController = TextEditingController(text: '${item.cost.toStringAsFixed(0)} DT');
      _garageController = TextEditingController(text: item.garageName);
      _nextDateController = TextEditingController(text: item.nextMaintenanceDate);
      _nextMileageController = TextEditingController(text: '${item.nextMaintenanceMileage} km');
    } else {
      _selectedVehicle = _repo.vehicles.first;
      _maintenanceType = 'Vidange moteur';
      _maintenanceDate = DateTime.now();
      _mileageController = TextEditingController(text: '${_selectedVehicle.currentMileage} km');
      _descriptionController = TextEditingController(
          text: 'Vidange moteur et remplacement du filtre à huile.');
      _costController = TextEditingController(text: '150 DT');
      _garageController = TextEditingController(text: 'Garage Auto Plus');
      _nextDateController = TextEditingController(text: '15/01/2027');
      _nextMileageController = TextEditingController(text: '90 000 km');
    }
  }

  @override
  void dispose() {
    _mileageController.dispose();
    _descriptionController.dispose();
    _costController.dispose();
    _garageController.dispose();
    _nextDateController.dispose();
    _nextMileageController.dispose();
    super.dispose();
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
              title: _isEditing ? 'Modifier la maintenance' : 'Nouvelle maintenance',
              subtitle: _isEditing ? 'Informations préremplies' : 'Remplir les détails',
              showBackButton: true,
              onBack: () => Navigator.of(context).pop(),
            ),

            // Form Body
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section Véhicule
                      _buildSectionTitle('Véhicule'),
                      const SizedBox(height: 12),
                      _buildFieldLabel('Véhicule *'),
                      const SizedBox(height: 6),
                      _buildVehicleSelector(),
                      const SizedBox(height: 12),
                      _buildSelectedVehicleCard(),

                      const SizedBox(height: 24),

                      // Section Intervention
                      _buildSectionTitle('Intervention'),
                      const SizedBox(height: 12),

                      _buildFieldLabel('Type de maintenance *'),
                      const SizedBox(height: 6),
                      _buildTypeSelector(),

                      const SizedBox(height: 14),

                      _buildFieldLabel('Date de maintenance *'),
                      const SizedBox(height: 6),
                      _buildDatePickerField(),

                      const SizedBox(height: 14),

                      _buildFieldLabel('Kilométrage actuel *'),
                      const SizedBox(height: 6),
                      _buildInputField(
                        controller: _mileageController,
                        hint: '82 450 km',
                      ),

                      const SizedBox(height: 14),

                      _buildFieldLabel('Description'),
                      const SizedBox(height: 6),
                      _buildInputField(
                        controller: _descriptionController,
                        hint: 'Vidange moteur et remplacement du filtre à huile.',
                        maxLines: 4,
                      ),

                      const SizedBox(height: 14),

                      // Row Coût + Garage
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Coût'),
                                const SizedBox(height: 6),
                                _buildInputField(
                                  controller: _costController,
                                  hint: '150 DT',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Garage / technicien'),
                                const SizedBox(height: 6),
                                _buildInputField(
                                  controller: _garageController,
                                  hint: 'Garage Auto Plus',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Section Prochaine maintenance
                      _buildNextMaintenanceSection(),

                      const SizedBox(height: 24),

                      // Section Pièces jointes
                      _buildSectionTitle('Pièces jointes'),
                      const SizedBox(height: 12),
                      _buildUploadArea(),

                      const SizedBox(height: 30),

                      // Submit Button
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
                          onPressed: _saveMaintenance,
                          child: Text(
                            _isEditing ? 'Enregistrer les modifications' : 'Ajouter la maintenance',
                            style: const TextStyle(
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildVehicleSelector() {
    return InkWell(
      onTap: _showVehiclePickerModal,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorderSubtle, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedVehicle.brandAndModel,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
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

  Widget _buildSelectedVehicleCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorderSubtle, width: 1),
        boxShadow: const [AppColors.softShadow],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: VehicleImage(
              modelName: _selectedVehicle.brandAndModel,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedVehicle.brandAndModel,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_selectedVehicle.year} • ${_selectedVehicle.registrationPlate}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          StatusBadge.available(label: 'Disponible'),
        ],
      ),
    );
  }

  void _showVehiclePickerModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
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
                    'Choisir un véhicule',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Divider(),
                ..._repo.vehicles.map((v) {
                  final isSelected = v.id == _selectedVehicle.id;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
                    leading: Icon(
                      Icons.directions_car_filled_rounded,
                      color: isSelected ? AppColors.primaryBlue : AppColors.textSecondary,
                    ),
                    title: Text(
                      v.brandAndModel,
                      style: TextStyle(
                        color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    subtitle: Text('${v.year} • ${v.registrationPlate}'),
                    trailing: isSelected
                        ? const Icon(Icons.check_rounded, color: AppColors.primaryBlue)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedVehicle = v;
                        _mileageController.text = '${v.currentMileage} km';
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

  Widget _buildTypeSelector() {
    return InkWell(
      onTap: _showTypePickerModal,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorderSubtle, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _maintenanceType,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
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

  void _showTypePickerModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
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
                    'Type d\'intervention',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    children: _typeOptions.map((type) {
                      final isSelected = type == _maintenanceType;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
                        title: Text(
                          type,
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
                            _maintenanceType = type;
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDatePickerField() {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorderSubtle, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_maintenanceDate.day} Octobre ${_maintenanceDate.year}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Icon(
              Icons.calendar_today_outlined,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _maintenanceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryBlue,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _maintenanceDate = picked;
      });
    }
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorderSubtle, width: 1),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildNextMaintenanceSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.sectionBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorderSubtle, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Prochaine maintenance',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Date prévue'),
                    const SizedBox(height: 6),
                    _buildInputField(
                      controller: _nextDateController,
                      hint: '15/01/2027',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Kilométrage'),
                    const SizedBox(height: 6),
                    _buildInputField(
                      controller: _nextMileageController,
                      hint: '90 000 km',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUploadArea() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.35),
          style: BorderStyle.solid,
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.blueLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.cloud_upload_outlined,
              color: AppColors.primaryBlue,
              size: 24,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Ajouter des factures ou photos',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'PNG, JPG ou PDF jusqu\'à 10 Mo',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  void _saveMaintenance() {
    final cleanedMileage = int.tryParse(
          _mileageController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        _selectedVehicle.currentMileage;

    final cleanedCost = double.tryParse(
          _costController.text.replaceAll(RegExp(r'[^0-9.]'), ''),
        ) ??
        150.0;

    final cleanedNextMileage = int.tryParse(
          _nextMileageController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        90000;

    if (_isEditing) {
      final current = widget.maintenanceToEdit!;
      final updated = current.copyWith(
        vehicleId: _selectedVehicle.id,
        vehicleModel: _selectedVehicle.brandAndModel,
        vehiclePlate: _selectedVehicle.registrationPlate,
        vehicleCategory: _selectedVehicle.category,
        type: _maintenanceType,
        mileage: cleanedMileage,
        cost: cleanedCost,
        garageName: _garageController.text.trim().isNotEmpty
            ? _garageController.text.trim()
            : current.garageName,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : current.description,
        nextMaintenanceDate: _nextDateController.text.trim().isNotEmpty
            ? _nextDateController.text.trim()
            : current.nextMaintenanceDate,
        nextMaintenanceMileage: cleanedNextMileage,
      );
      _repo.updateMaintenance(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maintenance modifiée avec succès')),
      );
    } else {
      final newItem = MaintenanceItem(
        id: 'MNT-2026-${DateTime.now().millisecondsSinceEpoch % 1000}',
        vehicleId: _selectedVehicle.id,
        vehicleModel: _selectedVehicle.brandAndModel,
        vehiclePlate: _selectedVehicle.registrationPlate,
        vehicleCategory: _selectedVehicle.category,
        type: _maintenanceType,
        date: '${_maintenanceDate.day} Oct ${_maintenanceDate.year}',
        mileage: cleanedMileage,
        cost: cleanedCost,
        garageName: _garageController.text.trim().isNotEmpty
            ? _garageController.text.trim()
            : 'Garage Auto Plus',
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : 'Intervention standard enregistrée.',
        nextMaintenanceDate: _nextDateController.text.trim().isNotEmpty
            ? _nextDateController.text.trim()
            : '15 Jan 2027',
        nextMaintenanceMileage: cleanedNextMileage,
        status: MaintenanceStatus.completed,
      );
      _repo.addMaintenance(newItem);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nouvelle maintenance ajoutée avec succès')),
      );
    }

    Navigator.of(context).pop();
  }
}
