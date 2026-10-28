import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../users/domain/user.dart';
import '../../domain/enums.dart';
import '../../domain/fleet_dates.dart';
import '../../domain/vehicle_category.dart';
import '../../domain/vehicle_filter.dart';
import 'availability_calendar.dart';

/// Feuille « Filtres » du catalogue. Renvoie le nouveau filtre (ou null
/// si l'utilisateur ferme sans appliquer).
Future<VehicleFilter?> showVehicleFilterSheet(
  BuildContext context, {
  required VehicleFilter current,
  required List<VehicleCategory> categories,
  required List<String> cities,
  List<User> agencies = const [],
}) {
  return showModalBottomSheet<VehicleFilter>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: _FilterSheet(
        initial: current,
        categories: categories,
        cities: cities,
        agencies: agencies,
      ),
    ),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.initial,
    required this.categories,
    required this.cities,
    required this.agencies,
  });

  final VehicleFilter initial;
  final List<VehicleCategory> categories;
  final List<String> cities;

  /// Liste non vide : filtre par agence (vue administrateur).
  final List<User> agencies;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  static const double _priceMax = 700;
  static const List<int> _seatOptions = [2, 4, 5, 7];

  late VehicleFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initial;
  }

  RangeValues get _priceRange => RangeValues(
        _filter.minPrice ?? 0,
        (_filter.maxPrice ?? _priceMax).clamp(0, _priceMax).toDouble(),
      );

  Future<void> _pickDates() async {
    DateTime? start = _filter.availableFrom;
    DateTime? end = _filter.availableTo;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (sheetContext) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: StatefulBuilder(
          builder: (context, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Dates de location',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Touchez la date de départ puis la date de retour.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              AvailabilityCalendar(
                initialStart: start,
                initialEnd: end,
                showLegend: false,
                onRangeChanged: (s, e) => setSheetState(() {
                  start = s;
                  end = e;
                }),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: start == null
                    ? null
                    : () => Navigator.of(sheetContext).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  minimumSize: const Size.fromHeight(50),
                ),
                child: Text(start == null
                    ? 'Choisissez une date de départ'
                    : 'Valider ${_rangeLabel(start!, end ?? start!)}'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (confirmed == true && start != null) {
      setState(() {
        _filter = _filter.copyWith(
          availableFrom: start,
          availableTo: end ?? start,
        );
      });
    }
  }

  static String _rangeLabel(DateTime start, DateTime end) =>
      start == end
          ? 'le ${FleetDates.display(start)}'
          : 'du ${FrenchDates.shortDay(start)} au ${FrenchDates.shortDay(end)}';

  @override
  Widget build(BuildContext context) {
    final range = _priceRange;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Filtres',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              const _SectionTitle('Dates de location'),
              OutlinedButton.icon(
                onPressed: _pickDates,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  alignment: Alignment.centerLeft,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(
                  _filter.hasDateRange
                      ? _rangeLabel(_filter.availableFrom!, _filter.availableTo!)
                      : 'Toutes les dates',
                ),
              ),
              if (_filter.hasDateRange)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(
                        () => _filter = _filter.copyWith(clearDates: true)),
                    child: const Text('Effacer les dates'),
                  ),
                ),
              if (widget.agencies.isNotEmpty) ...[
                const _SectionTitle('Agence'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip('Toutes', _filter.agencyId == null,
                        () => _filter.copyWith(clearAgency: true)),
                    for (final agency in widget.agencies)
                      _chip(agency.displayName, _filter.agencyId == agency.id,
                          () => _filter.copyWith(agencyId: agency.id)),
                  ],
                ),
              ],
              if (widget.cities.length > 1) ...[
                const _SectionTitle('Ville'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip('Toutes', _filter.city == null,
                        () => _filter.copyWith(clearCity: true)),
                    for (final city in widget.cities)
                      _chip(city, _filter.city == city,
                          () => _filter.copyWith(city: city)),
                  ],
                ),
              ],
              const _SectionTitle('Catégorie'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip('Toutes', _filter.categoryId == null,
                      () => _filter.copyWith(clearCategory: true)),
                  for (final c in widget.categories)
                    _chip(c.name, _filter.categoryId == c.id,
                        () => _filter.copyWith(categoryId: c.id)),
                ],
              ),
              _SectionTitle(
                'Prix par jour : ${FleetFormat.dt(range.start)} – '
                '${range.end >= _priceMax ? '${FleetFormat.dt(_priceMax)}+' : FleetFormat.dt(range.end)}',
              ),
              RangeSlider(
                values: range,
                min: 0,
                max: _priceMax,
                divisions: 70,
                activeColor: AppColors.primaryBlue,
                labels: RangeLabels(
                  FleetFormat.dt(range.start),
                  FleetFormat.dt(range.end),
                ),
                onChanged: (values) => setState(() {
                  _filter = _filter.copyWith(
                    clearPrices: true,
                  );
                  _filter = _filter.copyWith(
                    minPrice: values.start <= 0 ? null : values.start,
                    maxPrice: values.end >= _priceMax ? null : values.end,
                  );
                }),
              ),
              const _SectionTitle('Carburant'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip('Tous', _filter.fuel == null,
                      () => _filter.copyWith(clearFuel: true)),
                  for (final f in FuelType.values)
                    _chip(f.label, _filter.fuel == f,
                        () => _filter.copyWith(fuel: f)),
                ],
              ),
              const _SectionTitle('Boîte de vitesses'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip('Toutes', _filter.transmission == null,
                      () => _filter.copyWith(clearTransmission: true)),
                  for (final t in Transmission.values)
                    _chip(t.label, _filter.transmission == t,
                        () => _filter.copyWith(transmission: t)),
                ],
              ),
              const _SectionTitle('Nombre de places minimum'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip('Peu importe', _filter.minSeats == null,
                      () => _filter.copyWith(clearSeats: true)),
                  for (final n in _seatOptions)
                    _chip('$n+', _filter.minSeats == n,
                        () => _filter.copyWith(minSeats: n)),
                ],
              ),
              const _SectionTitle('Trier par'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in VehicleSort.values)
                    _chip(s.label, _filter.sort == s,
                        () => _filter.copyWith(sort: s)),
                ],
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _filter = VehicleFilter(
                          query: _filter.query,
                        )),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Réinitialiser'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_filter),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryNavy,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Appliquer les filtres'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, bool selected, VehicleFilter Function() apply) {
    return ChoiceChip(
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
      onSelected: (_) => setState(() => _filter = apply()),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
