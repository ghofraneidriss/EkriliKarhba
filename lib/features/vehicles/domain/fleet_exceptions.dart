/// Erreur métier : l'action est interdite par une règle de gestion
/// (statut incompatible, document expiré, prix hors catégorie, etc.).
/// Le message est en français et peut être affiché tel quel.
class FleetRuleException implements Exception {
  const FleetRuleException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Erreur de droits : le profil courant n'a pas le droit de faire l'action.
class FleetPermissionException implements Exception {
  const FleetPermissionException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Erreur de saisie sur un champ précis (affichable sous le champ).
class FleetValidationException implements Exception {
  const FleetValidationException(this.field, this.message);

  /// Nom du champ concerné (ex. 'registrationPlate').
  final String field;
  final String message;

  @override
  String toString() => message;
}

/// L'élément demandé n'existe pas (ou plus).
class FleetNotFoundException implements Exception {
  const FleetNotFoundException(this.message);
  final String message;

  @override
  String toString() => message;
}
