import 'package:sqflite/sqflite.dart';

import '../../vehicles/data/fleet_database.dart';
import '../domain/user.dart';
import 'user_repository.dart';

/// Implémentation SQLite sécurisée de [UserRepository] via [FleetDatabase].
class SqliteUserRepository implements UserRepository {
  SqliteUserRepository(this._database, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final FleetDatabase _database;
  final DateTime Function() _clock;

  Future<Database> get _db => _database.database;

  @override
  Future<User> insertUser(User user, {String? actor, String? comment}) async {
    final db = await _db;
    final now = _clock();
    final candidate = user.copyWith(
      createdAt: user.createdAt,
      updatedAt: now,
    );

    return await db.transaction<User>((txn) async {
      final map = candidate.toMap();
      map.remove('id'); // Laisser SQLite générer l'id auto-incrémenté

      final id = await txn.insert(
        'users',
        map,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      final insertedUser = candidate.copyWith(id: id);

      // Audit trail
      await txn.insert('user_history', {
        'user_id': id,
        'timestamp': now.toIso8601String(),
        'actor': actor ?? 'Système',
        'action': 'CREATION',
        'comment': comment ?? 'Création du compte ${insertedUser.displayName} (${insertedUser.role.label})',
      });

      return insertedUser;
    });
  }

  @override
  Future<User> updateUser(User user, {String? actor, String? comment}) async {
    if (user.id == null) {
      throw ArgumentError('Impossible de mettre à jour un utilisateur sans ID.');
    }

    final db = await _db;
    final now = _clock();
    final candidate = user.copyWith(updatedAt: now);

    return await db.transaction<User>((txn) async {
      // Récupérer l'état actuel pour l'historique
      final currentRows = await txn.query(
        'users',
        where: 'id = ?',
        whereArgs: [user.id],
        limit: 1,
      );

      final current = currentRows.isNotEmpty ? User.fromMap(currentRows.first) : null;

      final count = await txn.update(
        'users',
        candidate.toMap(),
        where: 'id = ?',
        whereArgs: [user.id],
      );

      if (count == 0) {
        throw StateError('Utilisateur introuvable pour la mise à jour (id: ${user.id}).');
      }

      // Audit trail
      final changes = <String>[];
      if (current != null) {
        if (current.nom != candidate.nom) changes.add('Nom');
        if (current.prenom != candidate.prenom) changes.add('Prénom');
        if (current.telephone != candidate.telephone) changes.add('Téléphone');
        if (current.nomAgence != candidate.nomAgence) changes.add("Nom d'agence");
        if (current.adresseAgence != candidate.adresseAgence) changes.add("Adresse d'agence");
        if (current.motDePasse != candidate.motDePasse) changes.add('Mot de passe');
      }

      await txn.insert('user_history', {
        'user_id': user.id!,
        'timestamp': now.toIso8601String(),
        'actor': actor ?? 'Système',
        'action': 'MODIFICATION',
        'comment': comment ?? (changes.isNotEmpty ? 'Champs modifiés: ${changes.join(', ')}' : 'Mise à jour du profil'),
      });

      return candidate;
    });
  }

  @override
  Future<void> deleteUser(int id, {String? actor, String? comment}) async {
    final db = await _db;
    final now = _clock();

    await db.transaction<void>((txn) async {
      final rows = await txn.query(
        'users',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      final targetName = rows.isNotEmpty
          ? '${rows.first['prenom']} ${rows.first['nom']}'
          : 'id $id';

      final count = await txn.delete(
        'users',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (count == 0) {
        throw StateError('Utilisateur introuvable pour la suppression (id: $id).');
      }

      // Audit trail
      await txn.insert('user_history', {
        'user_id': id,
        'timestamp': now.toIso8601String(),
        'actor': actor ?? 'Système',
        'action': 'SUPPRESSION',
        'comment': comment ?? 'Suppression du compte $targetName',
      });
    });
  }

  @override
  Future<User?> getById(int id) async {
    final db = await _db;
    final rows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return User.fromMap(rows.first);
  }

  @override
  Future<User?> getByEmail(String email) async {
    final db = await _db;
    final rows = await db.query(
      'users',
      where: 'LOWER(TRIM(email)) = LOWER(TRIM(?))',
      whereArgs: [email],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return User.fromMap(rows.first);
  }

  @override
  Future<List<User>> listUsers({
    UserRole? role,
    UserStatus? status,
    String? query,
  }) async {
    final db = await _db;
    final conditions = <String>[];
    final args = <Object?>[];

    if (role != null) {
      conditions.add('role = ?');
      args.add(role.code);
    }

    if (status != null) {
      conditions.add('statut = ?');
      args.add(status.code);
    }

    if (query != null && query.trim().isNotEmpty) {
      final pattern = '%${query.trim().toLowerCase()}%';
      conditions.add(
        '(LOWER(nom) LIKE ? OR LOWER(prenom) LIKE ? OR LOWER(email) LIKE ? OR LOWER(telephone) LIKE ? OR (nom_agence IS NOT NULL AND LOWER(nom_agence) LIKE ?))',
      );
      args.addAll([pattern, pattern, pattern, pattern, pattern]);
    }

    final whereClause = conditions.isEmpty ? null : conditions.join(' AND ');

    final rows = await db.query(
      'users',
      where: whereClause,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
    );

    return rows.map(User.fromMap).toList();
  }

  @override
  Future<void> setUserStatus(
    int id,
    UserStatus status, {
    String? actor,
    String? comment,
  }) async {
    final db = await _db;
    final now = _clock();

    await db.transaction<void>((txn) async {
      final rows = await txn.query(
        'users',
        columns: ['statut', 'nom', 'prenom'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (rows.isEmpty) {
        throw StateError('Utilisateur introuvable (id: $id).');
      }

      final oldStatus = rows.first['statut'] as String;
      final userName = '${rows.first['prenom']} ${rows.first['nom']}';

      await txn.update(
        'users',
        {
          'statut': status.code,
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      await txn.insert('user_history', {
        'user_id': id,
        'timestamp': now.toIso8601String(),
        'actor': actor ?? 'Système',
        'action': 'STATUT',
        'field': 'statut',
        'old_value': oldStatus,
        'new_value': status.code,
        'comment': comment ?? 'Changement de statut de $userName vers ${status.label}',
      });
    });
  }

  @override
  Future<int> countActiveAdmins() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM users WHERE role = ? AND statut = ?',
      [UserRole.admin.code, UserStatus.actif.code],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<bool> agencyHasVehicles(int agencyId) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM vehicles WHERE agency_id = ?',
      [agencyId],
    );
    final count = Sqflite.firstIntValue(result) ?? 0;
    return count > 0;
  }

  @override
  Future<bool> emailExists(String email, {int? excludeId}) async {
    final db = await _db;
    final result = await db.rawQuery(
      excludeId == null
          ? 'SELECT COUNT(*) as c FROM users WHERE LOWER(TRIM(email)) = LOWER(TRIM(?))'
          : 'SELECT COUNT(*) as c FROM users WHERE LOWER(TRIM(email)) = LOWER(TRIM(?)) AND id != ?',
      excludeId == null ? [email] : [email, excludeId],
    );
    final count = Sqflite.firstIntValue(result) ?? 0;
    return count > 0;
  }

  @override
  Future<List<Map<String, dynamic>>> getUserHistory(int userId) async {
    final db = await _db;
    return await db.query(
      'user_history',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
    );
  }
}

