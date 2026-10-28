import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../users/domain/user.dart';
import '../../domain/actor.dart';
import '../../domain/document_alert.dart';
import '../../domain/enums.dart';
import '../../domain/fleet_dates.dart';
import '../../domain/fleet_vehicle.dart';
import '../../domain/vehicle_filter.dart';
import '../../services/fleet_service.dart';
import '../details/vehicle_details_screen.dart';
import '../feedback.dart';
import '../manage/document_alerts_sheet.dart';
import 'admin_widgets.dart';

/// Statistiques de la flotte pour l'administrateur, globales ou par agence.
/// Les chiffres se mettent à jour en direct à chaque modification.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

/// Une part de la répartition par statut.
class _Slice {
  const _Slice(this.label, this.count, this.color);
  final String label;
  final int count;
  final Color color;
}

class _StatsScreenState extends State<StatsScreen> {
  final FleetService _service = FleetService.instance;

  int? _agencyId;
  List<User> _agencies = const [];
  FleetStats? _stats;
  List<DocumentAlert> _alerts = const [];
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
    const actor = Actor.admin();
    try {
      final agencies = await _service.agencies();
      final stats = await _service.computeStats(agencyId: _agencyId);
      final alerts =
          await _service.documentAlerts(actor, agencyId: _agencyId);
      if (!mounted || request != _requestId) return;
      setState(() {
        _agencies = agencies;
        _stats = stats;
        _alerts = alerts;
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

  void _selectAgency(int? id) {
    setState(() => _agencyId = id);
    _load();
  }

  void _openAlerts() {
    showDocumentAlertsSheet(
      context,
      alerts: _alerts,
      agencies: {for (final a in _agencies) if (a.id != null) a.id!: a},
      onOpenVehicle: (FleetVehicle vehicle) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VehicleDetailsScreen(vehicleId: vehicle.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar('Statistiques'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          children: [
            _buildAgencyFilter(),
            const SizedBox(height: 16),
            if (_loading && stats == null)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              AdminBanner.error(text: _error!)
            else if (stats != null) ...[
              _buildHero(stats),
              const SizedBox(height: 12),
              _buildKpis(stats),
              _SectionTitle(
                'Répartition par statut',
                trailing: '${stats.total} véhicule(s)',
              ),
              _StatusBreakdown(slices: [
                // Ordre choisi pour ne jamais coller orange et rouge.
                _Slice('Disponibles', stats.count(VehicleStatus.disponible),
                    AppColors.green),
                _Slice('Maintenance', stats.count(VehicleStatus.maintenance),
                    AppColors.orange),
                _Slice('Occupés', stats.occupied, AppColors.primaryBlue),
                _Slice('Hors service', stats.count(VehicleStatus.horsService),
                    AppColors.redDark),
              ]),
              if (_agencyId == null && stats.byAgency.isNotEmpty) ...[
                const _SectionTitle('Véhicules par agence'),
                _BarList(values: stats.byAgency),
              ],
              if (stats.byCategory.isNotEmpty) ...[
                const _SectionTitle('Véhicules par catégorie'),
                _BarList(values: stats.byCategory),
              ],
              const _SectionTitle('Papiers des véhicules'),
              _PapersCard(
                expired: stats.documentsExpired,
                soon: stats.documentsExpiringSoon,
                onTap: _openAlerts,
              ),
              const SizedBox(height: 12),
              const Text(
                'Véhicules archivés non comptés. « Occupés » regroupe les '
                'réservations et locations en cours (module Réservations).',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAgencyFilter() {
    Widget chip(String label, int? id) {
      final selected = _agencyId == id;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          selectedColor: AppColors.primaryNavy,
          backgroundColor: Colors.white,
          side: BorderSide(
            color: selected ? AppColors.primaryNavy : AppColors.cardBorderSubtle,
          ),
          labelStyle: TextStyle(
            color: selected ? Colors.white : AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          onSelected: (_) => _selectAgency(id),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('Toute la flotte', null),
          for (final agency in _agencies) chip(agency.displayName, agency.id),
        ],
      ),
    );
  }

  /// Le chiffre principal : taux de disponibilité, avec sa jauge.
  Widget _buildHero(FleetStats stats) {
    final rate = stats.availabilityRate;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryNavy,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Taux de disponibilité',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '$rate %',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rate / 100,
              minHeight: 8,
              color: AppColors.green,
              backgroundColor: Colors.white24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${stats.count(VehicleStatus.disponible)} véhicule(s) disponible(s)'
            ' sur ${stats.total} · ${stats.occupancyRate} % occupés',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildKpis(FleetStats stats) {
    final tiles = [
      _StatTile(label: 'Véhicules', value: '${stats.total}'),
      _StatTile(
        label: 'Prix moyen / jour',
        value: FleetFormat.dt(stats.averagePricePerDay.roundToDouble()),
      ),
      _StatTile(
        label: 'À valider',
        value: '${stats.pendingValidation}',
        icon: stats.pendingValidation > 0 ? Icons.hourglass_top_rounded : null,
      ),
    ];
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: tiles[i]),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.icon});

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: AppColors.orange),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Barre empilée (parts du total) + légende avec les valeurs.
class _StatusBreakdown extends StatelessWidget {
  const _StatusBreakdown({required this.slices});

  final List<_Slice> slices;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold(0, (sum, s) => sum + s.count);
    final visible = slices.where((s) => s.count > 0).toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (total == 0)
            Container(
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.sectionBg,
                borderRadius: BorderRadius.circular(4),
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 14,
                child: Row(
                  children: [
                    for (var i = 0; i < visible.length; i++) ...[
                      // Espace de 2 px couleur fond entre deux parts.
                      if (i > 0) const SizedBox(width: 2),
                      Expanded(
                        flex: visible[i].count,
                        child: ColoredBox(color: visible[i].color),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              for (final s in slices)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: s.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${s.label} ',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      total == 0
                          ? '${s.count}'
                          : '${s.count} (${(s.count * 100 / total).round()} %)',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Barres horizontales d'une seule couleur, de la plus grande à la plus
/// petite, valeur au bout de chaque barre.
class _BarList extends StatelessWidget {
  const _BarList({required this.values});

  final Map<String, int> values;

  @override
  Widget build(BuildContext context) {
    final entries = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = entries.isEmpty ? 1 : entries.first.value;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      entry.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = max == 0
                            ? 0.0
                            : constraints.maxWidth * entry.value / max;
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: width,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryBlue,
                              // Bout arrondi côté valeur, carré côté base.
                              borderRadius: BorderRadius.horizontal(
                                right: Radius.circular(4),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${entry.value}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PapersCard extends StatelessWidget {
  const _PapersCard({
    required this.expired,
    required this.soon,
    required this.onTap,
  });

  final int expired;
  final int soon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, Color color, Color background, String value,
        String label) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  item(Icons.error_outline_rounded, AppColors.redDark,
                      AppColors.redLight, '$expired', 'expiré(s)'),
                  const SizedBox(width: 8),
                  item(Icons.schedule_rounded, AppColors.orange,
                      AppColors.orangeLight, '$soon', 'expirent sous 30 j'),
                ],
              ),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Voir les véhicules concernés ›',
                  style: TextStyle(
                    color: AppColors.primaryBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
