import 'fleet_dates.dart';
import 'fleet_vehicle.dart';
import 'vehicle_document.dart';

/// Notification pour le gestionnaire d'agence : un document d'un véhicule
/// expire bientôt (dans les 30 jours) ou est déjà expiré.
class DocumentAlert {
  const DocumentAlert({
    required this.vehicle,
    required this.document,
    required this.daysLeft,
  });

  /// Crée l'alerte si le document expire dans [withinDays] jours ou moins
  /// (ou est déjà expiré), sinon null.
  static DocumentAlert? of(
    FleetVehicle vehicle,
    VehicleDocument document,
    DateTime now, {
    int withinDays = VehicleDocument.warningDays,
  }) {
    final expiry = document.expiryDate;
    if (expiry == null) return null;
    final days = daysBetween(now, expiry);
    if (days > withinDays) return null;
    return DocumentAlert(vehicle: vehicle, document: document, daysLeft: days);
  }

  /// Nombre de jours calendaires de [from] à [to] (négatif si [to] est
  /// passé). Calcul en UTC pour ne pas être faussé par l'heure d'été.
  static int daysBetween(DateTime from, DateTime to) =>
      DateTime.utc(to.year, to.month, to.day)
          .difference(DateTime.utc(from.year, from.month, from.day))
          .inDays;

  final FleetVehicle vehicle;
  final VehicleDocument document;

  /// Jours restants avant l'expiration (négatif : expiré depuis N jours).
  final int daysLeft;

  bool get expired => daysLeft < 0;

  /// Assurance ou visite technique : le véhicule ne peut pas être loué
  /// une fois le document expiré.
  bool get blocksRental => document.type.blocksRentalWhenExpired;

  /// Clé unique, pour savoir si la notification a déjà été fermée.
  String get key =>
      '${vehicle.id}|${document.type.name}|${FleetDates.toDbDay(document.expiryDate!)}';

  /// « expire dans 12 jours », « expire aujourd'hui », « expirée depuis 5 jours ».
  String get delayLabel {
    if (daysLeft == 0) return "expire aujourd'hui";
    if (daysLeft == 1) return 'expire demain';
    if (daysLeft > 1) return 'expire dans $daysLeft jours';
    // Les quatre documents sont féminins : assurance, visite, vignette, carte.
    final overdue = -daysLeft;
    return overdue == 1
        ? 'expirée depuis hier'
        : 'expirée depuis $overdue jours';
  }

  /// « Visite technique · expire dans 12 jours (03/11/2026) ».
  String get summary =>
      '${document.type.label} · $delayLabel '
      '(${FleetDates.display(document.expiryDate!)})';
}
