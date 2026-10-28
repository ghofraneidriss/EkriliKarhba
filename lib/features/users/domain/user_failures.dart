/// Exceptions et échecs métier du module Utilisateurs (pur Dart).
library;

sealed class UserFailure implements Exception {
  const UserFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Échec de validation formulaire / données utilisateur.
class UserValidationFailure extends UserFailure {
  const UserValidationFailure(this.errors, [super.message = 'Données utilisateur invalides']);

  final Map<String, String> errors;

  String? errorFor(String field) => errors[field];
  bool hasError(String field) => errors.containsKey(field);

  @override
  String toString() =>
      '$message: ${errors.entries.map((e) => '${e.key}: ${e.value}').join(', ')}';
}

/// Violation d'une règle de sécurité ou d'intégrité métier
/// (ex. auto-bannissement, dernier admin actif, agence avec véhicules).
class UserRuleFailure extends UserFailure {
  const UserRuleFailure(super.message);
}

/// Erreur de permission (ex. action réservée à l'administrateur).
class UserPermissionFailure extends UserFailure {
  const UserPermissionFailure([super.message = 'Action réservée aux administrateurs']);
}

/// Utilisateur non trouvé.
class UserNotFoundFailure extends UserFailure {
  const UserNotFoundFailure([super.message = 'Utilisateur introuvable']);
}

/// Conflit de données (ex. adresse email déjà utilisée).
class UserConflictFailure extends UserFailure {
  const UserConflictFailure(this.field, super.message);
  final String field;
}

