import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/actor.dart';
import '../../domain/agency.dart';
import '../../domain/enums.dart';
import '../../domain/fleet_vehicle.dart';
import '../../domain/vehicle_category.dart';
import '../../domain/vehicle_filter.dart';
import '../../services/demo_session.dart';
import '../../services/fleet_service.dart';
import '../details/vehicle_details_screen.dart';
import '../widgets/availability_calendar.dart';
import '../widgets/client_vehicle_card.dart';
import '../widgets/vehicle_filter_sheet.dart';

/// Catalogue du client : recherche, catégories, filtres avancés, tri.
/// Consultation uniquement ; la liste se met à jour en direct quand une
/// agence ou l'administrateur modifie la flotte.
class ClientCatalogView extends StatefulWidget {
  const ClientCatalogView({super.key});

  @override
  State<ClientCatalogView> createState() => _ClientCatalogViewState();
}

class _ClientCatalogViewState extends State<ClientCatalogView> {
  static const Actor _client = Actor.client();

  final FleetService _service = FleetService.instance;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  int _requestId = 0;

  VehicleFilter _filter = const VehicleFilter();
  List<FleetVehicle> _vehicles = const [];
  Map<String, Agency> _agencies = const {};
  List<VehicleCategory> _categories = const [];
  List<String> _cities = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    _service.removeListener(_reload);
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final request = ++_requestId;
    try {
      final vehicles = await _service.search(_filter, _client);
      final agencies = await _service.agencyMap();
      final categories = await _service.categories(activeOnly: true);
      final cities = await _service.cities();
      if (!mounted || request != _requestId) return;
      setState(() {
        _vehicles = vehicles;
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
        _error = e.toString();
      });
    }
  }

  void _applyFilter(VehicleFilter filter) {
    setState(() => _filter = filter);
    _reload();
  }

  void _onQueryChanged(String value) {
    setState(() {}); // affiche / masque la croix d'effacement
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _applyFilter(_filter.copyWith(query: value));
    });
  }

  Future<void> _openFilters() async {
    final result = await showVehicleFilterSheet(
      context,
      current: _filter,
      categories: _categories,
      cities: _cities,
    );
    if (result != null && mounted) {
      _applyFilter(result.copyWith(query: _searchController.text));
    }
  }

  void _resetAll() {
    _searchController.clear();
    _applyFilter(const VehicleFilter());
  }

  void _openDetails(FleetVehicle vehicle) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VehicleDetailsScreen(vehicleId: vehicle.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              _buildHeader(),
              const SizedBox(height: 18),
              _buildSearchRow(),
              if (_filter.hasDateRange) ...[
                const SizedBox(height: 12),
                _buildDatesBanner(),
              ],
              const SizedBox(height: 14),
              _buildCategoryChips(),
              const SizedBox(height: 18),
              _buildResultsBar(),
              const SizedBox(height: 12),
              ..._buildResults(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bonjour 👋',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Trouvez la voiture parfaite pour votre trajet',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: DemoSession.instance.signOut,
          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
          label: const Text('Changer'),
        ),
      ],
    );
  }

  Widget _buildSearchRow() {
    final activeFilters = _filter.activeCount;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            onChanged: _onQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Marque, modèle…',
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
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primaryBlue),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
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
            if (activeFilters > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: AppColors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$activeFilters',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDatesBanner() {
    final from = _filter.availableFrom!;
    final to = _filter.availableTo!;
    final label = from == to
        ? 'Libres le ${FrenchDates.shortDay(from)}'
        : 'Libres du ${FrenchDates.shortDay(from)} '
            'au ${FrenchDates.shortDay(to)}';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.blueLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available_outlined,
              size: 18, color: AppColors.primaryBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.primaryNavy,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _applyFilter(_filter.copyWith(clearDates: true)),
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    Widget chip(String label, bool selected, VoidCallback onTap) {
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
          onSelected: (_) => onTap(),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('Toutes', _filter.categoryId == null,
              () => _applyFilter(_filter.copyWith(clearCategory: true))),
          for (final category in _categories)
            chip(category.name, _filter.categoryId == category.id,
                () => _applyFilter(_filter.copyWith(categoryId: category.id))),
        ],
      ),
    );
  }

  Widget _buildResultsBar() {
    return Row(
      children: [
        Expanded(
          child: Text(
            _loading ? 'Chargement…' : '${_vehicles.length} véhicule(s)',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        PopupMenuButton<VehicleSort>(
          initialValue: _filter.sort,
          onSelected: (sort) => _applyFilter(_filter.copyWith(sort: sort)),
          itemBuilder: (context) => [
            for (final sort in VehicleSort.values)
              PopupMenuItem(value: sort, child: Text(sort.label)),
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sort_rounded,
                  size: 18, color: AppColors.primaryBlue),
              const SizedBox(width: 4),
              Text(
                _filter.sort.label,
                style: const TextStyle(
                  color: AppColors.primaryBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildResults() {
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
        _MessageBox(
          icon: Icons.error_outline_rounded,
          title: 'Impossible de charger les véhicules',
          message: _error!,
          actionLabel: 'Réessayer',
          onAction: _reload,
        ),
      ];
    }
    if (_vehicles.isEmpty) {
      final filtered =
          _filter.activeCount > 0 || _filter.query.trim().isNotEmpty;
      return [
        _MessageBox(
          icon: Icons.search_off_rounded,
          title: filtered
              ? 'Aucun véhicule ne correspond'
              : 'Aucun véhicule disponible',
          message: filtered
              ? 'Essayez d\'autres critères ou d\'autres dates.'
              : 'Revenez un peu plus tard.',
          actionLabel: filtered ? 'Réinitialiser les filtres' : null,
          onAction: filtered ? _resetAll : null,
        ),
      ];
    }
    return [
      for (final vehicle in _vehicles) ...[
        ClientVehicleCard(
          vehicle: vehicle,
          categoryName: _categoryName(vehicle.categoryId),
          agencyLabel: _agencyLabel(vehicle.agencyId),
          onTap: () => _openDetails(vehicle),
        ),
        const SizedBox(height: 16),
      ],
    ];
  }

  String? _categoryName(String id) {
    for (final c in _categories) {
      if (c.id == id) return c.name;
    }
    return null;
  }

  String? _agencyLabel(String id) {
    final agency = _agencies[id];
    return agency == null ? null : '${agency.name} · ${agency.city}';
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(icon, size: 44, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
