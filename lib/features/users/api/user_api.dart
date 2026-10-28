import '../domain/user.dart';
import '../services/user_service.dart';

/// Façade publique exposée par le module Users aux autres modules de l'application
/// (Véhicules, Réservations, Maintenance, etc.).
///
/// Aucun module externe ne doit accéder directement à la base de données SQLite
/// ou aux classes internes de `features/users`.
class UserApi {
  UserApi({UserService? service}) : _service = service ?? UserService.instance;

  static UserApi? _instance;

  /// Instance partagée de la façade publique.
  static UserApi get instance => _instance ??= UserApi();

  final UserService _service;

  /// Utilisateur actuellement connecté dans l'application.
  User? get currentUser => _service.currentUser;

  /// Vérifie si une session est active.
  bool get isAuthenticated => _service.currentUser != null;

  /// Vérifie si l'utilisateur donné a le droit de se connecter.
  bool canLogin(User user) => user.canLogin;

  /// Récupère un utilisateur par son identifiant unique.
  Future<User?> getUser(int id) => _service.getUserById(id);

  /// Récupère la liste de tous les utilisateurs ayant le rôle Agence.
  Future<List<User>> getAgencies() => _service.getAgencies();

  /// Vérifie si un compte utilisateur est actif et existe.
  Future<bool> isUserActive(int id) async {
    final user = await _service.getUserById(id);
    return user != null && user.isActif;
  }
}

