import 'package:sqflite/sqflite.dart';

import '../../users/data/password_hasher.dart';
import '../../users/domain/user.dart';
import '../domain/enums.dart';
import '../domain/fleet_vehicle.dart';
import '../domain/history_entry.dart';
import '../domain/unavailability_period.dart';
import '../domain/vehicle_category.dart';
import '../domain/vehicle_document.dart';

/// Données de démonstration insérées à la création de la base :
/// 1 admin, 3 utilisateurs agences, 2 clients, 6 catégories, 10 véhicules dans des situations variées
/// (loué, réservé, en maintenance, en attente de validation, assurance
/// expirée…), leurs documents, indisponibilités et historique.
class SeedData {
  SeedData._();

  static const int agencyTunis = 2;
  static const int agencySousse = 3;
  static const int agencySfax = 4;

  static Future<void> insert(Database db, DateTime now) async {
    final batch = db.batch();
    DateTime daysAgo(int d) => now.subtract(Duration(days: d));
    DateTime inDays(int d) => now.add(Duration(days: d));

    final salt = PasswordHasher.generateSalt();
    final users = [
      User(
        id: 1,
        nom: 'Ben Amor',
        prenom: 'Yassine',
        email: 'admin@ekrili.tn',
        motDePasse: PasswordHasher.hashPassword('Admin1234', salt),
        passwordSalt: salt,
        telephone: '20100200',
        role: UserRole.admin,
        statut: UserStatus.actif,
        niveauAcces: 'Super Admin',
        createdAt: daysAgo(500),
        updatedAt: daysAgo(500),
      ),
      User(
        id: agencyTunis,
        nom: 'Ben Salem',
        prenom: 'Ahmed',
        nomAgence: 'Auto Mobility Tunis',
        adresseAgence: 'Rue du Lac Léman, Les Berges du Lac, Tunis',
        email: 'contact@automobility.tn',
        motDePasse: PasswordHasher.hashPassword('Agence1234', salt),
        passwordSalt: salt,
        telephone: '71200340',
        role: UserRole.agence,
        statut: UserStatus.actif,
        createdAt: daysAgo(400),
        updatedAt: daysAgo(400),
      ),
      User(
        id: agencySousse,
        nom: 'Trabelsi',
        prenom: 'Sonia',
        nomAgence: 'Sahel Rent Car',
        adresseAgence: 'Avenue Hédi Chaker, Sousse',
        email: 'reservation@sahelrent.tn',
        motDePasse: PasswordHasher.hashPassword('Agence1234', salt),
        passwordSalt: salt,
        telephone: '73225110',
        role: UserRole.agence,
        statut: UserStatus.actif,
        createdAt: daysAgo(300),
        updatedAt: daysAgo(300),
      ),
      User(
        id: agencySfax,
        nom: 'Karray',
        prenom: 'Firas',
        nomAgence: 'Sfax Location Auto',
        adresseAgence: 'Route de Tunis km 3, Sfax',
        email: 'info@sfaxlocation.tn',
        motDePasse: PasswordHasher.hashPassword('Agence1234', salt),
        passwordSalt: salt,
        telephone: '74400210',
        role: UserRole.agence,
        statut: UserStatus.actif,
        createdAt: daysAgo(200),
        updatedAt: daysAgo(200),
      ),
      User(
        id: 5,
        nom: 'Gharbi',
        prenom: 'Karim',
        email: 'karim@gmail.com',
        motDePasse: PasswordHasher.hashPassword('Client1234', salt),
        passwordSalt: salt,
        telephone: '98123456',
        role: UserRole.client,
        statut: UserStatus.actif,
        createdAt: daysAgo(100),
        updatedAt: daysAgo(100),
      ),
      User(
        id: 6,
        nom: 'Masmoudi',
        prenom: 'Fatma',
        email: 'fatma@gmail.com',
        motDePasse: PasswordHasher.hashPassword('Client1234', salt),
        passwordSalt: salt,
        telephone: '22123456',
        role: UserRole.client,
        statut: UserStatus.actif,
        createdAt: daysAgo(50),
        updatedAt: daysAgo(50),
      ),
    ];

    for (final user in users) {
      batch.insert('users', user.toMap());
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
        description: 'Polyvalentes et confortables, 5 places.',
        minPricePerDay: 70,
        maxPricePerDay: 130,
      ),
      VehicleCategory(
        id: 'cat_compacte',
        name: 'Compacte',
        description: 'Parfaites pour la route comme pour la ville.',
        minPricePerDay: 90,
        maxPricePerDay: 160,
      ),
      VehicleCategory(
        id: 'cat_berline',
        name: 'Berline',
        description: 'Grand confort pour les longs trajets d’affaires.',
        minPricePerDay: 140,
        maxPricePerDay: 260,
      ),
      VehicleCategory(
        id: 'cat_suv',
        name: 'SUV',
        description: 'Position haute, habitacle spacieux et grand coffre.',
        minPricePerDay: 150,
        maxPricePerDay: 320,
      ),
      VehicleCategory(
        id: 'cat_prestige',
        name: 'Prestige',
        description: 'Modèles haut de gamme pour les grandes occasions.',
        minPricePerDay: 280,
        maxPricePerDay: 700,
      ),
    ];
    for (final category in categories) {
      batch.insert('categories', category.toMap());
    }

    FleetVehicle vehicle({
      required String id,
      required int agencyId,
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
        year: 2023,
        plate: '234 TUN 1987',
        color: 'Gris métallisé',
        fuel: FuelType.essence,
        transmission: Transmission.automatique,
        mileage: 42100,
        price: 180,
        deposit: 800,
        description:
            'Berline premium dynamique, GPS connecté, sellerie cuir et toit ouvrant.',
        photos: ['assets/images/bmw_serie_3.jpg'],
        createdDaysAgo: 180,
      ),
      vehicle(
        id: 'veh_peugeot_208',
        agencyId: agencyTunis,
        categoryId: 'cat_citadine',
        brand: 'Peugeot',
        model: '208',
        year: 2022,
        plate: '215 TUN 9841',
        color: 'Blanc Banquise',
        fuel: FuelType.essence,
        transmission: Transmission.manuelle,
        mileage: 38500,
        price: 85,
        deposit: 300,
        status: VehicleStatus.maintenance,
        description:
            'Citadine moderne et très économique, écran tactile CarPlay / Android Auto.',
        photos: ['assets/images/peugeot_208.jpg'],
        createdDaysAgo: 240,
      ),
      vehicle(
        id: 'veh_audi_a4',
        agencyId: agencyTunis,
        categoryId: 'cat_berline',
        brand: 'Audi',
        model: 'A4',
        year: 2023,
        plate: '231 TUN 4512',
        color: 'Noir Mythic',
        fuel: FuelType.diesel,
        transmission: Transmission.automatique,
        mileage: 29400,
        price: 195,
        deposit: 900,
        status: VehicleStatus.loue,
        description:
            'Berline élégante et silencieuse, virtual cockpit, feux Matrix LED.',
        photos: ['assets/images/audi_a4.jpg'],
        createdDaysAgo: 150,
      ),
      vehicle(
        id: 'veh_renault_clio',
        agencyId: agencySousse,
        categoryId: 'cat_citadine',
        brand: 'Renault',
        model: 'Clio 5',
        year: 2021,
        plate: '204 TUN 7731',
        color: 'Rouge Flamme',
        fuel: FuelType.essence,
        transmission: Transmission.manuelle,
        mileage: 61200,
        price: 75,
        deposit: 300,
        description:
            'Polyvalente et agréable sur route, climatisation auto et radar de recul.',
        photos: ['assets/images/renault_clio_5.jpg'],
        createdDaysAgo: 320,
      ),
      vehicle(
        id: 'veh_hyundai_tucson',
        agencyId: agencySfax,
        categoryId: 'cat_suv',
        brand: 'Hyundai',
        model: 'Tucson',
        year: 2023,
        plate: '229 TUN 8804',
        color: 'Bleu Intense',
        fuel: FuelType.diesel,
        transmission: Transmission.automatique,
        mileage: 34100,
        price: 210,
        deposit: 1000,
        status: VehicleStatus.reserve,
        description:
            'SUV familial spacieux au design futuriste, aides à la conduite complètes.',
        photos: ['assets/images/hyundai_tucson.jpg'],
        createdDaysAgo: 140,
      ),
      vehicle(
        id: 'veh_dacia_sandero',
        agencyId: agencySousse,
        categoryId: 'cat_eco',
        brand: 'Dacia',
        model: 'Sandero Stepway',
        year: 2022,
        plate: '219 TUN 3318',
        color: 'Orange Atacama',
        fuel: FuelType.essence,
        transmission: Transmission.manuelle,
        mileage: 47800,
        price: 65,
        deposit: 250,
        validation: ValidationStatus.enAttente,
        description:
            'Robuste, garde au sol surélevée, parfaite pour toutes les routes.',
        photos: ['assets/images/dacia_sandero.jpg'],
        createdDaysAgo: 210,
      ),
      vehicle(
        id: 'veh_golf_8',
        agencyId: agencySfax,
        categoryId: 'cat_compacte',
        brand: 'Volkswagen',
        model: 'Golf 8',
        year: 2022,
        plate: '221 TUN 5142',
        color: 'Gris Lunaire',
        fuel: FuelType.essence,
        transmission: Transmission.automatique,
        mileage: 41300,
        price: 135,
        deposit: 600,
        description:
            'Compacte de référence, tableau de bord numérique, tenue de route irréprochable.',
        photos: ['assets/images/golf_8.jpg'],
        createdDaysAgo: 190,
      ),
      vehicle(
        id: 'veh_mercedes_c',
        agencyId: agencyTunis,
        categoryId: 'cat_prestige',
        brand: 'Mercedes-Benz',
        model: 'Classe C',
        year: 2024,
        plate: '235 TUN 1290',
        color: 'Blanc Polaire',
        fuel: FuelType.hybride,
        transmission: Transmission.automatique,
        mileage: 12400,
        price: 340,
        deposit: 1500,
        description:
            'Luxe contemporain, technologie MBUX dernière génération, confort exceptionnel.',
        photos: ['assets/images/mercedes_c.jpg'],
        createdDaysAgo: 60,
      ),
      vehicle(
        id: 'veh_kia_picanto',
        agencyId: agencySousse,
        categoryId: 'cat_eco',
        brand: 'Kia',
        model: 'Picanto',
        year: 2023,
        plate: '230 TUN 6419',
        color: 'Jaune Miel',
        fuel: FuelType.essence,
        transmission: Transmission.manuelle,
        mileage: 18900,
        price: 55,
        deposit: 200,
        description:
            'Mini-citadine ultra maniable, consommation minime, idéale petits trajets.',
        photos: ['assets/images/kia_picanto.jpg'],
        createdDaysAgo: 10,
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
              ? 'Administrateur'
              : 'Agence',
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
        actor: 'Administrateur',
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
