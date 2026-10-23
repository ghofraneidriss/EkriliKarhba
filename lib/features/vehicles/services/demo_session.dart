import 'package:flutter/foundation.dart';

import '../domain/actor.dart';
import '../domain/agency.dart';
import '../domain/enums.dart';

/// Profil choisi dans le sélecteur de démonstration de l'onglet Véhicules.
///
/// Remplaçable plus tard par le vrai login du module Utilisateurs :
/// il suffira d'appeler [signInAs] avec le rôle de l'utilisateur connecté.
class DemoSession extends ChangeNotifier {
  DemoSession._();

  static final DemoSession instance = DemoSession._();

  UserRole? _role;
  Agency? _agency;

  /// Notifications « papiers » fermées pendant cette connexion
  /// (clés DocumentAlert.key). Elles réapparaissent à la connexion suivante.
  final Set<String> _dismissedAlerts = {};

  UserRole? get role => _role;
  Agency? get agency => _agency;
  bool get isSignedIn => _role != null;

  bool isAlertDismissed(String key) => _dismissedAlerts.contains(key);

  /// Ferme les notifications données jusqu'à la prochaine connexion.
  void dismissAlerts(Iterable<String> keys) => _dismissedAlerts.addAll(keys);

  /// L'acteur utilisé pour les droits et l'historique.
  Actor get actor => switch (_role) {
        UserRole.admin => const Actor.admin(),
        UserRole.agence => Actor.agency(_agency!.id),
        _ => const Actor.client(),
      };

  void signInAs(UserRole role, {Agency? agency}) {
    if (role == UserRole.agence && agency == null) {
      throw ArgumentError('Une agence doit être choisie pour ce profil.');
    }
    _role = role;
    _agency = role == UserRole.agence ? agency : null;
    _dismissedAlerts.clear();
    notifyListeners();
  }

  void signOut() {
    _role = null;
    _agency = null;
    _dismissedAlerts.clear();
    notifyListeners();
  }
}
