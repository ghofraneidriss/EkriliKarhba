import 'package:flutter/foundation.dart';

import '../../../models/vehicle.dart';
import '../domain/actor.dart';
import '../domain/enums.dart';
import '../domain/fleet_vehicle.dart';
import '../domain/unavailability_period.dart';
import '../domain/vehicle_filter.dart';
import '../services/fleet_service.dart';

/// API interne du module Gestion des véhicules, pour les autres modules
/// de l'équipe (Réservations, Maintenance, Avis…).
///
/// Les autres modules n'ont pas besoin de connaître la base ni les écrans :
/// ils appellent ces fonctions. Les erreurs métier sont levées sous forme
/// de FleetRuleException / FleetValidationException avec un message en
/// français affichable tel quel.
///
/// Les statuts Réservé, Loué et Contrôle retour (affichés « Occupé » dans
/// la gestion des véhicules) ne peuvent être posés que par ces fonctions :
/// l'agence et l'administrateur ne les changent pas à la main.
///
/// Exemple (module Réservations) :
/// ```dart
/// final probleme = await VehicleApi.availabilityProblem(id, debut, fin);
/// if (probleme == null) {
///   final prixJour = await VehicleApi.getPricePerDay(id);
///   final blocage = await VehicleApi.blockForReservation(id, debut, fin, 'RES-42');
///   await VehicleApi.markReserved(id);
/// }
/// ```
class VehicleApi {
  VehicleApi._();

  static FleetService get _service => FleetService.instance;

  static const Actor _reservations = Actor.system('Réservations');
  static const Actor _maintenance = Actor.system('Maintenance');

  /// Notifie chaque modification de la flotte (pour rafraîchir un écran).
  static Listenable get changes => _service;

  // ----------------------------------------------------------- Consultation

  static Future<FleetVehicle?> getVehicle(String vehicleId) =>
      _service.getVehicle(vehicleId);

  /// Véhicules louables : visibles des clients et, si des dates sont
  /// données, libres sur toute la période.
  static Future<List<FleetVehicle>> listRentableVehicles({
    DateTime? from,
    DateTime? to,
    String? city,
    String? categoryId,
  }) {
    final withDates = from != null && to != null;
    return _service.search(
      VehicleFilter(
        availableFrom: withDates ? from : null,
        availableTo: withDates ? to : null,
        city: city,
        categoryId: categoryId,
        statuses: withDates
            ? const <VehicleStatus>{}
            : const <VehicleStatus>{VehicleStatus.disponible},
      ),
      const Actor.client(),
    );
  }

  static Future<bool> isAvailable(
          String vehicleId, DateTime from, DateTime to) =>
      _service.isAvailable(vehicleId, from, to);

  /// Null si le véhicule est louable sur la période, sinon la raison.
  static Future<String?> availabilityProblem(
          String vehicleId, DateTime from, DateTime to) =>
      _service.availabilityProblem(vehicleId, from, to);

  /// Prix de location par jour (DT). Le calcul du total d'une location
  /// reste dans le module Réservations.
  static Future<double?> getPricePerDay(String vehicleId) async =>
      (await _service.getVehicle(vehicleId))?.pricePerDay;

  /// Caution (DT).
  static Future<double?> getDeposit(String vehicleId) async =>
      (await _service.getVehicle(vehicleId))?.deposit;

  // ------------------------------------------------- Pour les Réservations

  /// Bloque les dates d'une réservation ; renvoie l'id du blocage à
  /// conserver pour pouvoir le libérer en cas d'annulation.
  static Future<int> blockForReservation(
    String vehicleId,
    DateTime from,
    DateTime to,
    String reservationRef,
  ) async {
    final period = await _service.addUnavailability(
      UnavailabilityPeriod(
        vehicleId: vehicleId,
        start: from,
        end: to,
        reason: 'Réservation $reservationRef',
      ),
      _reservations,
    );
    return period.id!;
  }

  static Future<void> releaseReservationBlock(int blockId) =>
      _service.removeUnavailability(blockId, _reservations);

  static Future<void> markReserved(String vehicleId) =>
      _service.changeStatus(vehicleId, VehicleStatus.reserve, _reservations);

  static Future<void> cancelReservation(String vehicleId) =>
      _service.changeStatus(vehicleId, VehicleStatus.disponible, _reservations,
          comment: 'Réservation annulée');

  static Future<void> markPickedUp(String vehicleId) =>
      _service.changeStatus(vehicleId, VehicleStatus.loue, _reservations,
          comment: 'Départ du client');

  /// Retour du client : nouveau kilométrage puis contrôle retour.
  static Future<void> markReturned(String vehicleId,
      {required int mileage}) async {
    await _service.updateMileage(vehicleId, mileage, _reservations,
        comment: 'Retour de location');
    await _service.changeStatus(
        vehicleId, VehicleStatus.controleRetour, _reservations,
        comment: 'Retour du client');
  }

  /// Fin du contrôle retour : le véhicule redevient libre, ou part en
  /// maintenance si un [problem] a été constaté.
  static Future<void> finishReturn(String vehicleId, {String? problem}) =>
      _service.changeStatus(
        vehicleId,
        problem == null ? VehicleStatus.disponible : VehicleStatus.maintenance,
        _reservations,
        comment: problem ?? 'Contrôle retour terminé',
      );

  // -------------------------------------------------- Pour la Maintenance

  static Future<void> sendToMaintenance(String vehicleId, {String? reason}) =>
      _service.changeStatus(vehicleId, VehicleStatus.maintenance, _maintenance,
          comment: reason);

  static Future<void> backFromMaintenance(String vehicleId,
      {int? mileage}) async {
    if (mileage != null) {
      await _service.updateMileage(vehicleId, mileage, _maintenance,
          comment: 'Relevé après maintenance');
    }
    await _service.changeStatus(
        vehicleId, VehicleStatus.disponible, _maintenance,
        comment: 'Fin de maintenance');
  }

  static Future<void> updateMileage(String vehicleId, int mileage,
          {String module = 'Maintenance'}) =>
      _service.updateMileage(vehicleId, mileage, Actor.system(module));

  /// Conversion vers le modèle `Vehicle` du module Maintenance
  /// (lib/models/vehicle.dart), sans modifier ce modèle.
  static Vehicle toMaintenanceVehicle(FleetVehicle vehicle,
      {String categoryName = ''}) {
    return Vehicle(
      id: vehicle.id,
      brandAndModel: vehicle.fullName,
      registrationPlate: vehicle.registrationPlate,
      category: categoryName,
      year: vehicle.year,
      currentMileage: vehicle.mileage,
      status: switch (vehicle.status) {
        VehicleStatus.maintenance => 'En maintenance',
        VehicleStatus.horsService => 'En réparation',
        _ => 'Disponible',
      },
      imageAsset: vehicle.mainPhoto ?? '',
    );
  }

  /// Toute la flotte non archivée, au format du module Maintenance.
  static Future<List<Vehicle>> maintenanceVehicles() async {
    final categories = await _service.categoryMap();
    final vehicles = await _service.search(
      const VehicleFilter(),
      const Actor.admin(),
    );
    return vehicles
        .where((v) => v.status != VehicleStatus.archive)
        .map((v) => toMaintenanceVehicle(v,
            categoryName: categories[v.categoryId]?.name ?? ''))
        .toList();
  }
}
