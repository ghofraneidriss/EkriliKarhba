import 'dart:io';
import 'package:ekrili_karhba/features/vehicles/data/fleet_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main() async {
  sqfliteFfiInit();
  final dbPath = '${Directory.current.path}/ekrili_vehicles.db';
  final file = File(dbPath);
  if (file.existsSync()) {
    file.deleteSync();
  }

  final database = FleetDatabase(
    factory: databaseFactoryFfi,
    path: dbPath,
    withSeedData: true,
  );

  final db = await database.database;
  final tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';",
  );

  final tableNames = tables.map((t) => t['name']).toList();
  print('SUCCESS: Base SQLite générée : $dbPath');
  print('Tables trouvées : $tableNames');

  await database.close();
}

