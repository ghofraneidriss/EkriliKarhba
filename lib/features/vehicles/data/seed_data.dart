import 'package:sqflite/sqflite.dart';

import '../domain/agency.dart';
import '../domain/enums.dart';
import '../domain/fleet_vehicle.dart';
import '../domain/history_entry.dart';
import '../domain/unavailability_period.dart';
import '../domain/vehicle_category.dart';
import '../domain/vehicle_document.dart';

/// Données de démonstration insérées à la création de la base :
/// 3 agences, 6 catégories, 10 véhicules dans des situations variées
/// (loué, réservé, en maintenance, en attente de validation, assurance
/// expirée…), leurs documents, indisponibilités et historique.
///
/// Les identifiants veh_bmw_3, veh_peugeot_208 et veh_renault_clio sont
/// les mêmes que dans lib/data/mock_data.dart (module Maintenance).
class SeedData {
  SeedData._();

  static const String agencyTunis = 'ag_tunis';
  static const String agencySousse = 'ag_sousse';
  static const String agencySfax = 'ag_sfax';

  static Future<void> insert(Database db, DateTime now) async {
    final batch = db.batch();
    DateTime daysAgo(int d) => now.subtract(Duration(days: d));
    DateTime inDays(int d) => now.add(Duration(days: d));

    final agencies = [
      Agency(
        id: agencyTunis,
        name: 'Auto Mobility Tunis',
        city: 'Tunis',
        address: 'Rue du Lac Léman, Les Berges du Lac',
        phone: '+216 71 200 340',
        email: 'contact@automobility.tn',
        createdAt: daysAgo(400),
      ),
      Agency(
        id: agencySousse,
        name: 'Sahel Rent Car',
        city: 'Sousse',
        address: 'Avenue Hédi Chaker, Sousse',
        phone: '+216 73 225 110',
        email: 'reservation@sahelrent.tn',
        createdAt: daysAgo(300),
      ),
      Agency(
        id: agencySfax,
        name: 'Sfax Location Auto',
        city: 'Sfax',
        address: 'Route de Tunis km 3, Sfax',
        phone: '+216 74 400 210',
        email: 'info@sfaxlocation.tn',
        createdAt: daysAgo(200),
      ),
    ];
    for (final agency in agencies) {
      batch.insert('agencies', agency.toMap());
    }

    const categories = [
      VehicleCategory(
        id: 'cat_eco',
        name: 'Économique',
        description: 'Petites voitures sobres, idéales pour la ville.',
        minPricePerDay: 45,
        maxPricePerDay: 90,
      ),
      VehicleCategory(
        id: 'cat_citadine',
        name: 'Citadine',
        description: 'Polyvalentes, confortables en ville et sur route.',
        minPricePerDay: 60,
        maxPricePerDay: 120,
      ),
      VehicleCategory(
        id: 'cat_berline',
        name: 'Berline',
        description: 'Confort et espace pour les longs trajets.',
        minPricePerDay: 120,
        maxPricePerDay: 260,
      ),
      VehicleCategory(
        id: 'cat_suv',
        name: 'SUV',
        description: 'Position haute et grand coffre.',
        minPricePerDay: 130,
        maxPricePerDay: 300,
      ),
      VehicleCategory(
        id: 'cat_luxe',
        name: 'Luxe',
        description: 'Véhicules haut de gamme.',
        minPricePerDay: 250,
        maxPricePerDay: 700,
      ),
      VehicleCategory(
        id: 'cat_utilitaire',
        name: 'Utilitaire',
        description: 'Transport de marchandises et déménagements.',
        minPricePerDay: 90,
        maxPricePerDay: 200,
      ),
    ];
    for (final category in categories) {
      batch.insert('categories', category.toMap());
    }

    FleetVehicle vehicle({
      required String id,
      required String agencyId,
      required String categoryId,
      required String brand,
      required String model,
      required int year,
      required String plate,
      required String color,
      required FuelType fuel,
      required Transmission transmission,
      int seats = 5,
      int doors = 5,
      required int mileage,
      required double price,
      required double deposit,
      VehicleStatus status = VehicleStatus.disponible,
      ValidationStatus validation = ValidationStatus.valide,
      String description = '',
      List<String> photos = const [],
      required int createdDaysAgo,
    }) {
      return FleetVehicle(
        id: id,
        agencyId: agencyId,
        categoryId: categoryId,
        brand: brand,
        model: model,
        year: year,
        registrationPlate: plate,
        color: color,
        fuel: fuel,
        transmission: transmission,
        seats: seats,
        doors: doors,
        mileage: mileage,
        pricePerDay: price,
        deposit: deposit,
        status: status,
        validation: validation,
        description: description,
        photos: photos,
        createdAt: daysAgo(createdDaysAgo),
        updatedAt: daysAgo(createdDaysAgo),
      );
    }

    final vehicles = [
      vehicle(
        id: 'veh_bmw_3',
        agencyId: agencyTunis,
        categoryId: 'cat_berline',
        brand: 'BMW',
        model: 'Série 3',
        year: 2024,
        plate: '234 TUN 1987',
        color: 'Bleu nuit',
        fuel: FuelType.essence,
        transmission: Transmission.automatique,
        doors: 4,
        mileage: 82450,
        price: 180,
        deposit: 800,
        description: 'Berline premium élégante, confortable et parfaitement '
            'entretenue. Idéale pour la ville et les longs trajets.',
        photos: const ['assets/images/bmw_serie3.jpg'],
        createdDaysAgo: 120,
      ),
      vehicle(
        id: 'veh_peugeot_208',
        agencyId: agencyTunis,
        categoryId: 'cat_citadine',
        brand: 'Peugeot',
        model: '208',
        year: 2023,
        plate: '201 TUN 5521',
        color: 'Blanc nacré',
        fuel: FuelType.essence,
        transmission: Transmission.manuelle,
        mileage: 92450,
        price: 95,
        deposit: 400,
        status: VehicleStatus.maintenance,
        description: 'Citadine agile et économique, parfaite pour la ville.',
        photos: const ['assets/images/peugeot_208.jpg'],
        createdDaysAgo: 110,
      ),
      vehicle(
        id: 'veh_renault_clio',
        agencyId: agencySousse,
        categoryId: 'cat_citadine',
        brand: 'Renault',
        model: 'Clio',
        year: 2022,
        plate: '189 TUN 4520',
        color: 'Gris titanium',
        fuel: FuelType.diesel,
        transmission: Transmission.manuelle,
        mileage: 85000,
        price: 85,
        deposit: 400,
        description: 'La citadine la plus demandée : sobre et spacieuse.',
        photos: const ['assets/images/renault_clio.jpg'],
        createdDaysAgo: 100,
      ),
      vehicle(
        id: 'veh_audi_a4',
        agencyId: agencyTunis,
        categoryId: 'cat_berline',
        brand: 'Audi',
        model: 'A4',
        year: 2023,
        plate: '245 TUN 3310',
        color: 'Noir mythe',
        fuel: FuelType.diesel,
        transmission: Transmission.automatique,
        doors: 4,
        mileage: 41200,
        price: 165,
        deposit: 800,
        status: VehicleStatus.loue,
        description: 'Berline allemande raffinée, boîte automatique.',
        createdDaysAgo: 90,
      ),
      vehicle(
        id: 'veh_kia_picanto',
        agencyId: agencySousse,
        categoryId: 'cat_eco',
        brand: 'Kia',
        model: 'Picanto',
        year: 2024,
        plate: '250 TUN 1204',
        color: 'Rouge',
        fuel: FuelType.essence,
        transmission: Transmission.manuelle,
        seats: 4,
        mileage: 18900,
        price: 70,
        deposit: 300,
        description: 'Petite, maniable et très économique.',
        createdDaysAgo: 60,
      ),
      vehicle(
        id: 'veh_hyundai_tucson',
        agencyId: agencySfax,
        categoryId: 'cat_suv',
        brand: 'Hyundai',
        model: 'Tucson',
        year: 2023,
        plate: '238 TUN 7781',
        color: 'Gris amazone',
        fuel: FuelType.diesel,
        transmission: Transmission.automatique,
        mileage: 56300,
        price: 150,
        deposit: 1000,
        status: VehicleStatus.reserve,
        description: 'SUV familial spacieux avec grand coffre.',
        createdDaysAgo: 80,
      ),
      vehicle(
        id: 'veh_vw_caddy',
        agencyId: agencySfax,
        categoryId: 'cat_utilitaire',
        brand: 'Volkswagen',
        model: 'Caddy',
        year: 2021,
        plate: '221 TUN 9043',
        color: 'Blanc',
        fuel: FuelType.diesel,
        transmission: Transmission.manuelle,
        doors: 4,
        mileage: 120400,
        price: 110,
        deposit: 600,
        description: 'Utilitaire pratique, 3,2 m³ de chargement.',
        createdDaysAgo: 150,
      ),
      vehicle(
        id: 'veh_mercedes_c',
        agencyId: agencyTunis,
        categoryId: 'cat_luxe',
        brand: 'Mercedes-Benz',
        model: 'Classe C',
        year: 2025,
        plate: '252 TUN 0088',
        color: 'Noir obsidienne',
        fuel: FuelType.hybride,
        transmission: Transmission.automatique,
        doors: 4,
        mileage: 6200,
        price: 320,
        deposit: 1500,
        description: 'Hybride haut de gamme, équipement complet.',
        createdDaysAgo: 30,
      ),
      vehicle(
        id: 'veh_dacia_sandero',
        agencyId: agencySousse,
        categoryId: 'cat_eco',
        brand: 'Dacia',
        model: 'Sandero',
        year: 2024,
        plate: '251 TUN 6612',
        color: 'Bleu iron',
        fuel: FuelType.essence,
        transmission: Transmission.manuelle,
        mileage: 12000,
        price: 65,
        deposit: 300,
        validation: ValidationStatus.enAttente,
        description: 'Ajoutée par l\'agence, en attente de validation.',
        createdDaysAgo: 2,
      ),
      vehicle(
        id: 'veh_toyota_yaris',
        agencyId: agencySfax,
        categoryId: 'cat_citadine',
        brand: 'Toyota',
        model: 'Yaris',
        year: 2020,
        plate: '199 TUN 3021',
        color: 'Gris',
        fuel: FuelType.hybride,
        transmission: Transmission.automatique,
        mileage: 110800,
        price: 90,
        deposit: 400,
        description: 'Hybride très sobre. Assurance à renouveler.',
        createdDaysAgo: 200,
      ),
    ];
    for (final v in vehicles) {
      batch.insert('vehicles', v.toMap());
      batch.insert(
        'vehicle_history',
        HistoryEntry(
          vehicleId: v.id,
          timestamp: v.createdAt,
          actor: v.validation == ValidationStatus.valide
              ? UserRole.admin.label
              : UserRole.agence.label,
          action: HistoryAction.creation,
          comment: 'Ajout du véhicule ${v.fullName} (${v.registrationPlate})',
        ).toMap(),
      );
    }

    // Documents : tout est en règle, sauf deux cas de démonstration.
    for (final v in vehicles) {
      final assuranceExpiry =
          v.id == 'veh_toyota_yaris' ? daysAgo(5) : inDays(200);
      final visiteExpiry =
          v.id == 'veh_peugeot_208' ? inDays(12) : inDays(140);
      batch.insert(
        'vehicle_documents',
        VehicleDocument(
          vehicleId: v.id,
          type: DocumentType.assurance,
          reference: 'ASS-${v.registrationPlate.replaceAll(' ', '')}',
          expiryDate: assuranceExpiry,
        ).toMap(),
      );
      batch.insert(
        'vehicle_documents',
        VehicleDocument(
          vehicleId: v.id,
          type: DocumentType.visiteTechnique,
          reference: 'VT-${v.registrationPlate.replaceAll(' ', '')}',
          expiryDate: visiteExpiry,
        ).toMap(),
      );
      batch.insert(
        'vehicle_documents',
        VehicleDocument(
          vehicleId: v.id,
          type: DocumentType.carteGrise,
          reference: v.registrationPlate,
        ).toMap(),
      );
    }

    final periods = [
      UnavailabilityPeriod(
        vehicleId: 'veh_bmw_3',
        start: inDays(5),
        end: inDays(7),
        reason: 'Usage interne',
      ),
      UnavailabilityPeriod(
        vehicleId: 'veh_bmw_3',
        start: inDays(12),
        end: inDays(14),
        reason: 'Préparation',
      ),
      UnavailabilityPeriod(
        vehicleId: 'veh_audi_a4',
        start: daysAgo(2),
        end: inDays(3),
        reason: 'Réservation',
      ),
      UnavailabilityPeriod(
        vehicleId: 'veh_hyundai_tucson',
        start: inDays(2),
        end: inDays(6),
        reason: 'Réservation',
      ),
    ];
    for (final period in periods) {
      batch.insert('unavailabilities', period.toMap());
    }

    final history = [
      HistoryEntry(
        vehicleId: 'veh_bmw_3',
        timestamp: daysAgo(30),
        actor: UserRole.admin.label,
        action: HistoryAction.prix,
        field: 'Prix par jour',
        oldValue: '160 DT',
        newValue: '180 DT',
        comment: 'Alignement sur la haute saison',
      ),
      HistoryEntry(
        vehicleId: 'veh_peugeot_208',
        timestamp: daysAgo(3),
        actor: 'Module Maintenance',
        action: HistoryAction.statut,
        field: 'Statut',
        oldValue: VehicleStatus.disponible.label,
        newValue: VehicleStatus.maintenance.label,
        comment: 'Entretien en retard',
      ),
      HistoryEntry(
        vehicleId: 'veh_audi_a4',
        timestamp: daysAgo(2),
        actor: 'Module Réservations',
        action: HistoryAction.statut,
        field: 'Statut',
        oldValue: VehicleStatus.reserve.label,
        newValue: VehicleStatus.loue.label,
        comment: 'Départ du client',
      ),
    ];
    for (final entry in history) {
      batch.insert('vehicle_history', entry.toMap());
    }

    batch.insert('favorites', {
      'vehicle_id': 'veh_bmw_3',
      'created_at': daysAgo(1).toIso8601String(),
    });

    await batch.commit(noResult: true);
  }
}
