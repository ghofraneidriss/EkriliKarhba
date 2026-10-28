import '../domain/user.dart';

/// Contrat abstrait pour la persistance des utilisateurs.
abstract class UserRepository {
  /// Insère un nouvel utilisateur et consigne l'événement dans user_history.
  Future<User> insertUser(User user, {String? actor, String? comment});

  /// Met à jour les informations d'un utilisateur et consigne l'événement dans user_history.
  Future<User> updateUser(User user, {String? actor, String? comment});

  /// Supprime un utilisateur et consigne l'événement dans user_history.
  Future<void> deleteUser(int id, {String? actor, String? comment});

  /// Récupère un utilisateur par son identifiant unique.
  Future<User?> getById(int id);

  /// Récupère un utilisateur par son adresse email (insensible à la casse).
  Future<User?> getByEmail(String email);

  /// Liste les utilisateurs avec filtres optionnels par rôle, statut et recherche textuelle.
  Future<List<User>> listUsers({
    UserRole? role,
    UserStatus? status,
    String? query,
  });

  /// Modifie le statut d'un utilisateur et consigne l'événement dans user_history.
  Future<void> setUserStatus(
    int id,
    UserStatus status, {
    String? actor,
    String? comment,
  });

  /// Compte le nombre d'administrateurs actuellement avec le statut ACTIF.
  Future<int> countActiveAdmins();

  /// Vérifie si une agence possède des véhicules enregistrés dans la flotte.
  Future<bool> agencyHasVehicles(int agencyId);

  /// Vérifie si une adresse email existe déjà (avec exclusion optionnelle d'un id).
  Future<bool> emailExists(String email, {int? excludeId});

  /// Récupère l'historique d'audit des actions relatives à un utilisateur.
  Future<List<Map<String, dynamic>>> getUserHistory(int userId);

  /// Enregistre l'identifiant de session active persistante.
  Future<void> saveActiveSession(int userId);

  /// Récupère l'identifiant de la session active sauvegardée, ou null si aucune.
  Future<int?> getActiveSessionUserId();

  /// Supprime la session active sauvegardée (déconnexion).
  Future<void> clearActiveSession();
}

