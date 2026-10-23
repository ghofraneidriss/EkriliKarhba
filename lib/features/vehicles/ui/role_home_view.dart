import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/agency.dart';
import '../domain/document_alert.dart';
import '../domain/enums.dart';
import '../domain/fleet_vehicle.dart';
import '../domain/vehicle_category.dart';
import '../domain/vehicle_filter.dart';
import '../services/demo_session.dart';
import '../services/fleet_service.dart';
import 'admin/agencies_screen.dart';
import 'admin/categories_screen.dart';
import 'admin/stats_screen.dart';
import 'admin/validation_screen.dart';
import 'details/vehicle_details_screen.dart';
import 'feedback.dart';
import 'manage/document_alerts_sheet.dart';
import 'manage/status_sheet.dart';
import 'manage/transfer_sheet.dart';
import 'manage/vehicle_form_screen.dart';
import 'widgets/fleet_vehicle_tile.dart';
import 'widgets/vehicle_filter_sheet.dart';

/// Espace de gestion de la flotte (agence : sa flotte ; administrateur :
/// toutes les agences), d'après l'écran « Gestion des véhicules » de la
/// maquette : recherche, filtres, statuts, ajout, actions rapides.
///
/// Notifications « papiers » : à l'ouverture, l'agence voit une carte qui
/// liste les véhicules dont un document expire dans les 30 jours (ou est
/// expiré). La cloche de l'en-tête garde le compteur et la liste complète.
///
/// Administrateur : raccourcis vers Validation, Agences, Catégories et
/// Statistiques, et transfert d'un véhicule depuis le menu ⋮.
class RoleHomeView extends StatefulWidget {
  const RoleHomeView({super.key});

  @override
  State<RoleHomeView> createState() => _RoleHomeViewState();
}

class _RoleHomeViewState extends State<RoleHomeView> {
  final FleetService _service = FleetService.instance;
  final DemoSession _session = DemoSession.instance;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  int _requestId = 0;

  VehicleFilter _filter = const VehicleFilter();
  List<FleetVehicle> _vehicles = const [];
  Map<String, Agency> _agencies = const {};
  Map<String, VehicleCategory> _categories = const {};
  List<String> _cities = const [];
  FleetStats? _stats;
  List<DocumentAlert> _alerts = const [];
  bool _loading = true;
  String? _error;

  bool get _isAdmin => _session.actor.isAdmin;

  @override
  void initState() {
    super.initState();
    _service.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _service.removeListener(_load);
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_requestId;
    final actor = _session.actor;
    try {
      final vehicles = await _service.search(_filter, actor);
      final stats = await _service.computeStats(agencyId: actor.agencyId);
      final alerts = await _service.documentAlerts(actor);
      final agencies = await _service.agencyMap();
      final categories = await _service.categoryMap();
      final cities = await _service.cities();
      if (!mounted || request != _requestId) return;
      setState(() {
        _vehicles = vehicles;
        _stats = stats;
        _alerts = alerts;
        _agencies = agencies;
        _categories = categories;
        _cities = cities;
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

  void _applyFilter(VehicleFilter filter) {
    setState(() => _filter = filter);
    _load();
  }

  void _onQueryChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _applyFilter(_filter.copyWith(query: value));
    });
  }

  Future<void> _openFilters() async {
    final result = await showVehicleFilterSheet(
      context,
      current: _filter,
      categories: _categories.values.toList(),
      cities: _cities,
      agencies: _isAdmin ? _agencies.values.toList() : const [],
    );
    if (result != null && mounted) {
      _applyFilter(result.copyWith(
        query: _searchController.text,
        statuses: _filter.statuses,
      ));
    }
  }

  /// Notifications pas encore fermées pendant cette connexion.
  List<DocumentAlert> get _newAlerts => [
        for (final alert in _alerts)
          if (!_session.isAlertDismissed(alert.key)) alert,
      ];

  void _dismissAlerts() {
    setState(() => _session.dismissAlerts(_alerts.map((a) => a.key)));
  }

  void _openAlerts() {
    showDocumentAlertsSheet(
      context,
      alerts: _alerts,
      agencies: _isAdmin ? _agencies : const {},
      onOpenVehicle: _openDetails,
    );
  }

  void _openDetails(FleetVehicle vehicle) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VehicleDetailsScreen(vehicleId: vehicle.id),
      ),
    );
  }

  void _push(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  void _openForm({String? vehicleId}) {
    Navigator.of(context).push(
      MaterialPageRoute<VehicleFormResult>(
        builder: (_) => VehicleFormScreen(vehicleId: vehicleId),
      ),
    );
  }

  Future<void> _delete(FleetVehicle vehicle) async {
    final ok = await confirmAction(
      context,
      title: 'Supprimer ce véhicule ?',
      message: '${vehicle.fullName} (${vehicle.registrationPlate}) sera '
          "retiré de la flotte. L'historique est conservé.",
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.deleteVehicle(vehicle.id, _session.actor);
      showFleetSnack(messenger, '${vehicle.fullName} supprimé');
    } catch (e) {
      showFleetSnack(messenger, fleetErrorMessage(e), error: true);
    }
  }

  void _onMenu(FleetVehicle vehicle, String action) {
    switch (action) {
      case 'details':
        _openDetails(vehicle);
      case 'edit':
        _openForm(vehicleId: vehicle.id);
      case 'status':
        showStatusSheet(context, vehicle);
      case 'transfer':
        showTransferSheet(context, vehicle);
      case 'delete':
        _delete(vehicle);
    }
  }

  void _selectStatuses(Set<VehicleStatus> statuses) {
    _applyFilter(_filter.copyWith(
      statuses: statuses,
      clearValidation: true,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              _buildHeader(),
              _buildNotification(),
              if (_isAdmin) ...[
                const SizedBox(height: 14),
                _buildAdminShortcuts(),
              ],
              const SizedBox(height: 16),
              _buildSearchRow(),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _openForm(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'Ajouter un véhicule',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (_stats != null) ...[
                const SizedBox(height: 14),
                ..._buildAlerts(_stats!),
                _buildKpis(_stats!),
              ],
              const SizedBox(height: 14),
              _buildStatusChips(),
              const SizedBox(height: 14),
              ..._buildList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final agency = _session.agency;
    final total = _stats?.total;
    final scope = agency?.name ?? 'Toutes les agences';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gestion des véhicules',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                total == null ? scope : '$scope · $total véhicule(s)',
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Notifications',
          onPressed: _openAlerts,
          icon: Badge(
            isLabelVisible: _alerts.isNotEmpty,
            label: Text('${_alerts.length}'),
            backgroundColor: _alerts.any((a) => a.expired)
                ? AppColors.redDark
                : AppColors.orange,
            child: Icon(
              _alerts.isEmpty
                  ? Icons.notifications_none_rounded
                  : Icons.notifications_active_rounded,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: _session.signOut,
          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
          label: const Text('Changer'),
        ),
      ],
    );
  }

  /// Carte de notification affichée au gestionnaire d'agence tant qu'il ne
  /// l'a pas fermée (elle revient à la prochaine connexion).
  Widget _buildNotification() {
    final alerts = _isAdmin ? const <DocumentAlert>[] : _newAlerts;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: alerts.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 14),
              child: _DocumentNotificationCard(
                alerts: alerts,
                onOpenVehicle: _openDetails,
                onSeeAll: _openAlerts,
                onDismiss: _dismissAlerts,
              ),
            ),
    );
  }

  Widget _buildSearchRow() {
    final active = _filter.activeCount -
        (_filter.statuses.isNotEmpty ? 1 : 0) -
        (_filter.validation != null ? 1 : 0);
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            onChanged: _onQueryChanged,
            decoration: InputDecoration(
              hintText: 'Marque, modèle, matricule…',
              hintStyle: const TextStyle(color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.textSecondary),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        _onQueryChanged('');
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.inputBorder),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Badge(
          isLabelVisible: active > 0,
          label: Text('$active'),
          backgroundColor: AppColors.orange,
          child: Material(
            color: AppColors.primaryNavy,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: _openFilters,
              borderRadius: BorderRadius.circular(16),
              child: const SizedBox(
                width: 52,
                height: 52,
                child: Icon(Icons.tune_rounded, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Raccourcis de l'administrateur (2 × 2).
  Widget _buildAdminShortcuts() {
    final stats = _stats;
    final pending = stats?.pendingValidation ?? 0;
    final tiles = [
      _ShortcutTile(
        icon: Icons.fact_check_outlined,
        title: 'Validation',
        value: pending == 0 ? 'À jour' : '$pending à valider',
        highlight: pending > 0,
        onTap: () => _push(const ValidationScreen()),
      ),
      _ShortcutTile(
        icon: Icons.storefront_outlined,
        title: 'Agences',
        value: '${_agencies.length} agence(s)',
        onTap: () => _push(const AgenciesScreen()),
      ),
      _ShortcutTile(
        icon: Icons.category_outlined,
        title: 'Catégories',
        value: '${_categories.length} catégorie(s)',
        onTap: () => _push(const CategoriesScreen()),
      ),
      _ShortcutTile(
        icon: Icons.insights_rounded,
        title: 'Statistiques',
        value: stats == null ? '—' : '${stats.availabilityRate} % dispo.',
        onTap: () => _push(const StatsScreen()),
      ),
    ];
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: tiles[0]),
            const SizedBox(width: 10),
            Expanded(child: tiles[1]),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: tiles[2]),
            const SizedBox(width: 10),
            Expanded(child: tiles[3]),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildAlerts(FleetStats stats) {
    final alerts = <Widget>[];
    // L'admin a le raccourci « Validation » ; l'agence, ce rappel.
    if (!_isAdmin && stats.pendingValidation > 0) {
      alerts.add(_AlertTile(
        icon: Icons.hourglass_top_rounded,
        color: AppColors.orange,
        background: AppColors.orangeLight,
        text: '${stats.pendingValidation} véhicule(s) en attente de '
            "validation par l'administrateur",
        onTap: () => _applyFilter(_filter.copyWith(
          validation: ValidationStatus.enAttente,
          statuses: <VehicleStatus>{},
        )),
      ));
    }
    // L'agence a sa carte de notification ; l'admin garde ce résumé.
    if (_isAdmin &&
        (stats.documentsExpired > 0 || stats.documentsExpiringSoon > 0)) {
      final parts = [
        if (stats.documentsExpired > 0)
          '${stats.documentsExpired} document(s) expiré(s)',
        if (stats.documentsExpiringSoon > 0)
          '${stats.documentsExpiringSoon} expire(nt) dans moins de 30 jours',
      ];
      alerts.add(_AlertTile(
        icon: Icons.description_outlined,
        color: AppColors.redDark,
        background: AppColors.redLight,
        text: parts.join(' · '),
        onTap: _openAlerts,
      ));
    }
    return [
      for (final alert in alerts) ...[alert, const SizedBox(height: 8)],
    ];
  }

  Widget _buildKpis(FleetStats stats) {
    final unavailable = stats.count(VehicleStatus.maintenance) +
        stats.count(VehicleStatus.horsService);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: _Kpi(
              value: '${stats.count(VehicleStatus.disponible)}',
              label: 'Disponibles',
              color: AppColors.green,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Kpi(
              value: '${stats.occupied}',
              label: 'Occupés',
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Kpi(
              value: '$unavailable',
              label: 'Indisponibles',
              color: AppColors.redDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Kpi(
              value: '${stats.availabilityRate} %',
              label: 'Taux dispo.',
              color: AppColors.primaryNavy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChips() {
    final selected = _filter.statuses;
    bool isGroupSelected(Set<VehicleStatus> group) =>
        selected.length == group.length && selected.containsAll(group);
    String withCount(String label, Set<VehicleStatus> group) {
      final stats = _stats;
      if (stats == null || group.contains(VehicleStatus.archive)) return label;
      final n = group.fold(0, (sum, s) => sum + stats.count(s));
      return '$label ($n)';
    }

    // « Occupé » regroupe réservé, loué et contrôle retour : ces statuts
    // sont gérés par le module Réservations.
    const groups = <(String, Set<VehicleStatus>)>[
      ('Disponibles', {VehicleStatus.disponible}),
      ('Occupés', VehicleStatus.occupiedStatuses),
      ('Maintenance', {VehicleStatus.maintenance}),
      ('Hors service', {VehicleStatus.horsService}),
      ('Archivés', {VehicleStatus.archive}),
    ];
    final pendingOnly = _filter.validation == ValidationStatus.enAttente;
    Widget chip(String label, bool isSelected, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: isSelected,
          showCheckmark: false,
          selectedColor: AppColors.primaryNavy,
          backgroundColor: Colors.white,
          side: BorderSide(
            color:
                isSelected ? AppColors.primaryNavy : AppColors.cardBorderSubtle,
          ),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          onSelected: (_) => onTap(),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('Tous', selected.isEmpty && !pendingOnly,
              () => _selectStatuses(<VehicleStatus>{})),
          if (pendingOnly)
            chip('À valider', true, () => _selectStatuses(<VehicleStatus>{})),
          for (final (label, group) in groups)
            chip(withCount(label, group), isGroupSelected(group),
                () => _selectStatuses(group)),
        ],
      ),
    );
  }

  List<Widget> _buildList() {
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 60),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_error != null) {
      return [
        Text(_error!, style: const TextStyle(color: AppColors.redDark)),
        TextButton(onPressed: _load, child: const Text('Réessayer')),
      ];
    }
    if (_vehicles.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            children: [
              Icon(Icons.directions_car_outlined,
                  size: 44, color: AppColors.textSecondary),
              SizedBox(height: 10),
              Text(
                'Aucun véhicule ne correspond',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ];
    }
    return [
      for (final vehicle in _vehicles) ...[
        FleetVehicleTile(
          vehicle: vehicle,
          categoryName: _categories[vehicle.categoryId]?.name,
          agencyName: _isAdmin ? _agencies[vehicle.agencyId]?.name : null,
          showPlate: true,
          showValidation: true,
          onTap: () => _openDetails(vehicle),
          trailing: SizedBox(
            width: 30,
            height: 26,
            child: PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              iconSize: 20,
              tooltip: 'Actions',
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppColors.textSecondary),
              onSelected: (action) => _onMenu(vehicle, action),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'details', child: Text('Voir détails')),
                const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                const PopupMenuItem(
                    value: 'status', child: Text('Changer le statut')),
                if (_isAdmin)
                  const PopupMenuItem(
                    value: 'transfer',
                    child: Text('Transférer vers une agence'),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Supprimer',
                      style: TextStyle(color: AppColors.red)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }
}

/// Notification « papiers à renouveler » pour le gestionnaire d'agence.
class _DocumentNotificationCard extends StatelessWidget {
  const _DocumentNotificationCard({
    required this.alerts,
    required this.onOpenVehicle,
    required this.onSeeAll,
    required this.onDismiss,
  });

  static const int _maxShown = 3;

  final List<DocumentAlert> alerts;
  final void Function(FleetVehicle vehicle) onOpenVehicle;
  final VoidCallback onSeeAll;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final expired = alerts.where((a) => a.expired).length;
    final soon = alerts.length - expired;
    final accent = expired > 0 ? AppColors.redDark : AppColors.orange;
    final subtitle = [
      if (expired > 0) '$expired expiré${expired > 1 ? 's' : ''}',
      if (soon > 0) '$soon à renouveler sous 30 jours',
    ].join(' · ');
    final hidden = alerts.length - _maxShown;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.notifications_active_rounded,
                    size: 20, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Papiers à renouveler',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Fermer',
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded,
                    size: 20, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final alert in alerts.take(_maxShown))
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DocumentAlertRow(
                alert: alert,
                dense: true,
                onTap: () => onOpenVehicle(alert.vehicle),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onSeeAll,
              child: Text(hidden > 0
                  ? 'Voir tout (+$hidden)'
                  : 'Voir le détail'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Raccourci de l'espace administrateur.
class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  /// Quelque chose attend l'administrateur (ex. véhicules à valider).
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final accent = highlight ? AppColors.orange : AppColors.primaryBlue;
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
            border: Border.all(
              color: highlight
                  ? AppColors.orange.withValues(alpha: 0.5)
                  : AppColors.cardBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: highlight ? AppColors.orangeLight : AppColors.blueLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: highlight
                            ? AppColors.orangeDark
                            : AppColors.textMuted,
                        fontSize: 11,
                        fontWeight:
                            highlight ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.icon,
    required this.color,
    required this.background,
    required this.text,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, size: 18, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.value, required this.label, required this.color});

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
