import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/maintenance_repository.dart';
import '../../models/incident_item.dart';
import '../../models/vehicle.dart';
import '../../widgets/custom_app_bar.dart';

class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final MaintenanceRepository _repo = MaintenanceRepository();
  late Vehicle _vehicle;
  final _titleController = TextEditingController();
  final _mileageController = TextEditingController();
  final _locationController = TextEditingController();
  final _descController = TextEditingController();
  IncidentSeverity _severity = IncidentSeverity.elevee;
  bool _isImmobilized = false;

  @override
  void initState() {
    super.initState();
    _vehicle = _repo.vehicles.first;
    _mileageController.text = '${_vehicle.currentMileage} km';
    _locationController.text = 'Tunis';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _mileageController.dispose();
    _locationController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            CustomHeader(
              title: 'Signaler un incident',
              subtitle: 'Déclaration d\'anomalie ou de panne',
              showBackButton: true,
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Véhicule concerné *'),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorderSubtle),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Vehicle>(
                          isExpanded: true,
                          value: _vehicle,
                          items: _repo.vehicles.map((v) {
                            return DropdownMenuItem(
                              value: v,
                              child: Text('${v.brandAndModel} (${v.registrationPlate})'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _vehicle = val;
                                _mileageController.text = '${val.currentMileage} km';
                              });
                            }
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    _buildLabel('Intitulé de l\'incident *'),
                    const SizedBox(height: 6),
                    _buildTextField(_titleController, 'Ex: Bruit suspect au freinage'),

                    const SizedBox(height: 14),

                    _buildLabel('Gravité *'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildSeverityChip(IncidentSeverity.critique, 'Critique', AppColors.red),
                        const SizedBox(width: 8),
                        _buildSeverityChip(IncidentSeverity.elevee, 'Élevée', AppColors.orangeDark),
                        const SizedBox(width: 8),
                        _buildSeverityChip(IncidentSeverity.moyenne, 'Moyenne', AppColors.primaryBlue),
                      ],
                    ),

                    const SizedBox(height: 14),

                    _buildLabel('Kilométrage actuel *'),
                    const SizedBox(height: 6),
                    _buildTextField(_mileageController, 'Kilométrage'),

                    const SizedBox(height: 14),

                    _buildLabel('Localisation du véhicule *'),
                    const SizedBox(height: 6),
                    _buildTextField(_locationController, 'Adresse ou lieu'),

                    const SizedBox(height: 14),

                    _buildLabel('Description détaillée *'),
                    const SizedBox(height: 6),
                    _buildTextField(_descController, 'Détaillez les symptômes observés...', maxLines: 4),

                    const SizedBox(height: 14),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Véhicule immobilisé ?',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Cochez si le véhicule ne peut pas rouler en sécurité',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      value: _isImmobilized,
                      activeThumbColor: AppColors.redDark,
                      onChanged: (v) => setState(() => _isImmobilized = v),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _submitIncident,
                        child: const Text(
                          'Transmettre le signalement',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorderSubtle),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildSeverityChip(IncidentSeverity sev, String label, Color color) {
    final isSelected = _severity == sev;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _severity = sev);
      },
      selectedColor: color.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? color : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isSelected ? color : AppColors.cardBorderSubtle),
      ),
    );
  }

  void _submitIncident() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez renseigner un titre')),
      );
      return;
    }

    final newInc = IncidentItem(
      id: 'INC-2026-${DateTime.now().millisecondsSinceEpoch % 1000}',
      title: _titleController.text.trim(),
      vehicleModel: _vehicle.brandAndModel,
      vehiclePlate: _vehicle.registrationPlate,
      timeAgo: 'À l\'instant',
      severity: _severity,
      status: IncidentStatus.ouvert,
      date: '08 Oct 2026',
      mileage: int.tryParse(_mileageController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? _vehicle.currentMileage,
      location: _locationController.text.trim(),
      description: _descController.text.trim().isNotEmpty
          ? _descController.text.trim()
          : 'Signalement transmis par le conducteur.',
      isImmobilized: _isImmobilized,
    );

    _repo.addIncident(newInc);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Incident enregistré avec succès')),
    );
    Navigator.pop(context);
  }
}
