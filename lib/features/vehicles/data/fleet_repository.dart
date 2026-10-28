import 'package:sqflite/sqflite.dart';

import '../../users/domain/user.dart';
import '../domain/enums.dart';
import '../domain/fleet_dates.dart';
import '../domain/fleet_vehicle.dart';
import '../domain/history_entry.dart';
import '../domain/unavailability_period.dart';
import '../domain/vehicle_category.dart';
import '../domain/vehicle_document.dart';
import '../domain/vehicle_filter.dart';
import 'fleet_database.dart';

/// Accès SQL brut aux tables du module. Aucune règle métier ici :
/// les règles et les droits sont dans FleetService.
///
/// Chaque méthode accepte un `txn` facultatif pour être appelée
/// à l'intérieur d'une transaction.
class FleetRepository {
  FleetRepository(this._database);

  final FleetDatabase _database;

  Future<Database> get _db => _database.database;

  Future<DatabaseExecutor> _exec(DatabaseExecutor? txn) async =>
      txn ?? await _db;

  Future<void> open() async {
    await _db;
  }

  Future<void> close() => _database.close();

  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await _db;
    return db.transaction(action);
  }

  // ---------------------------------------------------------------- Agences (Users rôle AGENCE)

  Future<List<User>> getAgencies({
    bool activeOnly = false,
    DatabaseExecutor? txn,
  }) async {
    final db = await _exec(txn);
    final where = StringBuffer("role = 'AGENCE'");
    if (activeOnly) where.write(" AND statut = 'ACTIF'");
    final rows = await db.query(
      'users',
      where: where.toString(),
      orderBy: 'nom_agence COLLATE NOCASE, nom COLLATE NOCASE',
    );
    return rows.map(User.fromMap).toList();
  }

  Future<User?> getAgency(int id, {DatabaseExecutor? txn}) async {
    final db = await _exec(txn);
    final rows = await db.query('users',
        where: "id = ? AND role = 'AGENCE'", whereArgs: [id]);
    return rows.isEmpty ? null : User.fromMap(rows.first);
  }

  Future<int> countVehiclesOfAgency(int id, {DatabaseExecutor? txn}) =>
      _count('vehicles', 'agency_id = ?', [id], txn);

  Future<List<String>> getCities({DatabaseExecutor? txn}) async {
    final db = await _exec(txn);
    final rows = await db.query(
      'users',
      columns: ['adresse_agence'],
      where:
          "role = 'AGENCE' AND statut = 'ACTIF' AND adresse_agence IS NOT NULL AND adresse_agence != ''",
      distinct: true,
    );
    final cities = <String>{};
    for (final row in rows) {
      final addr = (row['adresse_agence'] as String?)?.trim();
      if (addr != null && addr.isNotEmpty) {
        final parts = addr.split(',');
        cities.add(parts.last.trim());
      }
    }
    final list = cities.toList()..sort();
    return list;
  }

  // ------------------------------------------------------------- Catégories

  Future<List<VehicleCategory>> getCategories({
    bool activeOnly = false,
    DatabaseExecutor? txn,
  }) async {
    final db = await _exec(txn);
    final rows = await db.query(
      'categories',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'min_price',
    );
    return rows.map(VehicleCategory.fromMap).toList();
  }

  Future<VehicleCategory?> getCategory(String id,
      {DatabaseExecutor? txn}) async {
    final db = await _exec(txn);
    final rows =
        await db.query('categories', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : VehicleCategory.fromMap(rows.first);
  }

  Future<bool> categoryNameExists(String name,
      {String? excludeId, DatabaseExecutor? txn}) async {
    final count = await _count(
      'categories',
      excludeId == null
          ? 'name = ? COLLATE NOCASE'
          : 'name = ? COLLATE NOCASE AND id != ?',
      excludeId == null ? [name.trim()] : [name.trim(), excludeId],
      txn,
    );
    return count > 0;
  }

  Future<void> insertCategory(VehicleCategory category,
      {DatabaseExecutor? txn}) async {
    final db = await _exec(txn);
    await db.insert('categories', category.toMap());
  }

  Future<void> updateCategory(VehicleCategory category,
      {DatabaseExecutor? txn}) async {
    final db = await _exec(txn);
    await db.update('categories', category.toMap(),
        where: 'id = ?', whereArgs: [category.id]);
  }

  Future<void> deleteCategory(String id, {DatabaseExecutor? txn}) async {
    final db = await _exec(txn);
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> countVehiclesOfCategory(String id, {DatabaseExecutor? txn}) =>
      _count('vehicles', 'category_id = ?', [id], txn);

  /// Véhicules de la catégorie dont le prix sort de [min, max].
  Future<int> countVehiclesOutsideRange(String categoryId, double min,
          double max, {DatabaseExecutor? txn}) =>
      _count(
        'vehicles',
        "category_id = ? AND status != 'archive' "
            'AND (price_per_day < ? OR price_per_day > ?)',
        [categoryId, min, max],
        txn,
      );

  // --------------------------------------------------------------- Véhicules

  /// Recherche dans la flotte.
  ///
  /// [clientView] : seulement les véhicules validés, ni en maintenance, ni
  /// hors service, ni archivés, d'une agence active. [scopeAgencyId] : seulement la flotte de cette agence.
  Future<List<FleetVehicle>> searchVehicles(
    VehicleFilter filter, {
    bool clientView = false,
    int? scopeAgencyId,
    DatabaseExecutor? txn,
  }) async {
    final db = await _exec(txn);
    final where = <String>[];
    final args = <Object?>[];

    if (clientView) {
      where.add("v.validation = 'valide' "
          "AND v.status NOT IN ('maintenance', 'horsService', 'archive') "
          "AND a.statut = 'ACTIF'");
    }
    if (scopeAgencyId != null) {
      where.add('v.agency_id = ?');
      args.add(scopeAgencyId);
    }
    final query = filter.query.trim().toLowerCase();
    if (query.isNotEmpty) {
      final like = '%$query%';
      where.add('(LOWER(v.brand) LIKE ? OR LOWER(v.model) LIKE ? '
          "OR LOWER(v.brand || ' ' || v.model) LIKE ? "
          'OR LOWER(v.registration_plate) LIKE ?)');
      args.addAll([like, like, like, like]);
    }
    if (filter.statuses.isNotEmpty) {
      final marks = List.filled(filter.statuses.length, '?').join(', ');
      where.add('v.status IN ($marks)');
      args.addAll(filter.statuses.map((s) => s.name));
    }
    if (filter.categoryId != null) {
      where.add('v.category_id = ?');
      args.add(filter.categoryId);
    }
    if (filter.agencyId != null) {
      where.add('v.agency_id = ?');
      args.add(filter.agencyId);
    }
    if (filter.city != null) {
      where.add('a.adresse_agence LIKE ?');
      args.add('%${filter.city}%');
    }
    if (filter.fuel != null) {
      where.add('v.fuel = ?');
      args.add(filter.fuel!.name);
    }
    if (filter.transmission != null) {
      where.add('v.transmission = ?');
      args.add(filter.transmission!.name);
    }
    if (filter.minPrice != null) {
      where.add('v.price_per_day >= ?');
      args.add(filter.minPrice);
    }
    if (filter.maxPrice != null) {
      where.add('v.price_per_day <= ?');
      args.add(filter.maxPrice);
    }
    if (filter.minSeats != null) {
      where.add('v.seats >= ?');
      args.add(filter.minSeats);
    }
    if (filter.validation != null) {
      where.add('v.validation = ?');
      args.add(filter.validation!.name);
    }
    if (filter.hasDateRange) {
      where.add("v.status NOT IN ('maintenance', 'horsService', 'archive') "
          'AND NOT EXISTS (SELECT 1 FROM unavailabilities u '
          'WHERE u.vehicle_id = v.id AND u.start_date <= ? '
          'AND u.end_date >= ?)');
      args.addAll([
        FleetDates.toDbDay(filter.availableTo!),
        FleetDates.toDbDay(filter.availableFrom!),
      ]);
    }

    final orderBy = switch (filter.sort) {
      VehicleSort.plusRecents => 'v.created_at DESC',
      VehicleSort.prixCroissant => 'v.price_per_day ASC, v.brand',
      VehicleSort.prixDecroissant => 'v.price_per_day DESC, v.brand',
      VehicleSort.kilometrage => 'v.mileage ASC',
      VehicleSort.marqueAZ =>
        'v.brand COLLATE NOCASE ASC, v.model COLLATE NOCASE ASC',
    };

    final sql = StringBuffer(
        'SELECT v.* FROM vehicles v JOIN users a ON a.id = v.agency_id');
    if (where.isNotEmpty) sql.write(' WHERE ${where.join(' AND ')}');
    sql.write(' ORDER BY $orderBy');

    final rows = await db.rawQuery(sql.toString(), args);
    return rows.map(FleetVehicle.fromMap).toList();
  }

  Future<FleetVehicle?> getVehicle(String id, {DatabaseExecutor? txn}) async {
    final db = await _exec(txn);
    final rows = await db.query('vehicles', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : FleetVehicle.fromMap(rows.first);
  }

  Future<List<FleetVehicle>> getVehicles({
    int? agencyId,
    bool includeArchived = true,
    DatabaseExecutor? txn,
  }) async {
    final db = await _exec(txn);
    final where = <String>[];
    final args = <Object?>[];
    if (agencyId != null) {
      where.add('agency_id = ?');
      args.add(agencyId);
    }
    if (!includeArchived) where.add("status != 'archive'");
    final rows = await db.query(
      'vehicles',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
    );
    return rows.map(FleetVehicle.fromMap).toList();
  }

  Future<bool> plateExists(String plate,
      {String? excludeId, DatabaseExecutor? txn}) async {
    final count = await _count(
      'vehicles',
      excludeId == null
          ? 'registration_plate = ?'
          : 'registration_plate = ? AND id != ?',
      excludeId == null ? [plate] : [plate, excludeId],
      txn,
    );
    return count > 0;
  }

  Future<void> insertVehicle(FleetVehicle vehicle,
      {DatabaseExecutor? txn}) async {
    final db = await _exec(txn);
    await db.insert('vehicles', vehicle.toMap());
  }

  Future<void> updateVehicle(FleetVehicle vehicle,
      {DatabaseExecutor? txn}) async {
    final db = await _exec(txn);
    await db.update('vehicles', vehicle.toMap(),
        where: 'id = ?', whereArgs: [vehicle.id]);
  }

  Future<void> deleteVehicle(String id, {DatabaseExecutor? txn}) async {
    final db = await _exec(txn);
    await db.delete('vehicles', where: 'id = ?', whereArgs: [id]);
  }

  // -------------------------------------------------------------- Documents

  Future<List<VehicleDocument>> getDocuments(String vehicleId,
      {DatabaseExecutor? txn}) async {
    final db = await _exec(txn);
    final rows = await db.query(
      'vehicle_documents',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'type',
    );
    return rows.map(VehicleDocument.fromMap).toList();
  }

  Future<List<VehicleDocument>> getAllDocuments({DatabaseExecutor? txn}) async {
    final db = await _exec(txn);
    final rows = await db.query('vehicle_documents');
    return rows.map(VehicleDocument.fromMap).toList();
  }

  Future<VehicleDocument?> getDocument(int id, {DatabaseExecutor? txn}) async {
    final db = await _exec(txn);
    final rows = await db
        .query('vehicle_documents', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : VehicleDocument.fromMap(rows.first);
  }

  Future<VehicleDocument?> getDocumentByType(
      String vehicleId, DocumentType type,
      {DatabaseExecutor? txn}) async {
    final db = await _exec(txn);
    final rows = await db.query(
      'vehicle_documents',
      where: 'vehicle_id = ? AND type = ?',
      whereArgs: [vehicleId, type.name],
    );
    return rows.isEmpty ? null : VehicleDocument.fromMap(rows.first);
  }

  Future<int> insertDocument(VehicleDocument document,
      {DatabaseExecutor? txn}) async {
    final db = await _exec(txn);
    return db.insert('vehicle_documents', document.toMap());
  }

  Future<void> updateDocument(VehicleDocument document,
      {DatabaseExecutor? txn}) async {
    final db = await _exec(txn);
    await db.update('vehicle_documents', document.toMap(),
        where: 'id = ?', whereArgs: [document.id]);
  }

  Future<void> deleteDocument(int id, {DatabaseExecutor? txn}) async {
    final db = await _exec(txn);
    await db.delete('vehicle_documents', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------- Indisponibilités

  Future<List<UnavailabilityPeriod>> getUnavailabilities(String vehicleId,
      {DatabaseExecutor? txn}) async {
    final db = await _exec(txn);
    final rows = await db.query(
      'unavailabilities',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'start_date',
    );
    return rows.map(UnavailabilityPeriod.fromMap).toList();
  }

  Future<List<UnavailabilityPeriod>> getPeriods(String vehicleId,
          {DatabaseExecutor? txn}) =>
      getUnavailabilities(vehicleId, txn: txn);

  Future<UnavailabilityPeriod?> getUnavailability(int id,
      {DatabaseExecutor? txn}) async {
    final db = await _exec(txn);
    final rows =
        await db.query('unavailabilities', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : UnavailabilityPeriod.fromMap(rows.first);
  }

  Future<UnavailabilityPeriod?> getPeriod(int id, {DatabaseExecutor? txn}) =>
      getUnavailability(id, txn: txn);

  Future<List<UnavailabilityPeriod>> overlappingPeriods(
    String vehicleId,
    DateTime start,
    DateTime end, {
    int? excludeId,
    DatabaseExecutor? txn,
  }) async {
    final db = await _exec(txn);
    final rows = await db.query(
      'unavailabilities',
      where: 'vehicle_id = ? AND start_date <= ? AND end_date >= ?'
          '${excludeId == null ? '' : ' AND id != ?'}',
      whereArgs: [
        vehicleId,
        FleetDates.toDbDay(end),
        FleetDates.toDbDay(start),
        if (excludeId != null) excludeId,
      ],
      orderBy: 'start_date',
    );
    return rows.map(UnavailabilityPeriod.fromMap).toList();
  }

  Future<int> insertUnavailability(UnavailabilityPeriod period,
      {DatabaseExecutor? txn}) async {
    final db = await _exec(txn);
    return db.insert('unavailabilities', period.toMap());
  }

  Future<int> insertPeriod(UnavailabilityPeriod period,
          {DatabaseExecutor? txn}) =>
      insertUnavailability(period, txn: txn);

  Future<void> deleteUnavailability(int id, {DatabaseExecutor? txn}) async {
    final db = await _exec(txn);
    await db.delete('unavailabilities', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deletePeriod(int id, {DatabaseExecutor? txn}) =>
      deleteUnavailability(id, txn: txn);

  // ------------------------------------------------------------- Historique

  Future<List<HistoryEntry>> getHistory(String vehicleId,
      {DatabaseExecutor? txn}) async {
    final db = await _exec(txn);
    final rows = await db.query(
      'vehicle_history',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'timestamp DESC, id DESC',
    );
    return rows.map(HistoryEntry.fromMap).toList();
  }

  Future<void> insertHistory(HistoryEntry entry,
      {DatabaseExecutor? txn}) async {
    final db = await _exec(txn);
    await db.insert('vehicle_history', entry.toMap());
  }

  // ---------------------------------------------------------------- Favoris

  Future<Set<String>> getFavorites({DatabaseExecutor? txn}) async {
    final db = await _exec(txn);
    final rows = await db.query('favorites');
    return {for (final r in rows) r['vehicle_id'] as String};
  }

  Future<Set<String>> getFavoriteIds({DatabaseExecutor? txn}) =>
      getFavorites(txn: txn);

  Future<bool> isFavorite(String vehicleId, {DatabaseExecutor? txn}) async {
    final db = await _exec(txn);
    final rows = await db.query('favorites',
        where: 'vehicle_id = ?', whereArgs: [vehicleId]);
    return rows.isNotEmpty;
  }

  Future<void> addFavorite(String vehicleId, DateTime now,
      {DatabaseExecutor? txn}) async {
    final db = await _exec(txn);
    await db.insert(
      'favorites',
      {'vehicle_id': vehicleId, 'created_at': now.toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeFavorite(String vehicleId,
      {DatabaseExecutor? txn}) async {
    final db = await _exec(txn);
    await db
        .delete('favorites', where: 'vehicle_id = ?', whereArgs: [vehicleId]);
  }

  // ---------------------------------------------------------------- Helpers

  Future<int> _count(String table, String? where, List<Object?>? args,
      DatabaseExecutor? txn) async {
    final db = await _exec(txn);
    final result = await db.rawQuery(
      'SELECT COUNT(*) as n FROM $table${where == null ? '' : ' WHERE $where'}',
      args,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
