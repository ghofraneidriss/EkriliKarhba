import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/fleet_dates.dart';
import '../../domain/unavailability_period.dart';

/// Noms français (l'app n'embarque pas les traductions Material).
class FrenchDates {
  FrenchDates._();

  static const List<String> months = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet',
    'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];

  /// Initiales des jours, du lundi au dimanche.
  static const List<String> dayLetters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  static String monthYear(DateTime d) {
    final name = months[d.month - 1];
    return '${name[0].toUpperCase()}${name.substring(1)} ${d.year}';
  }

  static const List<String> shortMonths = [
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.',
    'août', 'sept.', 'oct.', 'nov.', 'déc.',
  ];

  /// « 27 oct. »
  static String shortDay(DateTime d) => '${d.day} ${shortMonths[d.month - 1]}';
}

/// État d'un jour pour l'affichage.
enum DayAvailability {
  libre('Disponible', AppColors.green, Colors.white),
  reserve('Occupé', AppColors.primaryBlue, AppColors.blueSoft),
  indisponible('Indisponible', AppColors.redDark, AppColors.redLight),
  passe('Passé', AppColors.textSecondary, Colors.white);

  const DayAvailability(this.label, this.color, this.background);
  final String label;
  final Color color;
  final Color background;

  static DayAvailability of(
    DateTime day,
    List<UnavailabilityPeriod> periods,
    DateTime today,
  ) {
    final d = FleetDates.dayOnly(day);
    if (d.isBefore(FleetDates.dayOnly(today))) return passe;
    for (final p in periods) {
      if (p.containsDay(d)) {
        return p.reason.startsWith('Réservation') ? reserve : indisponible;
      }
    }
    return libre;
  }
}

/// Calendrier mensuel en français, avec les jours bloqués du véhicule.
/// Si [onRangeChanged] est fourni, on peut sélectionner une période
/// (1er appui = début, 2e appui = fin).
class AvailabilityCalendar extends StatefulWidget {
  const AvailabilityCalendar({
    super.key,
    this.periods = const [],
    this.initialStart,
    this.initialEnd,
    this.onRangeChanged,
    this.showLegend = true,
  });

  final List<UnavailabilityPeriod> periods;
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final void Function(DateTime? start, DateTime? end)? onRangeChanged;
  final bool showLegend;

  @override
  State<AvailabilityCalendar> createState() => _AvailabilityCalendarState();
}

class _AvailabilityCalendarState extends State<AvailabilityCalendar> {
  late DateTime _month;
  DateTime? _start;
  DateTime? _end;
  final DateTime _today = FleetDates.dayOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart == null
        ? null
        : FleetDates.dayOnly(widget.initialStart!);
    _end =
        widget.initialEnd == null ? null : FleetDates.dayOnly(widget.initialEnd!);
    final anchor = _start ?? _today;
    _month = DateTime(anchor.year, anchor.month);
  }

  bool get _selectable => widget.onRangeChanged != null;

  void _onTap(DateTime day) {
    if (!_selectable || day.isBefore(_today)) return;
    setState(() {
      if (_start == null || _end != null) {
        _start = day;
        _end = null;
      } else if (day.isBefore(_start!)) {
        _start = day;
      } else {
        _end = day;
      }
    });
    widget.onRangeChanged!(_start, _end);
  }

  bool _inSelection(DateTime day) {
    final start = _start;
    if (start == null) return false;
    final end = _end ?? start;
    return !day.isBefore(start) && !day.isAfter(end);
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(_month.year, _month.month);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = firstDay.weekday - 1; // lundi = 0
    final canGoBack = DateTime(_month.year, _month.month)
        .isAfter(DateTime(_today.year, _today.month));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: canGoBack
                  ? () => setState(
                      () => _month = DateTime(_month.year, _month.month - 1))
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                FrenchDates.monthYear(_month),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1)),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final letter in FrenchDates.dayLetters)
              Expanded(
                child: Center(
                  child: Text(
                    letter,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: leading + daysInMonth,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemBuilder: (context, index) {
            if (index < leading) return const SizedBox.shrink();
            final day = DateTime(_month.year, _month.month, index - leading + 1);
            return _DayCell(
              day: day,
              availability: DayAvailability.of(day, widget.periods, _today),
              isToday: day == _today,
              selected: _inSelection(day),
              onTap: _selectable ? () => _onTap(day) : null,
            );
          },
        ),
        if (widget.showLegend) ...[
          const SizedBox(height: 10),
          const Wrap(
            spacing: 14,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _LegendDot(DayAvailability.libre),
              _LegendDot(DayAvailability.reserve),
              _LegendDot(DayAvailability.indisponible),
            ],
          ),
        ],
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.availability,
    required this.isToday,
    required this.selected,
    required this.onTap,
  });

  final DateTime day;
  final DayAvailability availability;
  final bool isToday;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final blocked = availability == DayAvailability.reserve ||
        availability == DayAvailability.indisponible;
    final Color background;
    final Color foreground;
    if (selected) {
      background = blocked ? AppColors.red : AppColors.primaryNavy;
      foreground = Colors.white;
    } else {
      background = availability.background;
      foreground = availability == DayAvailability.libre
          ? AppColors.textPrimary
          : availability.color;
    }
    return InkWell(
      onTap: availability == DayAvailability.passe ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: isToday && !selected
              ? Border.all(color: AppColors.primaryBlue, width: 1.5)
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: foreground,
            fontSize: 13,
            fontWeight: blocked || selected ? FontWeight.w800 : FontWeight.w600,
            decoration: availability == DayAvailability.indisponible && !selected
                ? TextDecoration.lineThrough
                : null,
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot(this.availability);
  final DayAvailability availability;

  @override
  Widget build(BuildContext context) {
    final color = availability == DayAvailability.libre
        ? AppColors.green
        : availability.color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: availability == DayAvailability.libre
                ? AppColors.greenLight
                : availability.background,
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          availability.label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}

/// Bande des 14 prochains jours (fiche véhicule).
class AvailabilityStrip extends StatelessWidget {
  const AvailabilityStrip({super.key, required this.periods, this.days = 14});

  final List<UnavailabilityPeriod> periods;
  final int days;

  @override
  Widget build(BuildContext context) {
    final today = FleetDates.dayOnly(DateTime.now());
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = today.add(Duration(days: index));
          final state = DayAvailability.of(day, periods, today);
          final free = state == DayAvailability.libre;
          return Container(
            width: 46,
            decoration: BoxDecoration(
              color: free ? Colors.white : state.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: index == 0
                    ? AppColors.primaryBlue
                    : (free ? AppColors.cardBorderSubtle : state.background),
                width: index == 0 ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  FrenchDates.dayLetters[day.weekday - 1],
                  style: TextStyle(
                    color: free ? AppColors.textSecondary : state.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${day.day}',
                  style: TextStyle(
                    color: free ? AppColors.textPrimary : state.color,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Choix d'une date (aujourd'hui ou plus tard) avec le calendrier
/// français. Renvoie null si l'utilisateur ferme sans choisir.
Future<DateTime?> showFrenchDatePicker(
  BuildContext context, {
  required String title,
  DateTime? initial,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (sheetContext) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          // Début = fin = date actuelle : le prochain appui choisit un jour.
          AvailabilityCalendar(
            initialStart: initial,
            initialEnd: initial,
            showLegend: false,
            onRangeChanged: (start, _) {
              if (start != null) Navigator.of(sheetContext).pop(start);
            },
          ),
        ],
      ),
    ),
  );
}
