import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/unavailability_period.dart';
import '../../services/demo_session.dart';
import '../../services/fleet_service.dart';
import '../feedback.dart';
import '../widgets/availability_calendar.dart';

/// Blocage d'une période (usage interne, préparation…). Les blocages
/// « Réservation » sont posés par le module Réservations via VehicleApi.
Future<void> showUnavailabilitySheet(
  BuildContext context, {
  required String vehicleId,
  required List<UnavailabilityPeriod> periods,
}) {
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => _UnavailabilitySheet(
      vehicleId: vehicleId,
      periods: periods,
      messenger: messenger,
    ),
  );
}

class _UnavailabilitySheet extends StatefulWidget {
  const _UnavailabilitySheet({
    required this.vehicleId,
    required this.periods,
    required this.messenger,
  });

  final String vehicleId;
  final List<UnavailabilityPeriod> periods;
  final ScaffoldMessengerState messenger;

  @override
  State<_UnavailabilitySheet> createState() => _UnavailabilitySheetState();
}

class _UnavailabilitySheetState extends State<_UnavailabilitySheet> {
  static const List<String> _reasons = ['Usage interne', 'Préparation', 'Autre'];

  DateTime? _start;
  DateTime? _end;
  String _reason = _reasons.first;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    final start = _start;
    if (start == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await FleetService.instance.addUnavailability(
        UnavailabilityPeriod(
          vehicleId: widget.vehicleId,
          start: start,
          end: _end ?? start,
          reason: _reason,
        ),
        DemoSession.instance.actor,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      showFleetSnack(widget.messenger, 'Période bloquée');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = fleetErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = _start;
    final end = _end ?? _start;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Bloquer une période',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Touchez le premier puis le dernier jour. Les jours déjà bloqués '
            'sont en rouge ou en bleu.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          AvailabilityCalendar(
            periods: widget.periods,
            onRangeChanged: (s, e) => setState(() {
              _start = s;
              _end = e;
              _error = null;
            }),
          ),
          const SizedBox(height: 12),
          const Text(
            'Motif',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final reason in _reasons)
                ChoiceChip(
                  label: Text(reason),
                  selected: _reason == reason,
                  showCheckmark: false,
                  selectedColor: AppColors.primaryNavy,
                  labelStyle: TextStyle(
                    color:
                        _reason == reason ? Colors.white : AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                  onSelected: (_) => setState(() => _reason = reason),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.redDark, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: start == null || _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              start == null || end == null
                  ? 'Choisissez les dates'
                  : start == end
                      ? 'Bloquer le ${FrenchDates.shortDay(start)}'
                      : 'Bloquer du ${FrenchDates.shortDay(start)} '
                          'au ${FrenchDates.shortDay(end)}',
            ),
          ),
        ],
      ),
    );
  }
}
