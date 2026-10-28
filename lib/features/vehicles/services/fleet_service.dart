import 'package:flutter/foundation.dart';

import '../data/fleet_database.dart';
import '../data/fleet_repository.dart';
import '../domain/actor.dart';
import '../../users/domain/user.dart';
import '../domain/document_alert.dart';
import '../domain/enums.dart';
import '../domain/fleet_dates.dart';
import '../domain/fleet_exceptions.dart';
import '../domain/fleet_vehicle.dart';
import '../domain/history_entry.dart';
import '../domain/unavailability_period.dart';
import '../domain/validators.dart';
import '../domain/vehicle_category.dart';
import '../domain/vehicle_document.dart';
import '../domain/vehicle_filter.dart';

/// Cœur métier du module Véhicules : droits, règles de gestion et
/// historique. Les écrans l'écoutent (ChangeNotifier) pour se rafraîchir
/// après chaque modification.
///
/// Règles principales :
/// - un client ne voit que les véhicules validés, louables (ni en
///   maintenance, ni hors service, ni archivés), d'agences actives ; une agence ne gère que sa flotte ; l'admin gère tout ;
/// - les changements de statut suivent VehicleStatus.allowedNext ;
/// - un véhicule ajouté par une agence attend la validation de l'admin,
///   qui n'est possible qu'avec une assurance et une visite technique
///   valides et un prix dans la fourchette de la catégorie ;
/// - « Réservé », « Loué » et « Contrôle retour » (= occupé) sont posés
///   uniquement par le module Réservations (via VehicleApi) ;
/// - un véhicule occupé ne peut être ni supprimé ni transféré ;
/// - le prix par jour doit rester dans la fourchette de sa catégorie ;
/// - le kilométrage ne peut que croître ;
/// - une assurance ou une visite technique expirée bloque la location
///   (le véhicule passe automatiquement « Hors service ») ;
/// - chaque modification est enregistrée dans l'historique.
class FleetService extends ChangeNotifier {
  FleetService({FleetRepository? repository, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        _repo = repository ?? FleetRepository(FleetDatabase(clock: clock));

  static FleetService? _instance;

  /// Instance partagée par toute l'application.
  static FleetService get instance => _instance ??= FleetService();

  @visibleForTesting
  static set instance(FleetService service) => _instance = service;

  final FleetRepository _repo;
  final DateTime Function() _clock;
  int _idSequence = 0;
  Future<void>? _ready;

  /// Ouvre la base (création + données de démo au premier lancement)
  /// et applique le contrôle des documents expirés.
  /// En cas d'échec, l'appel suivant réessaie.
  Future<void> ensureReady() => _ready ??= _initialize().then(
        (_) {},
        onError: (Object error, StackTrace stack) {
          _ready = null;
          Error.throwWithStackTrace(error, stack);
        },
      );

  Future<void> _initialize() async {
    await _repo.open();
    await _enforceCompliance();
  }

  /// Ferme la base (utile dans les tests).
  Future<void> closeDatabase() async {
    _ready = null;
    await _repo.close();
  }

  // ================================================================ Lecture

  /// Recherche limitée à ce que le profil a le droit de voir.
  Future<List<FleetVehicle>> search(VehicleFilter filter, Actor actor) async {
    await ensureReady();
    return _repo.searchVehicles(
      filter,
      clientView: actor.isClient,
      scopeAgencyId: actor.isAgency ? actor.agencyId : null,
    );
  }

  Future<FleetVehicle?> getVehicle(String id) async {
    await ensureReady();
    return _repo.getVehicle(id);
  }

  /// Le véhicule si ce profil a le droit de le voir, sinon null
  /// (client : véhicule louable d'une agence active ; agence : sa flotte).
  Future<FleetVehicle?> getVehicleFor(String id, Actor actor) async {
    await ensureReady();
    final vehicle = await _repo.getVehicle(id);
    if (vehicle == null) return null;
    if (actor.isAgency && vehicle.agencyId != actor.agencyId) return null;
    if (actor.isClient) {
      if (!vehicle.isListedForClients) return null;
      final agency = await _repo.getAgency(vehicle.agencyId);
      if (agency == null || !agency.isActif) return null;
    }
    return vehicle;
  }

  Future<List<User>> agencies({bool activeOnly = false}) async {
    await ensureReady();
    return _repo.getAgencies(activeOnly: activeOnly);
  }

  Future<User?> agency(int id) async {
    await ensureReady();
    return _repo.getAgency(id);
  }

  Future<Map<int, User>> agencyMap() async {
    final list = await agencies();
    return {for (final a in list) a.id!: a};
  }

  Future<List<VehicleCategory>> categories({bool activeOnly = false}) async {
    await ensureReady();
    return _repo.getCategories(activeOnly: activeOnly);
  }

  Future<VehicleCategory?> category(String id) async {
    await ensureReady();
    return _repo.getCategory(id);
  }

  Future<Map<String, VehicleCategory>> categoryMap() async {
    final list = await categories();
    return {for (final c in list) c.id: c};
  }

  /// Villes des agences actives, triées.
  Future<List<String>> cities() async {
    await ensureReady();
    return _repo.getCities();
  }

  Future<List<VehicleDocument>> documents(String vehicleId) async {
    await ensureReady();
    return _repo.getDocuments(vehicleId);
  }

  Future<List<UnavailabilityPeriod>> unavailabilities(String vehicleId) async {
    await ensureReady();
    return _repo.getPeriods(vehicleId);
  }

  Future<List<HistoryEntry>> history(String vehicleId) async {
    await ensureReady();
    return _repo.getHistory(vehicleId);
  }

  /// Nombre de véhicules (archivés compris) par agence : id -> nombre.
  Future<Map<int, int>> vehicleCountByAgency() async {
    await ensureReady();
    final counts = <int, int>{};
    for (final v in await _repo.getVehicles()) {
      counts.update(v.agencyId, (n) => n + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  /// Nombre de véhicules (archivés compris) par catégorie : id -> nombre.
  Future<Map<String, int>> vehicleCountByCategory() async {
    await ensureReady();
    final counts = <String, int>{};
    for (final v in await _repo.getVehicles()) {
      counts.update(v.categoryId, (n) => n + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  /// Ce qui empêche l'administrateur de valider ce véhicule (liste vide :
  /// validation possible). Sert aussi de check-list dans l'écran Validation.
  Future<List<String>> validationProblems(String vehicleId) async {
    await ensureReady();
    final vehicle = await _loadVehicle(vehicleId);
    final problems = <String>[];
    final now = _clock();
    final documents = await _repo.getDocuments(vehicleId);
    for (final type in DocumentType.values) {
      if (!type.blocksRentalWhenExpired) continue;
      final matches = documents.where((d) => d.type == type);
      if (matches.isEmpty) {
        problems.add('${type.label} manquante');
      } else if (matches.first.stateAt(now) == DocumentState.expire) {
        problems.add('${type.label} expirée le '
            '${FleetDates.display(matches.first.expiryDate!)}');
      }
    }
    final category = await _repo.getCategory(vehicle.categoryId);
    if (category != null && !category.acceptsPrice(vehicle.pricePerDay)) {
      problems.add('Prix hors fourchette ${category.name} '
          '(${FleetFormat.dt(category.minPricePerDay)} – '
          '${FleetFormat.dt(category.maxPricePerDay)})');
    }
    final agency = await _repo.getAgency(vehicle.agencyId);
    if (agency != null && !agency.isActif) {
      problems.add('Agence ${agency.displayName} désactivée');
    }
    return problems;
  }

  // ============================================================== Véhicules

  Future<FleetVehicle> createVehicle(FleetVehicle draft, Actor actor) async {
    await ensureReady();
    _requireStaff(actor);
    final agencyId = actor.isAgency ? actor.agencyId! : draft.agencyId;
    final agency = await _repo.getAgency(agencyId);
    if (agency == null) {
      throw const FleetValidationException('agencyId', 'Agence introuvable.');
    }
    if (!agency.isActif) {
      throw FleetRuleException(
          "L'agence ${agency.displayName} est désactivée : impossible d'ajouter "
          'un véhicule.');
    }
    final category = await _requireCategory(draft.categoryId);
    if (!category.isActive) {
      throw FleetValidationException('categoryId',
          "La catégorie ${category.name} n'accepte plus de nouveaux véhicules.");
    }
    final plate = FleetValidators.normalizePlate(draft.registrationPlate);
    final candidate = draft.copyWith(
      agencyId: agencyId,
      registrationPlate: plate,
      brand: draft.brand.trim(),
      model: draft.model.trim(),
      color: draft.color.trim(),
      description: draft.description.trim(),
    );
    _validateVehicleFields(candidate);
    _checkPriceInCategory(candidate.pricePerDay, category);
    if (await _repo.plateExists(plate)) {
      throw const FleetValidationException(
          'registrationPlate', 'Ce matricule existe déjà dans la flotte.');
    }

    const allowedInitial = {
      VehicleStatus.disponible,
      VehicleStatus.maintenance,
      VehicleStatus.horsService,
    };
    final now = _clock();
    final vehicle = FleetVehicle(
      id: 'veh_${now.microsecondsSinceEpoch}_${++_idSequence}',
      agencyId: candidate.agencyId,
      categoryId: candidate.categoryId,
      brand: candidate.brand,
      model: candidate.model,
      year: candidate.year,
      registrationPlate: candidate.registrationPlate,
      color: candidate.color,
      fuel: candidate.fuel,
      transmission: candidate.transmission,
      seats: candidate.seats,
      doors: candidate.doors,
      mileage: candidate.mileage,
      pricePerDay: candidate.pricePerDay,
      deposit: candidate.deposit,
      status: allowedInitial.contains(candidate.status)
          ? candidate.status
          : VehicleStatus.disponible,
      validation:
          actor.isAdmin ? ValidationStatus.valide : ValidationStatus.enAttente,
      description: candidate.description,
      photos: candidate.photos,
      createdAt: now,
      updatedAt: now,
    );

    await _repo.transaction((txn) async {
      await _repo.insertVehicle(vehicle, txn: txn);
      await _repo.insertHistory(
        _entry(
          vehicle.id,
          actor,
          HistoryAction.creation,
          comment: 'Ajout de ${vehicle.fullName} (${vehicle.registrationPlate})'
              '${actor.isAdmin ? '' : ' – en attente de validation'}',
        ),
        txn: txn,
      );
    });
    notifyListeners();
    return vehicle;
  }

  /// Modifie les informations d'un véhicule (hors statut, agence et
  /// validation, qui ont leurs propres actions).
  Future<FleetVehicle> updateVehicle(
    FleetVehicle updated,
    Actor actor, {
    String? comment,
  }) async {
    await ensureReady();
    final current = await _loadVehicle(updated.id);
    _requireOwner(actor, current);
    if (updated.agencyId != current.agencyId) {
      throw const FleetRuleException(
          "Pour changer d'agence, utilisez le transfert (administrateur).");
    }
    if (updated.status != current.status) {
      throw const FleetRuleException(
          'Le statut se modifie avec l\'action « Changer le statut ».');
    }

    final plate = FleetValidators.normalizePlate(updated.registrationPlate);
    var next = updated.copyWith(
      registrationPlate: plate,
      brand: updated.brand.trim(),
      model: updated.model.trim(),
      color: updated.color.trim(),
      description: updated.description.trim(),
      validation: current.validation,
    );
    next = current.rejectionReason == null
        ? next.copyWith(clearRejectionReason: true)
        : next.copyWith(rejectionReason: current.rejectionReason);

    _validateVehicleFields(next);
    if (next.mileage < current.mileage) {
      throw FleetValidationException(
          'mileage',
          'Le kilométrage ne peut pas diminuer '
              '(actuel : ${FleetFormat.km(current.mileage)}).');
    }
    final category = await _requireCategory(next.categoryId);
    if (next.categoryId != current.categoryId && !category.isActive) {
      throw FleetValidationException('categoryId',
          "La catégorie ${category.name} n'accepte plus de nouveaux véhicules.");
    }
    _checkPriceInCategory(next.pricePerDay, category);
    if (plate != current.registrationPlate &&
        await _repo.plateExists(plate, excludeId: current.id)) {
      throw const FleetValidationException(
          'registrationPlate', 'Ce matricule existe déjà dans la flotte.');
    }

    final changes = await _diff(current, next);
    if (changes.isEmpty) return current;

    final resubmitted =
        actor.isAgency && current.validation == ValidationStatus.refuse;
    if (resubmitted) {
      next = next.copyWith(
        validation: ValidationStatus.enAttente,
        clearRejectionReason: true,
      );
    }
    final saved = next.copyWith(updatedAt: _clock());

    await _repo.transaction((txn) async {
      await _repo.updateVehicle(saved, txn: txn);
      for (final change in changes) {
        await _repo.insertHistory(
          _entry(
            current.id,
            actor,
            change.action,
            field: change.field,
            oldValue: change.oldValue,
            newValue: change.newValue,
            comment: comment,
          ),
          txn: txn,
        );
      }
      if (resubmitted) {
        await _repo.insertHistory(
          _entry(
            current.id,
            actor,
            HistoryAction.validation,
            field: 'Validation',
            oldValue: ValidationStatus.refuse.label,
            newValue: ValidationStatus.enAttente.label,
            comment: 'Renvoyé pour validation après correction',
          ),
          txn: txn,
        );
      }
    });
    notifyListeners();
    return saved;
  }

  /// Fait avancer le cycle de vie du véhicule.
  Future<FleetVehicle> changeStatus(
    String vehicleId,
    VehicleStatus next,
    Actor actor, {
    String? comment,
  }) async {
    await ensureReady();
    final current = await _loadVehicle(vehicleId);
    _requireOwner(actor, current);
    if (current.status == next) return current;
    if (!actor.isSystem && (next.isOccupied || current.status.isOccupied)) {
      throw const FleetRuleException(
          'Occupé ou libre : ce statut est géré automatiquement par le '
          'module Réservations.');
    }
    if (!current.status.canMoveTo(next)) {
      final options = current.status.allowedNext
          .where((s) => actor.isSystem || !s.isOccupied)
          .map((s) => s.label)
          .join(', ');
      throw FleetRuleException(
          'Passage « ${current.status.label} » → « ${next.label} » impossible. '
          'Depuis « ${current.status.label} » : $options.');
    }
    if (current.status == VehicleStatus.archive && !actor.isAdmin) {
      throw const FleetPermissionException(
          "Seul l'administrateur peut restaurer un véhicule archivé.");
    }
    if (next == VehicleStatus.reserve &&
        current.validation != ValidationStatus.valide) {
      throw const FleetRuleException(
          "Ce véhicule n'est pas encore validé par l'administrateur.");
    }
    if (next == VehicleStatus.disponible || next == VehicleStatus.reserve) {
      final blocking = await _blockingDocuments(vehicleId);
      if (blocking.isNotEmpty) {
        final doc = blocking.first;
        throw FleetRuleException(
            'Impossible : ${doc.type.label} expirée le '
            '${FleetDates.display(doc.expiryDate!)}. '
            "Renouvelez le document d'abord.");
      }
    }

    final updated = current.copyWith(status: next, updatedAt: _clock());
    await _repo.transaction((txn) async {
      await _repo.updateVehicle(updated, txn: txn);
      await _repo.insertHistory(
        _entry(
          vehicleId,
          actor,
          HistoryAction.statut,
          field: 'Statut',
          oldValue: current.status.label,
          newValue: next.label,
          comment: comment,
        ),
        txn: txn,
      );
    });
    notifyListeners();
    return updated;
  }

  /// Met à jour le kilométrage (il ne peut que croître).
  Future<FleetVehicle> updateMileage(
    String vehicleId,
    int mileage,
    Actor actor, {
    String? comment,
  }) async {
    await ensureReady();
    final current = await _loadVehicle(vehicleId);
    _requireOwner(actor, current);
    if (mileage < current.mileage) {
      throw FleetValidationException(
          'mileage',
          'Le kilométrage ne peut pas diminuer '
              '(actuel : ${FleetFormat.km(current.mileage)}).');
    }
    if (mileage == current.mileage) return current;
    final updated = current.copyWith(mileage: mileage, updatedAt: _clock());
    await _repo.transaction((txn) async {
      await _repo.updateVehicle(updated, txn: txn);
      await _repo.insertHistory(
        _entry(
          vehicleId,
          actor,
          HistoryAction.kilometrage,
          field: 'Kilométrage',
          oldValue: FleetFormat.km(current.mileage),
          newValue: FleetFormat.km(mileage),
          comment: comment,
        ),
        txn: txn,
      );
    });
    notifyListeners();
    return updated;
  }

  /// Validation (ou refus motivé) d'un véhicule par l'administrateur.
  Future<FleetVehicle> reviewVehicle(
    String vehicleId, {
    required bool approve,
    String? reason,
    required Actor actor,
  }) async {
    await ensureReady();
    _requireAdmin(actor, 'valider un véhicule');
    final current = await _loadVehicle(vehicleId);
    final motive = (reason ?? '').trim();
    if (!approve && motive.isEmpty) {
      throw const FleetValidationException(
          'reason', 'Indiquez le motif du refus.');
    }
    final nextValidation =
        approve ? ValidationStatus.valide : ValidationStatus.refuse;
    if (current.validation == nextValidation && approve) return current;
    if (approve) {
      final problems = await validationProblems(vehicleId);
      if (problems.isNotEmpty) {
        throw FleetRuleException(
            'Validation impossible : ${problems.join(' · ')}.');
      }
    }

    final updated = approve
        ? current.copyWith(
            validation: nextValidation,
            clearRejectionReason: true,
            updatedAt: _clock(),
          )
        : current.copyWith(
            validation: nextValidation,
            rejectionReason: motive,
            updatedAt: _clock(),
          );
    await _repo.transaction((txn) async {
      await _repo.updateVehicle(updated, txn: txn);
      await _repo.insertHistory(
        _entry(
          vehicleId,
          actor,
          HistoryAction.validation,
          field: 'Validation',
          oldValue: current.validation.label,
          newValue: nextValidation.label,
          comment: approve ? 'Véhicule visible par les clients' : motive,
        ),
        txn: txn,
      );
    });
    notifyListeners();
    return updated;
  }

  /// Transfert d'un véhicule vers une autre agence (administrateur).
  Future<FleetVehicle> transferVehicle(
    String vehicleId,
    int toAgencyId,
    Actor actor, {
    String? comment,
  }) async {
    await ensureReady();
    _requireAdmin(actor, 'transférer un véhicule');
    final current = await _loadVehicle(vehicleId);
    if (current.agencyId == toAgencyId) {
      throw const FleetRuleException(
          'Le véhicule appartient déjà à cette agence.');
    }
    if (current.status.isEngaged) {
      throw const FleetRuleException(
          'Véhicule occupé (réservation ou location en cours) : transfert '
          'impossible pour le moment.');
    }
    if (current.status == VehicleStatus.archive) {
      throw const FleetRuleException(
          'Restaurez le véhicule avant de le transférer.');
    }
    final target = await _repo.getAgency(toAgencyId);
    if (target == null) {
      throw const FleetNotFoundException('Agence de destination introuvable.');
    }
    if (!target.isActif) {
      throw FleetRuleException("L'agence « ${target.displayName} » est désactivée.");
    }
    final booking = await _upcomingReservation(vehicleId);
    if (booking != null) {
      throw FleetRuleException(
          'Réservation prévue du ${FleetDates.display(booking.start)} au '
          '${FleetDates.display(booking.end)} : transfert impossible.');
    }
    final source = await _repo.getAgency(current.agencyId);

    final updated =
        current.copyWith(agencyId: toAgencyId, updatedAt: _clock());
    await _repo.transaction((txn) async {
      await _repo.updateVehicle(updated, txn: txn);
      await _repo.insertHistory(
        _entry(
          vehicleId,
          actor,
          HistoryAction.transfert,
          field: 'Agence',
          oldValue: source?.displayName ?? '${current.agencyId}',
          newValue: target.displayName,
          comment: comment,
        ),
        txn: txn,
      );
    });
    notifyListeners();
    return updated;
  }

  /// Suppression définitive (l'historique est conservé).
  Future<void> deleteVehicle(String vehicleId, Actor actor) async {
    await ensureReady();
    final current = await _loadVehicle(vehicleId);
    _requireOwner(actor, current);
    if (current.status.isEngaged) {
      throw const FleetRuleException(
          'Véhicule occupé (réservation ou location en cours) : il ne peut '
          'pas être supprimé pour le moment.');
    }
    final booking = await _upcomingReservation(vehicleId);
    if (booking != null) {
      throw FleetRuleException(
          'Réservation prévue du ${FleetDates.display(booking.start)} au '
          '${FleetDates.display(booking.end)} : suppression impossible. '
          'Vous pouvez le passer « Hors service ».');
    }
    await _repo.transaction((txn) async {
      await _repo.insertHistory(
        _entry(
          vehicleId,
          actor,
          HistoryAction.suppression,
          comment: 'Suppression de ${current.fullName} '
              '(${current.registrationPlate})',
        ),
        txn: txn,
      );
      await _repo.deleteVehicle(vehicleId, txn: txn);
    });
    notifyListeners();
  }

  // ============================================================== Documents

  Future<VehicleDocument> saveDocument(
      VehicleDocument document, Actor actor) async {
    await ensureReady();
    final vehicle = await _loadVehicle(document.vehicleId);
    _requireOwner(actor, vehicle);
    if (document.type.blocksRentalWhenExpired && document.expiryDate == null) {
      throw FleetValidationException('expiryDate',
          "La date d'expiration est obligatoire pour : ${document.type.label}.");
    }
    final existing = await _repo.getDocuments(document.vehicleId);
    final duplicate =
        existing.where((d) => d.type == document.type && d.id != document.id);
    if (duplicate.isNotEmpty) {
      throw FleetRuleException(
          'Un document « ${document.type.label} » existe déjà pour ce '
          'véhicule : modifiez-le.');
    }
    VehicleDocument? previous;
    for (final d in existing) {
      if (d.id != null && d.id == document.id) previous = d;
    }
    final isNew = previous == null;
    final previousLabel = previous == null ? null : _expiryLabel(previous);

    final saved = await _repo.transaction<VehicleDocument>((txn) async {
      final VehicleDocument result;
      if (document.id == null) {
        final id = await _repo.insertDocument(document, txn: txn);
        result = document.copyWith(id: id);
      } else {
        await _repo.updateDocument(document, txn: txn);
        result = document;
      }
      await _repo.insertHistory(
        _entry(
          vehicle.id,
          actor,
          HistoryAction.document,
          field: document.type.label,
          oldValue: previousLabel,
          newValue: _expiryLabel(document),
          comment: isNew ? 'Document ajouté' : 'Document mis à jour',
        ),
        txn: txn,
      );
      return result;
    });
    await _enforceCompliance(vehicleIds: {vehicle.id});
    notifyListeners();
    return saved;
  }

  Future<void> deleteDocument(int documentId, Actor actor) async {
    await ensureReady();
    final document = await _repo.getDocument(documentId);
    if (document == null) {
      throw const FleetNotFoundException('Document introuvable.');
    }
    final vehicle = await _loadVehicle(document.vehicleId);
    _requireOwner(actor, vehicle);
    await _repo.transaction((txn) async {
      await _repo.deleteDocument(documentId, txn: txn);
      await _repo.insertHistory(
        _entry(
          vehicle.id,
          actor,
          HistoryAction.document,
          field: document.type.label,
          oldValue: _expiryLabel(document),
          comment: 'Document supprimé',
        ),
        txn: txn,
      );
    });
    notifyListeners();
  }

  /// Notifications « papiers » : documents expirés ou qui expirent dans
  /// les [withinDays] prochains jours, du plus urgent au moins urgent.
  /// Une agence ne reçoit que ceux de sa flotte ; l'admin, toute la flotte
  /// (ou une agence avec [agencyId]). Les véhicules archivés sont ignorés.
  Future<List<DocumentAlert>> documentAlerts(
    Actor actor, {
    int? agencyId,
    int withinDays = VehicleDocument.warningDays,
  }) async {
    await ensureReady();
    _requireStaff(actor);
    final scope = actor.isAgency ? actor.agencyId : agencyId;
    final vehicles = {
      for (final v
          in await _repo.getVehicles(agencyId: scope, includeArchived: false))
        v.id: v,
    };
    final now = _clock();
    final alerts = <DocumentAlert>[];
    for (final document in await _repo.getAllDocuments()) {
      final vehicle = vehicles[document.vehicleId];
      if (vehicle == null) continue;
      final alert =
          DocumentAlert.of(vehicle, document, now, withinDays: withinDays);
      if (alert != null) alerts.add(alert);
    }
    alerts.sort((a, b) {
      final byDays = a.daysLeft.compareTo(b.daysLeft);
      return byDays != 0
          ? byDays
          : a.vehicle.fullName.compareTo(b.vehicle.fullName);
    });
    return alerts;
  }

  /// Passe « Hors service » les véhicules disponibles dont l'assurance ou
  /// la visite technique est expirée. Renvoie le nombre de véhicules mis
  /// hors service.
  Future<int> enforceDocumentCompliance() async {
    await ensureReady();
    final count = await _enforceCompliance();
    if (count > 0) notifyListeners();
    return count;
  }

  // ======================================================= Indisponibilités

  Future<UnavailabilityPeriod> addUnavailability(
    UnavailabilityPeriod period,
    Actor actor,
  ) async {
    await ensureReady();
    final vehicle = await _loadVehicle(period.vehicleId);
    _requireOwner(actor, vehicle);
    final start = FleetDates.dayOnly(period.start);
    final end = FleetDates.dayOnly(period.end);
    if (end.isBefore(start)) {
      throw const FleetValidationException(
          'end', 'La date de fin doit être après la date de début.');
    }
    if (end.isBefore(FleetDates.dayOnly(_clock()))) {
      throw const FleetValidationException(
          'end', 'Cette période est déjà passée.');
    }
    final overlaps = await _repo.overlappingPeriods(vehicle.id, start, end);
    if (overlaps.isNotEmpty) {
      final other = overlaps.first;
      throw FleetRuleException(
          'Chevauche la période du ${FleetDates.display(other.start)} au '
          '${FleetDates.display(other.end)} (${other.reason}).');
    }
    final reason = period.reason.trim().isEmpty ? 'Autre' : period.reason.trim();
    final clean = UnavailabilityPeriod(
      vehicleId: vehicle.id,
      start: start,
      end: end,
      reason: reason,
    );
    final id = await _repo.transaction<int>((txn) async {
      final newId = await _repo.insertPeriod(clean, txn: txn);
      await _repo.insertHistory(
        _entry(
          vehicle.id,
          actor,
          HistoryAction.indisponibilite,
          field: 'Indisponibilité',
          newValue: 'du ${FleetDates.display(start)} au '
              '${FleetDates.display(end)}',
          comment: reason,
        ),
        txn: txn,
      );
      return newId;
    });
    notifyListeners();
    return UnavailabilityPeriod(
      id: id,
      vehicleId: vehicle.id,
      start: start,
      end: end,
      reason: reason,
    );
  }

  Future<void> removeUnavailability(int periodId, Actor actor) async {
    await ensureReady();
    final period = await _repo.getPeriod(periodId);
    if (period == null) {
      throw const FleetNotFoundException('Période introuvable.');
    }
    final vehicle = await _loadVehicle(period.vehicleId);
    _requireOwner(actor, vehicle);
    await _repo.transaction((txn) async {
      await _repo.deletePeriod(periodId, txn: txn);
      await _repo.insertHistory(
        _entry(
          vehicle.id,
          actor,
          HistoryAction.indisponibilite,
          field: 'Indisponibilité',
          oldValue: 'du ${FleetDates.display(period.start)} au '
              '${FleetDates.display(period.end)}',
          comment: 'Période supprimée (${period.reason})',
        ),
        txn: txn,
      );
    });
    notifyListeners();
  }

  Future<bool> isAvailable(
    String vehicleId,
    DateTime start,
    DateTime end,
  ) async =>
      await availabilityProblem(vehicleId, start, end) == null;

  /// Null si le véhicule peut être loué sur [start, end], sinon la raison.
  Future<String?> availabilityProblem(
    String vehicleId,
    DateTime start,
    DateTime end,
  ) async {
    await ensureReady();
    final vehicle = await _repo.getVehicle(vehicleId);
    if (vehicle == null) return 'Véhicule introuvable.';
    if (vehicle.validation != ValidationStatus.valide) {
      return "Véhicule pas encore validé par l'administrateur.";
    }
    const blocked = {
      VehicleStatus.maintenance,
      VehicleStatus.horsService,
      VehicleStatus.archive,
    };
    if (blocked.contains(vehicle.status)) {
      return 'Véhicule en statut « ${vehicle.status.label} ».';
    }
    final agency = await _repo.getAgency(vehicle.agencyId);
    if (agency == null || !agency.isActif) return 'Agence indisponible.';
    final from = FleetDates.dayOnly(start);
    final to = FleetDates.dayOnly(end);
    if (to.isBefore(from)) return 'Dates invalides.';
    final overlaps = await _repo.overlappingPeriods(vehicleId, from, to);
    if (overlaps.isNotEmpty) {
      final other = overlaps.first;
      final period = 'du ${FleetDates.display(other.start)} au '
          '${FleetDates.display(other.end)}';
      // Pas de référence de réservation : le client voit seulement « occupé ».
      return other.reason.startsWith('Réservation')
          ? 'Déjà occupé $period.'
          : 'Indisponible $period (${other.reason}).';
    }
    for (final doc in await _repo.getDocuments(vehicleId)) {
      final expiry = doc.expiryDate;
      if (doc.type.blocksRentalWhenExpired &&
          expiry != null &&
          FleetDates.dayOnly(expiry).isBefore(to)) {
        return '${doc.type.label} valable jusqu\'au '
            '${FleetDates.display(expiry)} seulement.';
      }
    }
    return null;
  }

  // ================================================================ Favoris

  Future<Set<String>> favoriteIds() async {
    await ensureReady();
    return _repo.getFavoriteIds();
  }

  /// Ajoute ou retire le favori ; renvoie le nouvel état.
  Future<bool> toggleFavorite(String vehicleId) async {
    await ensureReady();
    final ids = await _repo.getFavoriteIds();
    final nowFavorite = !ids.contains(vehicleId);
    if (nowFavorite) {
      await _repo.addFavorite(vehicleId, _clock());
    } else {
      await _repo.removeFavorite(vehicleId);
    }
    notifyListeners();
    return nowFavorite;
  }

  Future<List<FleetVehicle>> favorites() async {
    final ids = await favoriteIds();
    if (ids.isEmpty) return const [];
    final visible =
        await search(const VehicleFilter(), const Actor.client());
    return visible.where((v) => ids.contains(v.id)).toList();
  }

  // ============================================================= Catégories

  Future<VehicleCategory> createCategory({
    required String name,
    String description = '',
    required double minPricePerDay,
    required double maxPricePerDay,
    required Actor actor,
  }) async {
    await ensureReady();
    _requireAdmin(actor, 'créer une catégorie');
    _validateCategory(name, minPricePerDay, maxPricePerDay);
    if (await _repo.categoryNameExists(name)) {
      throw const FleetValidationException(
          'name', 'Cette catégorie existe déjà.');
    }
    final category = VehicleCategory(
      id: 'cat_${_clock().microsecondsSinceEpoch}',
      name: name.trim(),
      description: description.trim(),
      minPricePerDay: minPricePerDay,
      maxPricePerDay: maxPricePerDay,
    );
    await _repo.insertCategory(category);
    notifyListeners();
    return category;
  }

  Future<VehicleCategory> updateCategory(
      VehicleCategory category, Actor actor) async {
    await ensureReady();
    _requireAdmin(actor, 'modifier une catégorie');
    _validateCategory(
        category.name, category.minPricePerDay, category.maxPricePerDay);
    if (await _repo.categoryNameExists(category.name,
        excludeId: category.id)) {
      throw const FleetValidationException(
          'name', 'Cette catégorie existe déjà.');
    }
    final outside = await _repo.countVehiclesOutsideRange(
        category.id, category.minPricePerDay, category.maxPricePerDay);
    if (outside > 0) {
      throw FleetRuleException(
          '$outside véhicule(s) de cette catégorie ont un prix hors de la '
          "nouvelle fourchette. Ajustez leurs prix d'abord.");
    }
    final saved = category.copyWith(
      name: category.name.trim(),
      description: category.description.trim(),
    );
    await _repo.updateCategory(saved);
    notifyListeners();
    return saved;
  }

  Future<void> deleteCategory(String categoryId, Actor actor) async {
    await ensureReady();
    _requireAdmin(actor, 'supprimer une catégorie');
    final used = await _repo.countVehiclesOfCategory(categoryId);
    if (used > 0) {
      throw FleetRuleException(
          'Catégorie utilisée par $used véhicule(s) : désactivez-la plutôt.');
    }
    await _repo.deleteCategory(categoryId);
    notifyListeners();
  }

  // ============================================================ Statistiques

  /// Chiffres de la flotte entière, ou d'une seule agence.
  Future<FleetStats> computeStats({int? agencyId}) async {
    await ensureReady();
    final vehicles =
        await _repo.getVehicles(agencyId: agencyId, includeArchived: false);
    final categoryNames = {
      for (final c in await _repo.getCategories()) c.id: c.name,
    };
    final agencyNames = {
      for (final a in await _repo.getAgencies()) a.id!: a.displayName,
    };
    final byStatus = <VehicleStatus, int>{};
    final byCategory = <String, int>{};
    final byAgency = <String, int>{};
    var pending = 0;
    var priceSum = 0.0;
    for (final v in vehicles) {
      byStatus.update(v.status, (n) => n + 1, ifAbsent: () => 1);
      byCategory.update(categoryNames[v.categoryId] ?? '—', (n) => n + 1,
          ifAbsent: () => 1);
      byAgency.update(agencyNames[v.agencyId] ?? '—', (n) => n + 1,
          ifAbsent: () => 1);
      if (v.validation == ValidationStatus.enAttente) pending++;
      priceSum += v.pricePerDay;
    }
    final ids = vehicles.map((v) => v.id).toSet();
    final now = _clock();
    var soon = 0;
    var expired = 0;
    for (final d in await _repo.getAllDocuments()) {
      if (!ids.contains(d.vehicleId)) continue;
      final state = d.stateAt(now);
      if (state == DocumentState.expireBientot) soon++;
      if (state == DocumentState.expire) expired++;
    }
    return FleetStats(
      total: vehicles.length,
      byStatus: byStatus,
      byCategory: byCategory,
      byAgency: byAgency,
      pendingValidation: pending,
      averagePricePerDay: vehicles.isEmpty ? 0 : priceSum / vehicles.length,
      documentsExpiringSoon: soon,
      documentsExpired: expired,
    );
  }

  // ================================================================ Interne

  void _requireStaff(Actor actor) {
    if (actor.isClient) {
      throw const FleetPermissionException(
          "Action réservée aux agences et à l'administrateur.");
    }
  }

  void _requireAdmin(Actor actor, String action) {
    if (!actor.isAdmin) {
      throw FleetPermissionException("Seul l'administrateur peut $action.");
    }
  }

  void _requireOwner(Actor actor, FleetVehicle vehicle) {
    _requireStaff(actor);
    if (actor.isAgency && actor.agencyId != vehicle.agencyId) {
      throw const FleetPermissionException(
          'Ce véhicule appartient à une autre agence.');
    }
  }

  Future<FleetVehicle> _loadVehicle(String id) async {
    final vehicle = await _repo.getVehicle(id);
    if (vehicle == null) {
      throw const FleetNotFoundException('Véhicule introuvable.');
    }
    return vehicle;
  }

  Future<VehicleCategory> _requireCategory(String id) async {
    final category = await _repo.getCategory(id);
    if (category == null) {
      throw const FleetValidationException(
          'categoryId', 'Choisissez une catégorie.');
    }
    return category;
  }

  void _validateVehicleFields(FleetVehicle v) {
    void check(String field, String? error) {
      if (error != null) throw FleetValidationException(field, error);
    }

    check('brand', FleetValidators.name(v.brand, 'Marque'));
    check('model', FleetValidators.name(v.model, 'Modèle'));
    check('registrationPlate',
        FleetValidators.registrationPlate(v.registrationPlate));
    check('year', FleetValidators.year('${v.year}'));
    check('pricePerDay', FleetValidators.price('${v.pricePerDay}'));
    check('deposit', FleetValidators.deposit('${v.deposit}'));
    check('mileage', FleetValidators.mileage('${v.mileage}'));
    check('seats', FleetValidators.seats('${v.seats}'));
    check('doors', FleetValidators.doors('${v.doors}'));
  }

  void _checkPriceInCategory(double price, VehicleCategory category) {
    if (!category.acceptsPrice(price)) {
      throw FleetValidationException(
          'pricePerDay',
          'Catégorie ${category.name} : prix entre '
              '${FleetFormat.dt(category.minPricePerDay)} et '
              '${FleetFormat.dt(category.maxPricePerDay)} par jour.');
    }
  }

  void _validateCategory(String name, double min, double max) {
    final nameError = FleetValidators.name(name, 'Nom de la catégorie');
    if (nameError != null) throw FleetValidationException('name', nameError);
    if (min <= 0) {
      throw const FleetValidationException(
          'minPricePerDay', 'Le prix minimum doit être positif.');
    }
    if (max <= min) {
      throw const FleetValidationException('maxPricePerDay',
          'Le prix maximum doit être supérieur au prix minimum.');
    }
    if (max > 5000) {
      throw const FleetValidationException(
          'maxPricePerDay', 'Prix maximum trop élevé (5000 DT max).');
    }
  }

  Future<List<VehicleDocument>> _blockingDocuments(String vehicleId) async {
    final now = _clock();
    final docs = await _repo.getDocuments(vehicleId);
    return docs.where((d) => d.blocksRentalAt(now)).toList();
  }

  /// Prochaine période « Réservation » non terminée, s'il y en a une.
  Future<UnavailabilityPeriod?> _upcomingReservation(String vehicleId) async {
    final today = FleetDates.dayOnly(_clock());
    for (final p in await _repo.getPeriods(vehicleId)) {
      if (p.reason.startsWith('Réservation') && !p.end.isBefore(today)) {
        return p;
      }
    }
    return null;
  }

  Future<int> _enforceCompliance({Set<String>? vehicleIds}) async {
    final now = _clock();
    final blocking = <String, VehicleDocument>{};
    for (final d in await _repo.getAllDocuments()) {
      if (vehicleIds != null && !vehicleIds.contains(d.vehicleId)) continue;
      if (d.blocksRentalAt(now)) blocking.putIfAbsent(d.vehicleId, () => d);
    }
    var changed = 0;
    for (final item in blocking.entries) {
      final vehicle = await _repo.getVehicle(item.key);
      if (vehicle == null || vehicle.status != VehicleStatus.disponible) {
        continue;
      }
      final doc = item.value;
      final updated =
          vehicle.copyWith(status: VehicleStatus.horsService, updatedAt: now);
      await _repo.transaction((txn) async {
        await _repo.updateVehicle(updated, txn: txn);
        await _repo.insertHistory(
          HistoryEntry(
            vehicleId: vehicle.id,
            timestamp: now,
            actor: 'Système',
            action: HistoryAction.statut,
            field: 'Statut',
            oldValue: vehicle.status.label,
            newValue: VehicleStatus.horsService.label,
            comment: '${doc.type.label} expirée le '
                '${FleetDates.display(doc.expiryDate!)}',
          ),
          txn: txn,
        );
      });
      changed++;
    }
    return changed;
  }

  String _expiryLabel(VehicleDocument document) {
    final expiry = document.expiryDate;
    return expiry == null
        ? 'Sans expiration'
        : "Expire le ${FleetDates.display(expiry)}";
  }

  HistoryEntry _entry(
    String vehicleId,
    Actor actor,
    HistoryAction action, {
    String? field,
    String? oldValue,
    String? newValue,
    String? comment,
  }) {
    return HistoryEntry(
      vehicleId: vehicleId,
      timestamp: _clock(),
      actor: actor.label,
      action: action,
      field: field,
      oldValue: oldValue,
      newValue: newValue,
      comment: comment,
    );
  }

  Future<List<_Change>> _diff(FleetVehicle a, FleetVehicle b) async {
    final changes = <_Change>[];
    void add(HistoryAction action, String field, String before, String after) {
      if (before != after) changes.add(_Change(action, field, before, after));
    }

    add(HistoryAction.modification, 'Marque', a.brand, b.brand);
    add(HistoryAction.modification, 'Modèle', a.model, b.model);
    add(HistoryAction.modification, 'Année', '${a.year}', '${b.year}');
    add(HistoryAction.modification, 'Matricule', a.registrationPlate,
        b.registrationPlate);
    add(HistoryAction.modification, 'Couleur', a.color, b.color);
    add(HistoryAction.modification, 'Carburant', a.fuel.label, b.fuel.label);
    add(HistoryAction.modification, 'Boîte de vitesses', a.transmission.label,
        b.transmission.label);
    add(HistoryAction.modification, 'Places', '${a.seats}', '${b.seats}');
    add(HistoryAction.modification, 'Portes', '${a.doors}', '${b.doors}');
    add(HistoryAction.kilometrage, 'Kilométrage', FleetFormat.km(a.mileage),
        FleetFormat.km(b.mileage));
    add(HistoryAction.prix, 'Prix par jour', FleetFormat.dt(a.pricePerDay),
        FleetFormat.dt(b.pricePerDay));
    add(HistoryAction.prix, 'Caution', FleetFormat.dt(a.deposit),
        FleetFormat.dt(b.deposit));
    if (a.categoryId != b.categoryId) {
      final before = await _repo.getCategory(a.categoryId);
      final after = await _repo.getCategory(b.categoryId);
      add(HistoryAction.modification, 'Catégorie', before?.name ?? '—',
          after?.name ?? '—');
    }
    if (a.description != b.description) {
      changes.add(const _Change(
          HistoryAction.modification, 'Description', null, 'Mise à jour'));
    }
    if (!listEquals(a.photos, b.photos)) {
      changes.add(_Change(
        HistoryAction.modification,
        'Photos',
        '${a.photos.length} photo(s)',
        '${b.photos.length} photo(s)',
      ));
    }
    return changes;
  }
}

class _Change {
  const _Change(this.action, this.field, this.oldValue, this.newValue);

  final HistoryAction action;
  final String field;
  final String? oldValue;
  final String? newValue;
}
