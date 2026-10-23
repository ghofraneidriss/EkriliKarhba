import 'fleet_dates.dart';

/// Période pendant laquelle un véhicule ne peut pas être loué
/// (usage interne, préparation, réservation posée par le module
/// Réservations, etc.). Bornes incluses, dates sans heure.
class UnavailabilityPeriod {
  const UnavailabilityPeriod({
    this.id,
    required this.vehicleId,
    required this.start,
    required this.end,
    this.reason = 'Autre',
  });

  /// Motifs proposés dans l'interface.
  static const List<String> presetReasons = [
    'Usage interne',
    'Préparation',
    'Réservation',
    'Autre',
  ];

  final int? id;
  final String vehicleId;
  final DateTime start;
  final DateTime end;
  final String reason;

  int get days =>
      FleetDates.dayOnly(end).difference(FleetDates.dayOnly(start)).inDays + 1;

  bool overlaps(DateTime otherStart, DateTime otherEnd) =>
      FleetDates.overlaps(start, end, otherStart, otherEnd);

  bool containsDay(DateTime day) => overlaps(day, day);

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'vehicle_id': vehicleId,
        'start_date': FleetDates.toDbDay(start),
        'end_date': FleetDates.toDbDay(end),
        'reason': reason,
      };

  factory UnavailabilityPeriod.fromMap(Map<String, Object?> map) =>
      UnavailabilityPeriod(
        id: map['id'] as int?,
        vehicleId: map['vehicle_id'] as String,
        start: FleetDates.fromDbDay(map['start_date'] as String),
        end: FleetDates.fromDbDay(map['end_date'] as String),
        reason: (map['reason'] as String?) ?? 'Autre',
      );
}
