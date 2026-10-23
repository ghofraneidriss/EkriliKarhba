import 'package:ekrili_karhba/features/vehicles/data/fleet_database.dart';
import 'package:ekrili_karhba/features/vehicles/data/fleet_repository.dart';
import 'package:ekrili_karhba/features/vehicles/domain/actor.dart';
import 'package:ekrili_karhba/features/vehicles/domain/document_alert.dart';
import 'package:ekrili_karhba/features/vehicles/domain/enums.dart';
import 'package:ekrili_karhba/features/vehicles/domain/fleet_exceptions.dart';
import 'package:ekrili_karhba/features/vehicles/domain/fleet_vehicle.dart';
import 'package:ekrili_karhba/features/vehicles/domain/unavailability_period.dart';
import 'package:ekrili_karhba/features/vehicles/domain/vehicle_document.dart';
import 'package:ekrili_karhba/features/vehicles/domain/vehicle_filter.dart';
import 'package:ekrili_karhba/features/vehicles/services/fleet_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Tests des règles métier du module Véhicules, sur une base SQLite en
/// mémoire remplie avec les données de démonstration.
void main() {
  final now = DateTime(2026, 10, 22, 10);
  const admin = Actor.admin();
  const client = Actor.client();
  const tunis = Actor.agency('ag_tunis');
  const sousse = Actor.agency('ag_sousse');
  const sfax = Actor.agency('ag_sfax');
  const reservations = Actor.system('Réservations');

  late FleetService service;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    final database = FleetDatabase(
      factory: databaseFactoryFfi,
      path: ':memory:',
      clock: () => now,
    );
    service = FleetService(
      repository: FleetRepository(database),
      clock: () => now,
    );
    await service.ensureReady();
  });

  tearDown(() => service.closeDatabase());

  FleetVehicle draft({
    String agencyId = 'ag_sousse',
    String categoryId = 'cat_citadine',
    String plate = '260 TUN 1111',
    double price = 80,
    int mileage = 1000,
  }) {
    return FleetVehicle(
      id: 'tmp',
      agencyId: agencyId,
      categoryId: categoryId,
      brand: 'Seat',
      model: 'Ibiza',
      year: 2024,
      registrationPlate: plate,
      pricePerDay: price,
      deposit: 300,
      mileage: mileage,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('Visibilité selon le profil', () {
    test("l'admin voit toute la flotte", () async {
      final all = await service.search(const VehicleFilter(), admin);
      expect(all, hasLength(10));
    });

    test('le client ne voit que les véhicules louables et validés', () async {
      final visible = await service.search(const VehicleFilter(), client);
      final ids = visible.map((v) => v.id).toSet();
      expect(ids, hasLength(7));
      expect(ids, isNot(contains('veh_dacia_sandero'))); // en attente
      expect(ids, isNot(contains('veh_peugeot_208'))); // maintenance
      expect(ids, isNot(contains('veh_toyota_yaris'))); // hors service
    });

    test("une agence ne voit que sa flotte", () async {
      final mine = await service.search(const VehicleFilter(), sousse);
      expect(mine.map((v) => v.agencyId).toSet(), {'ag_sousse'});
      expect(mine, hasLength(3));
    });

    test('fiche détaillée : mêmes règles de visibilité', () async {
      expect(await service.getVehicleFor('veh_bmw_3', client), isNotNull);
      // En maintenance : invisible pour le client, visible pour son agence.
      expect(await service.getVehicleFor('veh_peugeot_208', client), isNull);
      expect(await service.getVehicleFor('veh_peugeot_208', tunis), isNotNull);
      // Véhicule d'une autre agence : invisible.
      expect(await service.getVehicleFor('veh_renault_clio', tunis), isNull);
      expect(await service.getVehicleFor('veh_renault_clio', admin), isNotNull);
    });

    test('fiche détaillée : retirée en direct quand le véhicule change',
        () async {
      var notifications = 0;
      service.addListener(() => notifications++);
      await service.changeStatus(
          'veh_bmw_3', VehicleStatus.maintenance, tunis);
      expect(notifications, greaterThan(0));
      expect(await service.getVehicleFor('veh_bmw_3', client), isNull);
    });
  });

  group('Documents', () {
    test('assurance expirée : véhicule mis hors service au démarrage',
        () async {
      final yaris = await service.getVehicle('veh_toyota_yaris');
      expect(yaris!.status, VehicleStatus.horsService);
      final history = await service.history('veh_toyota_yaris');
      expect(history.first.actor, 'Système');
    });

    test('impossible de remettre disponible avant renouvellement', () async {
      await expectLater(
        service.changeStatus(
            'veh_toyota_yaris', VehicleStatus.disponible, admin),
        throwsA(isA<FleetRuleException>()),
      );
      final docs = await service.documents('veh_toyota_yaris');
      final assurance =
          docs.firstWhere((d) => d.type == DocumentType.assurance);
      await service.saveDocument(
        assurance.copyWith(expiryDate: now.add(const Duration(days: 365))),
        admin,
      );
      final updated = await service.changeStatus(
          'veh_toyota_yaris', VehicleStatus.disponible, admin);
      expect(updated.status, VehicleStatus.disponible);
    });

    test('un seul document par type et par véhicule', () async {
      await expectLater(
        service.saveDocument(
          VehicleDocument(
            vehicleId: 'veh_bmw_3',
            type: DocumentType.assurance,
            expiryDate: now.add(const Duration(days: 100)),
          ),
          admin,
        ),
        throwsA(isA<FleetRuleException>()),
      );
    });
  });

  group('Ajout et modification', () {
    test("un véhicule ajouté par une agence attend la validation", () async {
      final created = await service.createVehicle(draft(), sousse);
      expect(created.validation, ValidationStatus.enAttente);
      expect(created.agencyId, 'ag_sousse');
      final history = await service.history(created.id);
      expect(history.single.action, HistoryAction.creation);
    });

    test('ajouté par l\'admin : validé directement', () async {
      final created = await service.createVehicle(draft(), admin);
      expect(created.validation, ValidationStatus.valide);
    });

    test('un client ne peut pas ajouter de véhicule', () async {
      await expectLater(
        service.createVehicle(draft(), client),
        throwsA(isA<FleetPermissionException>()),
      );
    });

    test('matricule unique et normalisé', () async {
      final created =
          await service.createVehicle(draft(plate: '260tun1111'), admin);
      expect(created.registrationPlate, '260 TUN 1111');
      await expectLater(
        service.createVehicle(draft(plate: '234 TUN 1987'), admin),
        throwsA(isA<FleetValidationException>()
            .having((e) => e.field, 'field', 'registrationPlate')),
      );
    });

    test('le prix doit rester dans la fourchette de la catégorie', () async {
      await expectLater(
        service.createVehicle(draft(price: 500), admin),
        throwsA(isA<FleetValidationException>()
            .having((e) => e.field, 'field', 'pricePerDay')),
      );
    });

    test('le kilométrage ne peut pas diminuer', () async {
      final bmw = await service.getVehicle('veh_bmw_3');
      await expectLater(
        service.updateVehicle(bmw!.copyWith(mileage: 1000), admin),
        throwsA(isA<FleetValidationException>()),
      );
    });

    test('un changement de prix est historisé', () async {
      final bmw = await service.getVehicle('veh_bmw_3');
      await service.updateVehicle(bmw!.copyWith(pricePerDay: 200), tunis);
      final history = await service.history('veh_bmw_3');
      final last = history.first;
      expect(last.action, HistoryAction.prix);
      expect(last.oldValue, '180 DT');
      expect(last.newValue, '200 DT');
    });

    test("une agence ne modifie pas le véhicule d'une autre", () async {
      final clio = await service.getVehicle('veh_renault_clio');
      await expectLater(
        service.updateVehicle(clio!.copyWith(pricePerDay: 90), tunis),
        throwsA(isA<FleetPermissionException>()),
      );
    });
  });

  group('Cycle de vie', () {
    test('passage interdit : Disponible → Loué', () async {
      await expectLater(
        service.changeStatus('veh_bmw_3', VehicleStatus.loue, reservations),
        throwsA(isA<FleetRuleException>()),
      );
    });

    test('cycle complet de location (module Réservations)', () async {
      for (final status in [
        VehicleStatus.reserve,
        VehicleStatus.loue,
        VehicleStatus.controleRetour,
        VehicleStatus.disponible,
      ]) {
        final v =
            await service.changeStatus('veh_bmw_3', status, reservations);
        expect(v.status, status);
      }
      final history = await service.history('veh_bmw_3');
      expect(history.first.actor, contains('Réservations'));
    });

    test("occupé / libre : ni l'agence ni l'admin ne le changent", () async {
      // Mettre « occupé » à la main : refusé.
      await expectLater(
        service.changeStatus('veh_bmw_3', VehicleStatus.reserve, tunis),
        throwsA(isA<FleetRuleException>()),
      );
      await expectLater(
        service.changeStatus('veh_bmw_3', VehicleStatus.reserve, admin),
        throwsA(isA<FleetRuleException>()),
      );
      // Libérer à la main un véhicule occupé : refusé aussi.
      await expectLater(
        service.changeStatus('veh_hyundai_tucson', VehicleStatus.disponible,
            sfax),
        throwsA(isA<FleetRuleException>()),
      );
      await expectLater(
        service.changeStatus(
            'veh_audi_a4', VehicleStatus.controleRetour, admin),
        throwsA(isA<FleetRuleException>()),
      );
      // Les autres statuts restent gérés par l'agence.
      final v = await service.changeStatus(
          'veh_bmw_3', VehicleStatus.maintenance, tunis);
      expect(v.status, VehicleStatus.maintenance);
    });

    test('statistiques : réservé, loué et retour comptent comme occupés',
        () async {
      final stats = await service.computeStats();
      expect(stats.occupied, 2); // Audi A4 (loué) + Tucson (réservé)
      expect(VehicleStatus.controleRetour.fleetLabel, 'Occupé');
      expect(VehicleStatus.maintenance.fleetLabel, 'Maintenance');
    });

    test('un véhicule loué ne peut pas être supprimé', () async {
      await expectLater(
        service.deleteVehicle('veh_audi_a4', admin),
        throwsA(isA<FleetRuleException>()),
      );
    });

    test("la suppression conserve l'historique", () async {
      await service.deleteVehicle('veh_bmw_3', admin);
      expect(await service.getVehicle('veh_bmw_3'), isNull);
      final history = await service.history('veh_bmw_3');
      expect(history.first.action, HistoryAction.suppression);
    });
  });

  group('Notifications papiers', () {
    test("l'agence est prévenue des documents qui expirent sous 30 jours",
        () async {
      final alerts = await service.documentAlerts(tunis);
      final alert = alerts.single;
      expect(alert.vehicle.id, 'veh_peugeot_208');
      expect(alert.document.type, DocumentType.visiteTechnique);
      expect(alert.daysLeft, 12);
      expect(alert.expired, isFalse);
      expect(alert.delayLabel, 'expire dans 12 jours');
    });

    test('document déjà expiré : notification « expirée »', () async {
      final alert = (await service.documentAlerts(sfax)).single;
      expect(alert.vehicle.id, 'veh_toyota_yaris');
      expect(alert.document.type, DocumentType.assurance);
      expect(alert.expired, isTrue);
      expect(alert.delayLabel, 'expirée depuis 5 jours');
    });

    test("agence sans papiers à renouveler : aucune notification", () async {
      expect(await service.documentAlerts(sousse), isEmpty);
    });

    test("l'admin voit toute la flotte, du plus urgent au moins urgent",
        () async {
      final alerts = await service.documentAlerts(admin);
      expect(alerts.map((a) => a.vehicle.id),
          ['veh_toyota_yaris', 'veh_peugeot_208']);
    });

    test('un client ne reçoit pas ces notifications', () async {
      await expectLater(
        service.documentAlerts(client),
        throwsA(isA<FleetPermissionException>()),
      );
    });

    test('document renouvelé : la notification disparaît', () async {
      final alert = (await service.documentAlerts(tunis)).single;
      await service.saveDocument(
        alert.document.copyWith(
            expiryDate: now.add(const Duration(days: 365))),
        tunis,
      );
      expect(await service.documentAlerts(tunis), isEmpty);
    });

    test('nouveau document qui expire dans 20 jours : notifié', () async {
      await service.saveDocument(
        VehicleDocument(
          vehicleId: 'veh_mercedes_c',
          type: DocumentType.vignette,
          expiryDate: now.add(const Duration(days: 20)),
        ),
        tunis,
      );
      final alerts = await service.documentAlerts(tunis);
      expect(alerts.map((a) => a.vehicle.id),
          ['veh_peugeot_208', 'veh_mercedes_c']);
    });

    test('calcul des jours', () {
      expect(DocumentAlert.daysBetween(now, DateTime(2026, 10, 22)), 0);
      expect(DocumentAlert.daysBetween(now, DateTime(2026, 11, 21)), 30);
      expect(DocumentAlert.daysBetween(now, DateTime(2026, 10, 20)), -2);
    });
  });

  group('Multi-agences et validation', () {
    test("transfert par l'admin, historisé", () async {
      final moved =
          await service.transferVehicle('veh_renault_clio', 'ag_tunis', admin);
      expect(moved.agencyId, 'ag_tunis');
      final history = await service.history('veh_renault_clio');
      expect(history.first.action, HistoryAction.transfert);
      expect(history.first.oldValue, 'Sahel Rent Car');
    });

    test('une agence ne peut pas transférer', () async {
      await expectLater(
        service.transferVehicle('veh_renault_clio', 'ag_tunis', sousse),
        throwsA(isA<FleetPermissionException>()),
      );
    });

    test('pas de transfert pour un véhicule réservé', () async {
      await expectLater(
        service.transferVehicle('veh_hyundai_tucson', 'ag_tunis', admin),
        throwsA(isA<FleetRuleException>()),
      );
    });

    test('validation : le véhicule devient visible des clients', () async {
      await service.reviewVehicle('veh_dacia_sandero',
          approve: true, actor: admin);
      final visible = await service.search(const VehicleFilter(), client);
      expect(visible.map((v) => v.id), contains('veh_dacia_sandero'));
    });

    test('un refus doit être motivé', () async {
      await expectLater(
        service.reviewVehicle('veh_dacia_sandero',
            approve: false, actor: admin),
        throwsA(isA<FleetValidationException>()),
      );
    });

    test('agence désactivée : ses véhicules sortent du catalogue', () async {
      await service.setAgencyActive('ag_sousse', false, admin);
      final visible = await service.search(const VehicleFilter(), client);
      expect(visible.map((v) => v.agencyId), isNot(contains('ag_sousse')));
    });

    test('pas de désactivation si un véhicule est loué', () async {
      await expectLater(
        service.setAgencyActive('ag_tunis', false, admin),
        throwsA(isA<FleetRuleException>()),
      );
    });

    test("pas de suppression d'une agence qui a des véhicules", () async {
      await expectLater(
        service.deleteAgency('ag_sfax', admin),
        throwsA(isA<FleetRuleException>()),
      );
    });

    test('validation impossible sans assurance ni visite technique',
        () async {
      final created = await service.createVehicle(draft(), sousse);
      expect(await service.validationProblems(created.id),
          ['Assurance manquante', 'Visite technique manquante']);
      await expectLater(
        service.reviewVehicle(created.id, approve: true, actor: admin),
        throwsA(isA<FleetRuleException>()),
      );
      for (final type in [
        DocumentType.assurance,
        DocumentType.visiteTechnique,
      ]) {
        await service.saveDocument(
          VehicleDocument(
            vehicleId: created.id,
            type: type,
            expiryDate: now.add(const Duration(days: 300)),
          ),
          sousse,
        );
      }
      expect(await service.validationProblems(created.id), isEmpty);
      final validated = await service.reviewVehicle(created.id,
          approve: true, actor: admin);
      expect(validated.validation, ValidationStatus.valide);
    });

    test("après un refus, la correction de l'agence renvoie en validation",
        () async {
      await service.reviewVehicle('veh_dacia_sandero',
          approve: false, reason: 'Photos manquantes', actor: admin);
      var dacia = await service.getVehicle('veh_dacia_sandero');
      expect(dacia!.validation, ValidationStatus.refuse);
      expect(dacia.rejectionReason, 'Photos manquantes');
      await service.updateVehicle(
          dacia.copyWith(mileage: dacia.mileage + 10), sousse);
      dacia = await service.getVehicle('veh_dacia_sandero');
      expect(dacia!.validation, ValidationStatus.enAttente);
      expect(dacia.rejectionReason, isNull);
    });

    test('nombre de véhicules par agence et par catégorie', () async {
      expect(await service.vehicleCountByAgency(),
          {'ag_tunis': 4, 'ag_sousse': 3, 'ag_sfax': 3});
      final byCategory = await service.vehicleCountByCategory();
      expect(byCategory.values.fold(0, (a, b) => a + b), 10);
    });
  });

  group('Agences (admin)', () {
    test('ajout, modification et suppression', () async {
      final created = await service.createAgency(
        name: 'Cap Bon Cars',
        city: 'Nabeul',
        phone: '+216 72 285 000',
        email: 'contact@capbon.tn',
        actor: admin,
      );
      expect((await service.agencies()).map((a) => a.id),
          contains(created.id));
      final updated = await service.updateAgency(
          created.copyWith(city: 'Hammamet'), admin);
      expect(updated.city, 'Hammamet');
      await service.deleteAgency(created.id, admin);
      expect(await service.agency(created.id), isNull);
    });

    test('téléphone invalide : erreur sur le bon champ', () async {
      await expectLater(
        service.createAgency(
            name: 'Test Auto', city: 'Tunis', phone: '123', actor: admin),
        throwsA(isA<FleetValidationException>()
            .having((e) => e.field, 'field', 'phone')),
      );
    });

    test("une agence ne peut pas créer d'agence", () async {
      await expectLater(
        service.createAgency(name: 'Autre', city: 'Tunis', actor: sousse),
        throwsA(isA<FleetPermissionException>()),
      );
    });

    test('une agence modifie sa fiche mais pas son activation', () async {
      final mine = await service.agency('ag_sousse');
      final saved = await service.updateAgency(
        mine!.copyWith(isActive: false, phone: '+216 73 000 000'),
        sousse,
      );
      expect(saved.isActive, isTrue);
      expect(saved.phone, '+216 73 000 000');
    });
  });

  group('Catégories', () {
    test('pas de fourchette qui exclut des véhicules existants', () async {
      final berline = await service.category('cat_berline');
      await expectLater(
        service.updateCategory(
            berline!.copyWith(minPricePerDay: 200), admin),
        throwsA(isA<FleetRuleException>()),
      );
    });

    test('nom de catégorie unique', () async {
      await expectLater(
        service.createCategory(
          name: 'suv',
          minPricePerDay: 100,
          maxPricePerDay: 200,
          actor: admin,
        ),
        throwsA(isA<FleetValidationException>()),
      );
    });

    test('catégorie utilisée : suppression refusée', () async {
      await expectLater(
        service.deleteCategory('cat_berline', admin),
        throwsA(isA<FleetRuleException>()),
      );
    });

    test('ajout, modification et suppression', () async {
      final created = await service.createCategory(
        name: 'Cabriolet',
        minPricePerDay: 150,
        maxPricePerDay: 400,
        actor: admin,
      );
      final updated = await service.updateCategory(
          created.copyWith(maxPricePerDay: 450, isActive: false), admin);
      expect(updated.maxPricePerDay, 450);
      expect(updated.isActive, isFalse);
      await service.deleteCategory(created.id, admin);
      expect(await service.category(created.id), isNull);
    });

    test('catégorie désactivée : plus de nouveaux véhicules', () async {
      final citadine = await service.category('cat_citadine');
      await service.updateCategory(citadine!.copyWith(isActive: false), admin);
      await expectLater(
        service.createVehicle(draft(), admin),
        throwsA(isA<FleetValidationException>()
            .having((e) => e.field, 'field', 'categoryId')),
      );
    });

    test('prix minimum supérieur au maximum : refusé', () async {
      await expectLater(
        service.createCategory(
          name: 'Minibus',
          minPricePerDay: 300,
          maxPricePerDay: 200,
          actor: admin,
        ),
        throwsA(isA<FleetValidationException>()
            .having((e) => e.field, 'field', 'maxPricePerDay')),
      );
    });

    test("seul l'admin gère les catégories", () async {
      await expectLater(
        service.createCategory(
          name: 'Minibus',
          minPricePerDay: 100,
          maxPricePerDay: 200,
          actor: tunis,
        ),
        throwsA(isA<FleetPermissionException>()),
      );
    });
  });

  group('Disponibilités et recherche', () {
    test('période qui chevauche une autre : refusée', () async {
      await expectLater(
        service.addUnavailability(
          UnavailabilityPeriod(
            vehicleId: 'veh_bmw_3',
            start: now.add(const Duration(days: 6)),
            end: now.add(const Duration(days: 9)),
          ),
          tunis,
        ),
        throwsA(isA<FleetRuleException>()),
      );
    });

    test('disponibilité sur des dates', () async {
      final blocked = await service.isAvailable(
        'veh_bmw_3',
        now.add(const Duration(days: 6)),
        now.add(const Duration(days: 8)),
      );
      final free = await service.isAvailable(
        'veh_bmw_3',
        now.add(const Duration(days: 1)),
        now.add(const Duration(days: 3)),
      );
      expect(blocked, isFalse);
      expect(free, isTrue);
    });

    test('recherche texte, prix et tri', () async {
      final clio = await service.search(
          const VehicleFilter(query: 'clio'), client);
      expect(clio.single.id, 'veh_renault_clio');

      final cheap = await service.search(
        const VehicleFilter(maxPrice: 90, sort: VehicleSort.prixCroissant),
        client,
      );
      expect(cheap.first.id, 'veh_kia_picanto');
      expect(cheap.every((v) => v.pricePerDay <= 90), isTrue);
    });

    test('recherche par dates : exclut les véhicules bloqués', () async {
      final results = await service.search(
        VehicleFilter(
          availableFrom: now.add(const Duration(days: 6)),
          availableTo: now.add(const Duration(days: 6)),
        ),
        client,
      );
      expect(results.map((v) => v.id), isNot(contains('veh_bmw_3')));
    });
  });

  test('favoris', () async {
    expect(await service.favoriteIds(), {'veh_bmw_3'});
    expect(await service.toggleFavorite('veh_kia_picanto'), isTrue);
    expect(await service.toggleFavorite('veh_bmw_3'), isFalse);
    expect(await service.favoriteIds(), {'veh_kia_picanto'});
  });

  test("statistiques d'une agence", () async {
    final stats = await service.computeStats(agencyId: 'ag_tunis');
    expect(stats.total, 4);
    expect(stats.occupied, 1); // Audi A4 louée
    expect(stats.count(VehicleStatus.maintenance), 1); // Peugeot 208
  });

  test('statistiques de la flotte', () async {
    final stats = await service.computeStats();
    expect(stats.total, 10);
    expect(stats.pendingValidation, 1);
    expect(stats.documentsExpired, 1);
    expect(stats.documentsExpiringSoon, 1);
    expect(stats.count(VehicleStatus.horsService), 1);
  });
}
