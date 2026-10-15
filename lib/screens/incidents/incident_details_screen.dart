import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/maintenance_repository.dart';
import '../../models/incident_item.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/status_badge.dart';
import 'repair_details_screen.dart';

class IncidentDetailsScreen extends StatefulWidget {
  final IncidentItem incident;

  const IncidentDetailsScreen({super.key, required this.incident});

  @override
  State<IncidentDetailsScreen> createState() => _IncidentDetailsScreenState();
}

class _IncidentDetailsScreenState extends State<IncidentDetailsScreen> {
  final MaintenanceRepository _repo = MaintenanceRepository();

  @override
  Widget build(BuildContext context) {
    final item = widget.incident;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            CustomHeader(
              title: 'Détails incident',
              subtitle: '#${item.id}',
              showBackButton: true,
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main status card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.cardBorder),
                        boxShadow: const [AppColors.softShadow],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              item.severity == IncidentSeverity.critique
                                  ? StatusBadge.critical()
                                  : StatusBadge.upcoming(label: item.severityLabel),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: item.status == IncidentStatus.resolu
                                      ? AppColors.greenLight
                                      : AppColors.blueLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  item.statusLabel,
                                  style: TextStyle(
                                    color: item.status == IncidentStatus.resolu
                                        ? AppColors.greenDark
                                        : AppColors.primaryBlue,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            item.title,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.vehicleModel} • ${item.vehiclePlate}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (item.isImmobilized) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.redLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.redBorder),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_rounded, color: AppColors.redDark, size: 24),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Véhicule immobilisé - Dépannage requis sur place.',
                                style: TextStyle(
                                  color: AppColors.redDark,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Information Card
                    _buildSectionCard(
                      title: 'Informations constatées',
                      children: [
                        _buildRow('Date & Heure', item.date),
                        const Divider(height: 18),
                        _buildRow('Kilométrage', '${item.mileage} km'),
                        const Divider(height: 18),
                        _buildRow('Localisation', item.location),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Description
                    _buildSectionCard(
                      title: 'Description du problème',
                      children: [
                        Text(
                          item.description,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Garage & Technician
                    if (item.assignedGarage != null)
                      _buildSectionCard(
                        title: 'Intervenants assignés',
                        children: [
                          _buildRow('Garage', item.assignedGarage!),
                          const Divider(height: 18),
                          _buildRow('Technicien', item.assignedTechnician ?? 'Non désigné'),
                        ],
                      ),

                    const SizedBox(height: 24),

                    // Actions
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RepairDetailsScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Voir le dossier de réparation',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    if (item.status != IncidentStatus.resolu) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.greenPrice),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () {
                            _repo.resolveIncident(item.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Incident marqué comme résolu')),
                            );
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Clôturer / Marquer comme résolu',
                            style: TextStyle(
                              color: AppColors.greenPrice,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],

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

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [AppColors.softShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
