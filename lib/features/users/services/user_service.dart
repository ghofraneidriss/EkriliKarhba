import 'package:flutter/foundation.dart';

import '../../vehicles/data/fleet_database.dart';
import '../data/password_hasher.dart';
import '../data/sqlite_user_repository.dart';
import '../data/user_repository.dart';
import '../domain/user.dart';
import '../domain/user_failures.dart';
import '../domain/user_security_rules.dart';
import '../domain/user_validators.dart';

/// Service métier centralisant la gestion des utilisateurs, les contrôles de
/// saisie, l'application stricte des règles de sécurité et les notifications UI.
class UserService extends ChangeNotifier {
  UserService({
    UserRepository? repository,
    DateTime Function()? clock,
  })  : _clock = clock ?? DateTime.now,
        _repo = repository ??
            SqliteUserRepository(
              FleetDatabase(clock: clock),
              clock: clock,
            );

  static UserService? _instance;

  /// Singleton partagé dans toute l'application.
  static UserService get instance => _instance ??= UserService();

  @visibleForTesting
  static set instance(UserService service) => _instance = service;

  final UserRepository _repo;
  final DateTime Function() _clock;

  User? _currentUser;

  /// Utilisateur actuellement connecté dans l'application.
  User? get currentUser => _currentUser;

  /// Modifie l'utilisateur courant (utilisé pour les tests ou la session).
  void setCurrentUser(User? user) {
    _currentUser = user;
    notifyListeners();
  }

  /// Initialise la session avec le compte admin par défaut s'il n'y a pas d'utilisateur connecté.
  Future<void> ensureInitialized() async {
    if (_currentUser == null) {
      final defaultAdmin = await _repo.getById(1);
      if (defaultAdmin != null) {
        _currentUser = defaultAdmin;
      }
    }
  }

  /// Création d'un utilisateur par un administrateur.
  Future<User> createUser({
    required String nom,
    required String prenom,
    required String email,
    required String motDePasse,
    required String telephone,
    required UserRole role,
    required UserStatus statut,
    String? nomAgence,
    String? adresseAgence,
    String? niveauAcces,
    required User actor,
  }) async {
    // 1. Contrôle des droits d'accès
    UserSecurityRules.ensureAdmin(actor);

    // 2. Validation stricte côté serveur
    final validation = UserValidators.validateCreate(
      nom: nom,
      prenom: prenom,
      email: email,
      motDePasse: motDePasse,
      telephone: telephone,
      role: role,
      nomAgence: nomAgence,
      adresseAgence: adresseAgence,
    );

    if (validation.hasErrors) {
      throw UserValidationFailure(validation.errors);
    }

    // 3. Vérification de l'unicité de l'email
    final normalizedEmail = UserValidators.normalizeEmail(email);
    if (await _repo.emailExists(normalizedEmail)) {
      throw const UserConflictFailure('email', 'Cette adresse email est déjà associée à un compte.');
    }

    // 4. Hachage cryptographique du mot de passe avec sel aléatoire
    final salt = PasswordHasher.generateSalt();
    final hashedPassword = PasswordHasher.hashPassword(motDePasse, salt);

    final now = _clock();
    final userToCreate = User(
      nom: nom.trim(),
      prenom: prenom.trim(),
      email: normalizedEmail,
      motDePasse: hashedPassword,
      passwordSalt: salt,
      telephone: UserValidators.normalizePhone(telephone),
      role: role,
      statut: statut,
      nomAgence: role == UserRole.agence ? nomAgence?.trim() : null,
      adresseAgence: role == UserRole.agence ? adresseAgence?.trim() : null,
      niveauAcces: role == UserRole.admin ? niveauAcces?.trim() : null,
      createdAt: now,
      updatedAt: now,
    );

    final created = await _repo.insertUser(
      userToCreate,
      actor: '${actor.prenom} ${actor.nom} (${actor.role.label})',
    );

    notifyListeners();
    return created;
  }

  /// Mise à jour d'un utilisateur par un administrateur.
  Future<User> updateUser({
    required int id,
    required String nom,
    required String prenom,
    required String email,
    String? motDePasse,
    required String telephone,
    required UserRole role,
    required UserStatus statut,
    String? nomAgence,
    String? adresseAgence,
    String? niveauAcces,
    required User actor,
  }) async {
    UserSecurityRules.ensureAdmin(actor);

    final existing = await _repo.getById(id);
    if (existing == null) {
      throw UserNotFoundFailure('Utilisateur introuvable (id: $id).');
    }

    // Validation stricte
    final validation = UserValidators.validateUpdate(
      nom: nom,
      prenom: prenom,
      email: email,
      motDePasse: motDePasse,
      telephone: telephone,
      role: role,
      nomAgence: nomAgence,
      adresseAgence: adresseAgence,
    );

    if (validation.hasErrors) {
      throw UserValidationFailure(validation.errors);
    }

    // Vérification unicité email si modifié
    final normalizedEmail = UserValidators.normalizeEmail(email);
    if (normalizedEmail != existing.email.toLowerCase()) {
      if (await _repo.emailExists(normalizedEmail, excludeId: id)) {
        throw const UserConflictFailure('email', 'Cette adresse email est déjà associée à un autre compte.');
      }
    }

    // Règles de changement de statut si le statut change
    if (statut != existing.statut) {
      final activeAdminCount = await _repo.countActiveAdmins();
      UserSecurityRules.ensureCanChangeStatus(
        actor: actor,
        target: existing,
        newStatus: statut,
        activeAdminCount: activeAdminCount,
      );
    }

    // Règle de rétrogradation du dernier admin actif
    if (existing.role == UserRole.admin && role != UserRole.admin && existing.statut == UserStatus.actif) {
      final activeAdminCount = await _repo.countActiveAdmins();
      if (activeAdminCount <= 1) {
        throw const UserRuleFailure(
          'Impossible de modifier le rôle du dernier administrateur actif.',
        );
      }
    }

    // Gestion du mot de passe
    String newHash = existing.motDePasse;
    String newSalt = existing.passwordSalt;
    if (motDePasse != null && motDePasse.trim().isNotEmpty) {
      newSalt = PasswordHasher.generateSalt();
      newHash = PasswordHasher.hashPassword(motDePasse, newSalt);
    }

    final updated = existing.copyWith(
      nom: nom.trim(),
      prenom: prenom.trim(),
      email: normalizedEmail,
      motDePasse: newHash,
      passwordSalt: newSalt,
      telephone: UserValidators.normalizePhone(telephone),
      role: role,
      statut: statut,
      nomAgence: role == UserRole.agence ? nomAgence?.trim() : null,
      adresseAgence: role == UserRole.agence ? adresseAgence?.trim() : null,
      niveauAcces: role == UserRole.admin ? niveauAcces?.trim() : null,
      updatedAt: _clock(),
    );

    final saved = await _repo.updateUser(
      updated,
      actor: '${actor.prenom} ${actor.nom} (${actor.role.label})',
    );

    if (_currentUser?.id == id) {
      _currentUser = saved;
    }

    notifyListeners();
    return saved;
  }

  /// Mise à jour de son propre profil par l'utilisateur connecté.
  Future<User> updateOwnProfile({
    required int id,
    required String nom,
    required String prenom,
    required String telephone,
    String? email,
    String? nomAgence,
    String? adresseAgence,
    String? oldPassword,
    String? newPassword,
    required User actor,
  }) async {
    if (actor.id != id) {
      throw const UserPermissionFailure(
        'Vous ne pouvez modifier que votre propre profil.',
      );
    }

    final existing = await _repo.getById(id);
    if (existing == null) {
      throw UserNotFoundFailure('Utilisateur introuvable (id: $id).');
    }

    final targetEmail = email ?? existing.email;

    // Validation nom, prénom, email, téléphone et champs agence
    final validation = UserValidators.validateProfileUpdate(
      nom: nom,
      prenom: prenom,
      telephone: telephone,
      email: targetEmail,
      nouveauMotDePasse: newPassword,
      nomAgence: existing.isAgence ? nomAgence : null,
      adresseAgence: existing.isAgence ? adresseAgence : null,
      role: existing.role,
    );

    final errors = Map<String, String>.from(validation.errors);

    // Vérification de l'unicité de l'email si modifié
    final normalizedEmail = UserValidators.normalizeEmail(targetEmail);
    if (normalizedEmail != existing.email.toLowerCase()) {
      if (await _repo.emailExists(normalizedEmail, excludeId: id)) {
        errors['email'] = 'Cette adresse email est déjà associée à un autre compte.';
      }
    }

    // Gestion du changement de mot de passe
    String newHash = existing.motDePasse;
    String newSalt = existing.passwordSalt;

    if (newPassword != null && newPassword.trim().isNotEmpty) {
      if (oldPassword == null || oldPassword.isEmpty) {
        errors['oldPassword'] = "L'ancien mot de passe est obligatoire pour changer de mot de passe.";
      } else {
        final matches = PasswordHasher.verifyPassword(oldPassword, existing.passwordSalt, existing.motDePasse);
        if (!matches) {
          errors['oldPassword'] = "L'ancien mot de passe saisi est incorrect.";
        }
      }

      if (errors.isEmpty) {
        newSalt = PasswordHasher.generateSalt();
        newHash = PasswordHasher.hashPassword(newPassword, newSalt);
      }
    }

    if (errors.isNotEmpty) {
      throw UserValidationFailure(errors);
    }

    final updated = existing.copyWith(
      nom: nom.trim(),
      prenom: prenom.trim(),
      email: normalizedEmail,
      telephone: UserValidators.normalizePhone(telephone),
      nomAgence: existing.isAgence ? nomAgence?.trim() : existing.nomAgence,
      adresseAgence: existing.isAgence ? adresseAgence?.trim() : existing.adresseAgence,
      motDePasse: newHash,
      passwordSalt: newSalt,
      updatedAt: _clock(),
    );

    final saved = await _repo.updateUser(
      updated,
      actor: '${actor.prenom} ${actor.nom} (Mon Profil)',
      comment: 'Modification de ses informations personnelles',
    );

    _currentUser = saved;
    notifyListeners();
    return saved;
  }

  /// Change le statut d'un utilisateur (Activer / Désactiver / Bannir).
  Future<void> setStatus({
    required int userId,
    required UserStatus newStatus,
    required User actor,
  }) async {
    UserSecurityRules.ensureAdmin(actor);

    final target = await _repo.getById(userId);
    if (target == null) {
      throw UserNotFoundFailure('Utilisateur introuvable (id: $userId).');
    }

    final activeAdminCount = await _repo.countActiveAdmins();
    UserSecurityRules.ensureCanChangeStatus(
      actor: actor,
      target: target,
      newStatus: newStatus,
      activeAdminCount: activeAdminCount,
    );

    await _repo.setUserStatus(
      userId,
      newStatus,
      actor: '${actor.prenom} ${actor.nom} (${actor.role.label})',
    );

    if (_currentUser?.id == userId) {
      _currentUser = target.copyWith(statut: newStatus);
    }

    notifyListeners();
  }

  /// Bascule le bannissement (Bannir ou Débannir).
  Future<void> toggleBan({
    required int userId,
    required User actor,
  }) async {
    final target = await _repo.getById(userId);
    if (target == null) {
      throw UserNotFoundFailure('Utilisateur introuvable (id: $userId).');
    }

    final nextStatus = target.isBanni ? UserStatus.actif : UserStatus.banni;
    await setStatus(userId: userId, newStatus: nextStatus, actor: actor);
  }

  /// Bascule l'activation (Activer ou Désactiver).
  Future<void> toggleActive({
    required int userId,
    required User actor,
  }) async {
    final target = await _repo.getById(userId);
    if (target == null) {
      throw UserNotFoundFailure('Utilisateur introuvable (id: $userId).');
    }

    final nextStatus = target.isActif ? UserStatus.desactive : UserStatus.actif;
    await setStatus(userId: userId, newStatus: nextStatus, actor: actor);
  }

  /// Suppression définitive d'un compte utilisateur avec vérifications métier.
  Future<void> deleteUser({
    required int userId,
    required User actor,
  }) async {
    UserSecurityRules.ensureAdmin(actor);

    final target = await _repo.getById(userId);
    if (target == null) {
      throw UserNotFoundFailure('Utilisateur introuvable (id: $userId).');
    }

    final activeAdminCount = await _repo.countActiveAdmins();
    final vehicleCount = target.isAgence ? (await _repo.agencyHasVehicles(userId) ? 1 : 0) : 0;

    UserSecurityRules.ensureCanDelete(
      actor: actor,
      target: target,
      activeAdminCount: activeAdminCount,
      vehicleCount: vehicleCount,
    );

    await _repo.deleteUser(
      userId,
      actor: '${actor.prenom} ${actor.nom} (${actor.role.label})',
    );

    notifyListeners();
  }

  /// Recherche filtrée d'utilisateurs.
  Future<List<User>> getUsers({
    UserRole? role,
    UserStatus? status,
    String? query,
  }) {
    return _repo.listUsers(role: role, status: status, query: query);
  }

  /// Récupère un utilisateur par son identifiant.
  Future<User?> getUserById(int id) => _repo.getById(id);

  /// Récupère un utilisateur par son adresse email.
  Future<User?> getUserByEmail(String email) => _repo.getByEmail(email);

  /// Récupère toutes les agences enregistrées (utilisé par d'autres modules).
  Future<List<User>> getAgencies() => _repo.listUsers(role: UserRole.agence);

  /// Compte les administrateurs actifs.
  Future<int> countActiveAdmins() => _repo.countActiveAdmins();

  /// Récupère l'historique d'un utilisateur.
  Future<List<Map<String, dynamic>>> getUserHistory(int userId) =>
      _repo.getUserHistory(userId);
}
