import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/maintenance_repository.dart';
import '../../models/incident_item.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/status_badge.dart';
import 'incident_details_screen.dart';
import 'report_incident_screen.dart';

class IncidentListScreen extends StatefulWidget {
  const IncidentListScreen({super.key});

  @override
  State<IncidentListScreen> createState() => _IncidentListScreenState();
}

class _IncidentListScreenState extends State<IncidentListScreen> {
  final MaintenanceRepository _repo = MaintenanceRepository();
  String _search = '';

  @override
  Widget build(BuildContext context) {
    var incidents = _repo.incidents;
    if (_search.isNotEmpty) {
      incidents = incidents.where((i) =>
        i.title.toLowerCase().contains(_search.toLowerCase()) ||
        i.vehicleModel.toLowerCase().contains(_search.toLowerCase())
      ).toList();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            CustomHeader(
              title: 'Incidents & Pannes',
              subtitle: '${incidents.length} signalements enregistrés',
              showBackButton: true,
              onBack: () => Navigator.of(context).pop(),
              trailing: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReportIncidentScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.redDark,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 24),
                ),
              ),
            ),
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
                  onChanged: (v) => setState(() => _search = v),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un incident, panne...',
                    hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                physics: const BouncingScrollPhysics(),
                itemCount: incidents.length,
                itemBuilder: (context, index) {
                  final item = incidents[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => IncidentDetailsScreen(incident: item),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.cardBorder),
                          boxShadow: const [AppColors.softShadow],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: item.severity == IncidentSeverity.critique
                                    ? AppColors.redLight
                                    : AppColors.orangeLight,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.warning_amber_rounded,
                                color: item.severity == IncidentSeverity.critique
                                    ? AppColors.red
                                    : AppColors.orange,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      item.severity == IncidentSeverity.critique
                                          ? StatusBadge.critical()
                                          : StatusBadge.upcoming(label: item.severityLabel),
                                      const SizedBox(width: 8),
                                      Text(
                                        item.statusLabel,
                                        style: TextStyle(
                                          color: item.status == IncidentStatus.resolu
                                              ? AppColors.greenPrice
                                              : AppColors.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.vehicleModel} • ${item.timeAgo}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
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
}
