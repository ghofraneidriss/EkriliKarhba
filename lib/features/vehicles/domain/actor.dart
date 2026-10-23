import 'enums.dart';

/// Qui fait l'action : le profil et, pour une agence, son identifiant.
/// Sert aux contrôles de droits et à l'historique.
class Actor {
  const Actor._(this.role, this.agencyId, this.systemName);

  const Actor.client() : this._(UserRole.client, null, null);
  const Actor.admin() : this._(UserRole.admin, null, null);
  const Actor.agency(String agencyId)
      : this._(UserRole.agence, agencyId, null);

  /// Action déclenchée par un autre module (Réservations, Maintenance…)
  /// via VehicleApi. Elle a les droits nécessaires à ces opérations.
  const Actor.system(String moduleName)
      : this._(UserRole.admin, null, moduleName);

  final UserRole role;
  final String? agencyId;
  final String? systemName;

  bool get isAdmin => role == UserRole.admin;
  bool get isAgency => role == UserRole.agence;
  bool get isClient => role == UserRole.client;
  bool get isSystem => systemName != null;

  /// Libellé enregistré dans l'historique.
  String get label {
    if (systemName != null) return 'Module $systemName';
    return role.label;
  }
}
