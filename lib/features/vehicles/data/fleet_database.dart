import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'seed_data.dart';

/// Base SQLite du module Véhicules (fichier `ekrili_vehicles.db`).
///
/// Tables : agencies, categories, vehicles, vehicle_documents,
/// unavailabilities, vehicle_history, favorites.
/// Les données de démonstration sont insérées à la création de la base.
class FleetDatabase {
  FleetDatabase({
    DatabaseFactory? factory,
    String? path,
    this.withSeedData = true,
    DateTime Function()? clock,
  })  : _factory = factory,
        _path = path,
        _clock = clock ?? DateTime.now;

  static const String fileName = 'ekrili_vehicles.db';
  static const int schemaVersion = 1;
  static const String _memoryPath = ':memory:';

  final DatabaseFactory? _factory;
  final String? _path;
  final bool withSeedData;
  final DateTime Function() _clock;

  Future<Database>? _opening;

  /// Ouvre la base au premier appel puis renvoie toujours la même.
  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() async {
    final factory = _factory ?? databaseFactory;
    final path = _path ?? p.join(await factory.getDatabasesPath(), fileName);
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        singleInstance: path != _memoryPath,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await _createSchema(db);
          if (withSeedData) await SeedData.insert(db, _clock());
        },
      ),
    );
  }

  Future<void> close() async {
    final opening = _opening;
    _opening = null;
    if (opening != null) await (await opening).close();
  }

  static Future<void> _createSchema(Database db) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE agencies (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        city TEXT NOT NULL,
        address TEXT NOT NULL DEFAULT '',
        phone TEXT NOT NULL DEFAULT '',
        email TEXT NOT NULL DEFAULT '',
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )''');
    batch.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE COLLATE NOCASE,
        description TEXT NOT NULL DEFAULT '',
        min_price REAL NOT NULL,
        max_price REAL NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      )''');
    batch.execute('''
      CREATE TABLE vehicles (
        id TEXT PRIMARY KEY,
        agency_id TEXT NOT NULL REFERENCES agencies(id),
        category_id TEXT NOT NULL REFERENCES categories(id),
        brand TEXT NOT NULL,
        model TEXT NOT NULL,
        year INTEGER NOT NULL,
        registration_plate TEXT NOT NULL UNIQUE,
        color TEXT NOT NULL DEFAULT '',
        fuel TEXT NOT NULL,
        transmission TEXT NOT NULL,
        seats INTEGER NOT NULL,
        doors INTEGER NOT NULL,
        mileage INTEGER NOT NULL,
        price_per_day REAL NOT NULL,
        deposit REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL,
        validation TEXT NOT NULL,
        rejection_reason TEXT,
        description TEXT NOT NULL DEFAULT '',
        photos TEXT NOT NULL DEFAULT '[]',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )''');
    batch.execute('''
      CREATE TABLE vehicle_documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicle_id TEXT NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
        type TEXT NOT NULL,
        reference TEXT NOT NULL DEFAULT '',
        expiry_date TEXT,
        note TEXT NOT NULL DEFAULT ''
      )''');
    batch.execute('''
      CREATE TABLE unavailabilities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicle_id TEXT NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        reason TEXT NOT NULL DEFAULT 'Autre'
      )''');
    // Pas de clé étrangère : l'historique survit à la suppression.
    batch.execute('''
      CREATE TABLE vehicle_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicle_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        actor TEXT NOT NULL,
        action TEXT NOT NULL,
        field TEXT,
        old_value TEXT,
        new_value TEXT,
        comment TEXT
      )''');
    batch.execute('''
      CREATE TABLE favorites (
        vehicle_id TEXT PRIMARY KEY REFERENCES vehicles(id) ON DELETE CASCADE,
        created_at TEXT NOT NULL
      )''');
    batch.execute('CREATE INDEX idx_vehicles_agency ON vehicles(agency_id)');
    batch.execute('CREATE INDEX idx_vehicles_category ON vehicles(category_id)');
    batch.execute('CREATE INDEX idx_vehicles_status ON vehicles(status)');
    batch.execute(
        'CREATE INDEX idx_unavail_vehicle ON unavailabilities(vehicle_id)');
    batch.execute(
        'CREATE INDEX idx_history_vehicle ON vehicle_history(vehicle_id)');
    batch.execute(
        'CREATE INDEX idx_documents_vehicle ON vehicle_documents(vehicle_id)');
    await batch.commit(noResult: true);
  }
}
