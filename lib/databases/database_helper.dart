
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB('ekrili_karhba.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE incidents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            vehicleId INTEGER,
            title TEXT NOT NULL,
            description TEXT,
            severity TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'reported',
            latitude REAL,
            longitude REAL,
            createdAt TEXT NOT NULL,
            appIncidentId TEXT,
            vehicleModel TEXT,
            vehiclePlate TEXT,
            timeAgo TEXT,
            date TEXT,
            mileage INTEGER,
            location TEXT,
            isImmobilized INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE incidents ADD COLUMN appIncidentId TEXT');
          await db.execute('ALTER TABLE incidents ADD COLUMN vehicleModel TEXT');
          await db.execute('ALTER TABLE incidents ADD COLUMN vehiclePlate TEXT');
          await db.execute('ALTER TABLE incidents ADD COLUMN timeAgo TEXT');
          await db.execute('ALTER TABLE incidents ADD COLUMN date TEXT');
          await db.execute('ALTER TABLE incidents ADD COLUMN mileage INTEGER');
          await db.execute('ALTER TABLE incidents ADD COLUMN location TEXT');
          await db.execute('ALTER TABLE incidents ADD COLUMN isImmobilized INTEGER NOT NULL DEFAULT 0');
        }
      },
    );
  }

  Future<int> insertIncident(Map<String, dynamic> incident) async {
    final db = await database;
    return db.insert('incidents', incident);
  }

  Future<List<Map<String, dynamic>>> getIncidents() async {
    final db = await database;
    return db.query('incidents', orderBy: 'id DESC');
  }

  Future<int> updateIncident(
      int id,
      Map<String, dynamic> incident,
      ) async {
    final db = await database;
    return db.update(
      'incidents',
      incident,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteIncident(int id) async {
    final db = await database;
    return db.delete(
      'incidents',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
