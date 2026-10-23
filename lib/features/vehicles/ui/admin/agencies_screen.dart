import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/agency.dart';
import '../../domain/enums.dart';
import '../../domain/vehicle_filter.dart';
import '../../services/demo_session.dart';
import '../../services/fleet_service.dart';
import '../feedback.dart';
import 'admin_widgets.dart';
import 'agency_form_sheet.dart';

/// Gestion des agences par l'administrateur : ajout, modification,
/// activation / désactivation et suppression.
///
/// Règles : on ne désactive pas une agence qui a des véhicules occupés ;
/// on ne supprime pas une agence qui a encore des véhicules (il faut les
/// transférer ou désactiver l'agence). Une agence désactivée disparaît du
/// catalogue client avec ses véhicules.
class AgenciesScreen extends StatefulWidget {
  const AgenciesScreen({super.key});

  @override
  State<AgenciesScreen> createState() => _AgenciesScreenState();
}

class _AgenciesScreenState extends State<AgenciesScreen> {
  final FleetService _service = FleetService.instance;

  List<Agency> _agencies = const [];
  Map<String, int> _counts = const {};
  Map<String, FleetStats> _stats = const {};
  bool _loading = true;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _service.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _service.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_requestId;
    try {
      final agencies = await _service.agencies();
      final counts = await _service.vehicleCountByAgency();
      final stats = <String, FleetStats>{
        for (final a in agencies)
          a.id: await _service.computeStats(agencyId: a.id),
      };
      if (!mounted || request != _requestId) return;
      setState(() {
        _agencies = agencies;
        _counts = counts;
        _stats = stats;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || request != _requestId) return;
      setState(() {
        _loading = false;
        _error = fleetErrorMessage(e);
      });
    }
  }

  Future<void> _openForm([Agency? agency]) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showAgencyFormSheet(context, agency: agency);
    if (saved != null) {
      showFleetSnack(
        messenger,
        agency == null ? 'Agence ${saved.name} ajoutée' : 'Agence enregistrée',
      );
    }
  }

  Future<void> _setActive(Agency agency, bool active) async {
    if (!active) {
      final count = _counts[agency.id] ?? 0;
      final ok = await confirmAction(
        context,
        title: "Désactiver l'agence ?",
        message: '${agency.name} et ses $count véhicule(s) ne seront plus '
            'visibles par les clients. Vous pourrez la réactiver.',
        confirmLabel: 'Désactiver',
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.setAgencyActive(
          agency.id, active, DemoSession.instance.actor);
      showFleetSnack(
        messenger,
        active ? '${agency.name} réactivée' : '${agency.name} désactivée',
      );
    } catch (e) {
      showFleetSnack(messenger, fleetErrorMessage(e), error: true);
    }
  }

  Future<void> _delete(Agency agency) async {
    final count = _counts[agency.id] ?? 0;
    final messenger = ScaffoldMessenger.of(context);
    if (count > 0) {
      showFleetSnack(
        messenger,
        '${agency.name} possède $count véhicule(s) : transférez-les ou '
        "désactivez l'agence.",
        error: true,
      );
      return;
    }
    final ok = await confirmAction(
      context,
      title: "Supprimer l'agence ?",
      message: '${agency.name} sera supprimée définitivement.',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await _service.deleteAgency(agency.id, DemoSession.instance.actor);
      showFleetSnack(messenger, '${agency.name} supprimée');
    } catch (e) {
      showFleetSnack(messenger, fleetErrorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _agencies.where((a) => a.isActive).length;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar('Agences'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          children: [
            Text(
              '${_agencies.length} agence(s) · $active active(s)',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            AdminPrimaryButton(
              label: 'Ajouter une agence',
              icon: Icons.add_business_outlined,
              onPressed: () => _openForm(),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              AdminBanner.error(text: _error!)
            else if (_agencies.isEmpty)
              const AdminEmptyState(
                icon: Icons.storefront_outlined,
                title: 'Aucune agence',
                message: 'Ajoutez la première agence de location.',
              )
            else
              for (final agency in _agencies) ...[
                _AgencyCard(
                  agency: agency,
                  vehicleCount: _counts[agency.id] ?? 0,
                  stats: _stats[agency.id],
                  onTap: () => _openForm(agency),
                  onActiveChanged: (value) => _setActive(agency, value),
                  onDelete: () => _delete(agency),
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

class _AgencyCard extends StatelessWidget {
  const _AgencyCard({
    required this.agency,
    required this.vehicleCount,
    required this.stats,
    required this.onTap,
    required this.onActiveChanged,
    required this.onDelete,
  });

  final Agency agency;
  final int vehicleCount;
  final FleetStats? stats;
  final VoidCallback onTap;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final contact = [
      agency.city,
      if (agency.phone.isNotEmpty) agency.phone,
    ].join(' · ');
    return Opacity(
      opacity: agency.isActive ? 1 : 0.7,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: agency.isActive
                      ? AppColors.primaryNavy
                      : AppColors.textSecondary,
                  child: Text(
                    agency.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agency.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        contact,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          AdminPill(
                            '$vehicleCount véhicule(s)',
                            icon: Icons.directions_car_outlined,
                          ),
                          if (s != null && s.total > 0) ...[
                            AdminPill(
                              '${s.count(VehicleStatus.disponible)} dispo.',
                              color: AppColors.greenDark,
                              background: AppColors.greenLight,
                            ),
                            AdminPill(
                              '${s.occupied} occupé(s)',
                              color: AppColors.primaryBlue,
                              background: AppColors.blueLight,
                            ),
                          ],
                          if (s != null && s.pendingValidation > 0)
                            AdminPill(
                              '${s.pendingValidation} à valider',
                              color: AppColors.orangeDark,
                              background: AppColors.orangeLight,
                            ),
                          if (!agency.isActive)
                            const AdminPill(
                              'Désactivée',
                              color: AppColors.redDark,
                              background: AppColors.redLight,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Switch(
                      value: agency.isActive,
                      activeTrackColor: AppColors.green,
                      onChanged: onActiveChanged,
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Actions',
                      icon: const Icon(Icons.more_vert_rounded,
                          color: AppColors.textSecondary),
                      onSelected: (action) {
                        if (action == 'edit') {
                          onTap();
                        } else {
                          onDelete();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Modifier')),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Supprimer',
                              style: TextStyle(color: AppColors.red)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
