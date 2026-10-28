import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ekrili_karhba/features/users/data/password_hasher.dart';
import 'package:ekrili_karhba/features/users/data/sqlite_user_repository.dart';
import 'package:ekrili_karhba/features/users/domain/user.dart';
import 'package:ekrili_karhba/features/users/domain/user_failures.dart';
import 'package:ekrili_karhba/features/users/services/user_service.dart';
import 'package:ekrili_karhba/features/vehicles/data/fleet_database.dart';

void main() {
  final now = DateTime(2026, 10, 28, 12, 0, 0);

  late FleetDatabase db;
  late SqliteUserRepository repo;
  late UserService service;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = FleetDatabase(
      factory: databaseFactoryFfi,
      path: ':memory:',
      clock: () => now,
    );

    // Initialise la base avec les seeds
    await db.database;

    repo = SqliteUserRepository(db, clock: () => now);
    service = UserService(repository: repo, clock: () => now);
    await service.ensureInitialized(autoLoginDefaultAdmin: true);
  });

  tearDown(() async {
    await db.close();
  });

  group('UserService - Initialisation & Consultation', () {
    test('initialise automatiquement la session avec le Super Admin par défaut (id: 1)', () async {
      expect(service.currentUser, isNotNull);
      expect(service.currentUser!.id, 1);
      expect(service.currentUser!.role, UserRole.admin);
      expect(service.currentUser!.isActif, isTrue);
    });

    test('recherche et filtres par rôle et statut', () async {
      final allUsers = await service.getUsers();
      expect(allUsers.length, greaterThanOrEqualTo(6));

      final admins = await service.getUsers(role: UserRole.admin);
      expect(admins.every((u) => u.isAdmin), isTrue);

      final agencies = await service.getAgencies();
      expect(agencies.every((u) => u.isAgence), isTrue);
      expect(agencies.length, 3);

      final clients = await service.getUsers(role: UserRole.client);
      expect(clients.every((u) => u.isClient), isTrue);
    });

    test('recherche textuelle insensible à la casse sur nom, prénom, email', () async {
      final searchByName = await service.getUsers(query: 'ben amor');
      expect(searchByName.any((u) => u.nom == 'Ben Amor'), isTrue);

      final searchByEmail = await service.getUsers(query: 'automobility');
      expect(searchByEmail.single.email, 'contact@automobility.tn');

      final searchByAgency = await service.getUsers(query: 'sahel');
      expect(searchByAgency.single.nomAgence, 'Sahel Rent Car');
    });
  });

  group('UserService - Création de compte', () {
    test("un admin peut créer un client valide avec mot de passe haché et salé", () async {
      final admin = service.currentUser!;
      final created = await service.createUser(
        nom: 'Trabelsi',
        prenom: 'Mohamed',
        email: 'mohamed.trabelsi@gmail.com',
        motDePasse: 'Secret123',
        telephone: '98765432',
        role: UserRole.client,
        statut: UserStatus.actif,
        actor: admin,
      );

      expect(created.id, isNotNull);
      expect(created.email, 'mohamed.trabelsi@gmail.com');
      expect(created.motDePasse, isNot('Secret123'));
      expect(
        PasswordHasher.verifyPassword('Secret123', created.passwordSalt, created.motDePasse),
        isTrue,
      );

      final history = await service.getUserHistory(created.id!);
      expect(history, isNotEmpty);
      expect(history.first['action'], 'CREATION');
    });

    test("un admin peut créer une agence avec nom et adresse d'agence obligatoires", () async {
      final admin = service.currentUser!;
      final created = await service.createUser(
        nom: 'Ghazouani',
        prenom: 'Walid',
        email: 'contact@bizerterent.tn',
        motDePasse: 'Agence123',
        telephone: '72400500',
        role: UserRole.agence,
        statut: UserStatus.actif,
        nomAgence: 'Bizerte Rent Car',
        adresseAgence: 'Boulevard Habib Bourguiba, Bizerte',
        actor: admin,
      );

      expect(created.nomAgence, 'Bizerte Rent Car');
      expect(created.adresseAgence, 'Boulevard Habib Bourguiba, Bizerte');
    });

    test("refuse la création si un champ obligatoire manque pour une agence", () async {
      final admin = service.currentUser!;
      await expectLater(
        service.createUser(
          nom: 'Ghazouani',
          prenom: 'Walid',
          email: 'contact2@bizerterent.tn',
          motDePasse: 'Agence123',
          telephone: '72400500',
          role: UserRole.agence,
          statut: UserStatus.actif,
          nomAgence: '', // Manquant
          adresseAgence: 'Bizerte',
          actor: admin,
        ),
        throwsA(isA<UserValidationFailure>()
            .having((e) => e.hasError('nomAgence'), 'nomAgence error', isTrue)),
      );
    });

    test("refuse la création avec un email déjà existant", () async {
      final admin = service.currentUser!;
      await expectLater(
        service.createUser(
          nom: 'Autre',
          prenom: 'Admin',
          email: 'admin@ekrili.tn', // déjà pris par le Super Admin
          motDePasse: 'Admin1234',
          telephone: '20202020',
          role: UserRole.admin,
          statut: UserStatus.actif,
          actor: admin,
        ),
        throwsA(isA<UserConflictFailure>()),
      );
    });

    test("un non-administrateur ne peut pas créer d'utilisateurs", () async {
      final client = (await service.getUsers(role: UserRole.client)).first;
      await expectLater(
        service.createUser(
          nom: 'Test',
          prenom: 'User',
          email: 'test@gmail.com',
          motDePasse: 'Test1234',
          telephone: '20304050',
          role: UserRole.client,
          statut: UserStatus.actif,
          actor: client,
        ),
        throwsA(isA<UserPermissionFailure>()),
      );
    });
  });

  group('UserService - Règles de sécurité métier', () {
    test("interdit à un admin de se bannir ou de se désactiver lui-même", () async {
      final admin = service.currentUser!;
      await expectLater(
        service.setStatus(
          userId: admin.id!,
          newStatus: UserStatus.banni,
          actor: admin,
        ),
        throwsA(isA<UserRuleFailure>()),
      );

      await expectLater(
        service.toggleActive(
          userId: admin.id!,
          actor: admin,
        ),
        throwsA(isA<UserRuleFailure>()),
      );
    });

    test("interdit à un admin de se supprimer lui-même", () async {
      final admin = service.currentUser!;
      await expectLater(
        service.deleteUser(
          userId: admin.id!,
          actor: admin,
        ),
        throwsA(isA<UserRuleFailure>()),
      );
    });

    test("interdit de désactiver ou bannir le DERNIER administrateur actif", () async {
      final admin = service.currentUser!;
      // Il n'y a qu'1 seul admin dans le seed (id: 1)
      expect(await service.countActiveAdmins(), 1);

      // On tente de le désactiver
      await expectLater(
        service.setStatus(
          userId: 1,
          newStatus: UserStatus.desactive,
          actor: admin,
        ),
        throwsA(isA<UserRuleFailure>()),
      );
    });

    test("autorise le changement de statut d'un admin si un autre admin actif existe", () async {
      final admin = service.currentUser!;

      // Créer un 2ème admin
      final admin2 = await service.createUser(
        nom: 'Second',
        prenom: 'Admin',
        email: 'admin2@ekrili.tn',
        motDePasse: 'Admin2Pass',
        telephone: '22334455',
        role: UserRole.admin,
        statut: UserStatus.actif,
        actor: admin,
      );

      expect(await service.countActiveAdmins(), 2);

      // L'admin 1 peut maintenant désactiver admin 2
      await service.setStatus(
        userId: admin2.id!,
        newStatus: UserStatus.desactive,
        actor: admin,
      );

      final updatedAdmin2 = await service.getUserById(admin2.id!);
      expect(updatedAdmin2!.statut, UserStatus.desactive);
      expect(await service.countActiveAdmins(), 1);
    });

    test("interdit de supprimer une agence qui possède des véhicules", () async {
      final admin = service.currentUser!;
      // L'agence Tunis (id: 2) possède des véhicules dans le seed
      await expectLater(
        service.deleteUser(userId: 2, actor: admin),
        throwsA(isA<UserRuleFailure>()),
      );
    });

    test("autorise la suppression d'un client ou d'une agence sans véhicule", () async {
      final admin = service.currentUser!;
      final client = await service.createUser(
        nom: 'Temporaire',
        prenom: 'Client',
        email: 'temp@gmail.com',
        motDePasse: 'Temp1234',
        telephone: '50607080',
        role: UserRole.client,
        statut: UserStatus.actif,
        actor: admin,
      );

      await service.deleteUser(userId: client.id!, actor: admin);
      expect(await service.getUserById(client.id!), isNull);
    });
  });

  group('UserService - Mon Profil', () {
    test("un utilisateur peut modifier ses coordonnées personnelles", () async {
      final admin = service.currentUser!;
      final updated = await service.updateOwnProfile(
        id: admin.id!,
        nom: 'Ben Amor Modifié',
        prenom: 'Yassine',
        telephone: '20100999',
        actor: admin,
      );

      expect(updated.nom, 'Ben Amor Modifié');
      expect(updated.telephone, '20100999');
      expect(service.currentUser!.nom, 'Ben Amor Modifié');
    });

    test("un utilisateur peut changer son mot de passe avec l'ancien mot de passe vérifié", () async {
      final admin = service.currentUser!;

      final updated = await service.updateOwnProfile(
        id: admin.id!,
        nom: admin.nom,
        prenom: admin.prenom,
        telephone: admin.telephone,
        oldPassword: 'Admin1234', // Ancien mot de passe correct
        newPassword: 'NewPassword99', // Nouveau mot de passe fort
        actor: admin,
      );

      expect(
        PasswordHasher.verifyPassword('NewPassword99', updated.passwordSalt, updated.motDePasse),
        isTrue,
      );
    });

    test("refuse le changement de mot de passe si l'ancien mot de passe est faux", () async {
      final admin = service.currentUser!;

      await expectLater(
        service.updateOwnProfile(
          id: admin.id!,
          nom: admin.nom,
          prenom: admin.prenom,
          telephone: admin.telephone,
          oldPassword: 'WrongPassword',
          newPassword: 'NewPassword99',
          actor: admin,
        ),
        throwsA(isA<UserValidationFailure>()
            .having((e) => e.hasError('oldPassword'), 'oldPassword error', isTrue)),
      );
    });

    test("un utilisateur peut modifier son adresse email si elle est disponible", () async {
      final admin = service.currentUser!;
      final updated = await service.updateOwnProfile(
        id: admin.id!,
        nom: admin.nom,
        prenom: admin.prenom,
        email: 'nouvel.admin@ekrili.tn',
        telephone: admin.telephone,
        actor: admin,
      );

      expect(updated.email, 'nouvel.admin@ekrili.tn');
      expect(service.currentUser!.email, 'nouvel.admin@ekrili.tn');
    });

    test("refuse la modification de son email vers un email déjà pris", () async {
      final admin = service.currentUser!;

      await expectLater(
        service.updateOwnProfile(
          id: admin.id!,
          nom: admin.nom,
          prenom: admin.prenom,
          email: 'contact@automobility.tn', // déjà pris par agence Tunis
          telephone: admin.telephone,
          actor: admin,
        ),
        throwsA(isA<UserValidationFailure>()
            .having((e) => e.hasError('email'), 'email error', isTrue)),
      );
    });
  });

  group('UserService - Authentification & Session', () {
    test('un administrateur peut se connecter avec son email et son mot de passe', () async {
      await service.logout();
      expect(service.isAuthenticated, isFalse);

      final loggedIn = await service.login(
        email: 'admin@ekrili.tn',
        password: 'Admin1234',
      );

      expect(loggedIn.email, 'admin@ekrili.tn');
      expect(loggedIn.isAdmin, isTrue);
      expect(service.currentUser?.id, loggedIn.id);
      expect(service.isAuthenticated, isTrue);
    });

    test('une agence peut se connecter avec son propre email et son mot de passe', () async {
      await service.logout();
      final loggedIn = await service.login(
        email: 'contact@automobility.tn',
        password: 'Agence1234',
      );

      expect(loggedIn.email, 'contact@automobility.tn');
      expect(loggedIn.isAgence, isTrue);
      expect(loggedIn.nomAgence, 'Auto Mobility Tunis');
      expect(service.currentUser?.id, loggedIn.id);
    });

    test('un client peut se connecter avec son propre email et son mot de passe', () async {
      await service.logout();
      final loggedIn = await service.login(
        email: 'karim@gmail.com',
        password: 'Client1234',
      );

      expect(loggedIn.email, 'karim@gmail.com');
      expect(loggedIn.isClient, isTrue);
      expect(service.currentUser?.id, loggedIn.id);
    });

    test('refuse la connexion avec un mot de passe erroné', () async {
      await expectLater(
        service.login(
          email: 'admin@ekrili.tn',
          password: 'MauvaisMotDePasse',
        ),
        throwsA(isA<UserAuthFailure>()
            .having((e) => e.message, 'message', 'Email ou mot de passe incorrect.')),
      );
    });

    test('refuse la connexion avec un email inexistant', () async {
      await expectLater(
        service.login(
          email: 'inconnu@ekrili.tn',
          password: 'Password123',
        ),
        throwsA(isA<UserAuthFailure>()
            .having((e) => e.message, 'message', 'Email ou mot de passe incorrect.')),
      );
    });

    test('refuse la connexion si un champ est vide', () async {
      // Email vide → erreur de validation sur le champ 'email'
      await expectLater(
        service.login(email: '', password: 'Password123'),
        throwsA(isA<UserValidationFailure>()
            .having((e) => e.hasError('email'), 'email error', isTrue)),
      );
      // Mot de passe vide → erreur de validation sur le champ 'password'
      await expectLater(
        service.login(email: 'admin@ekrili.tn', password: ''),
        throwsA(isA<UserValidationFailure>()
            .having((e) => e.hasError('password'), 'password error', isTrue)),
      );
    });

    test("refuse la connexion si l'email a un format invalide", () async {
      await expectLater(
        service.login(email: 'pas-un-email', password: 'Password123'),
        throwsA(isA<UserValidationFailure>()
            .having((e) => e.hasError('email'), 'email error', isTrue)),
      );
    });

    test('refuse la connexion si le compte est désactivé', () async {
      await service.setStatus(
        userId: 5,
        newStatus: UserStatus.desactive,
        actor: service.currentUser!,
      );

      await expectLater(
        service.login(
          email: 'karim@gmail.com',
          password: 'Client1234',
        ),
        throwsA(isA<UserAuthFailure>()
            .having((e) => e.message, 'message', contains('désactivé'))),
      );
    });

    test('refuse la connexion si le compte est banni', () async {
      await service.setStatus(
        userId: 6,
        newStatus: UserStatus.banni,
        actor: service.currentUser!,
      );

      await expectLater(
        service.login(
          email: 'fatma@gmail.com',
          password: 'Client1234',
        ),
        throwsA(isA<UserAuthFailure>()
            .having((e) => e.message, 'message', contains('banni'))),
      );
    });

    test('logout() efface la session persistante et réinitialise le currentUser', () async {
      await service.login(
        email: 'admin@ekrili.tn',
        password: 'Admin1234',
      );
      expect(service.currentUser, isNotNull);

      await service.logout();
      expect(service.currentUser, isNull);
      expect(service.isAuthenticated, isFalse);

      final sessionUserId = await repo.getActiveSessionUserId();
      expect(sessionUserId, isNull);
    });

    test('la session active est persistée et restaurée via ensureInitialized()', () async {
      await service.login(
        email: 'contact@automobility.tn',
        password: 'Agence1234',
      );
      final loggedInId = service.currentUser!.id!;

      final newService = UserService(repository: repo, clock: () => now);
      expect(newService.currentUser, isNull);

      await newService.ensureInitialized();
      expect(newService.currentUser, isNotNull);
      expect(newService.currentUser!.id, loggedInId);
      expect(newService.currentUser!.isAgence, isTrue);
    });
  });

  group('UserService - Inscription libre-service (Register)', () {
    test("un client peut s'inscrire en libre-service et son compte est actif immédiatement", () async {
      final client = await service.register(
        nom: 'Driss',
        prenom: 'Tarek',
        email: 'tarek.driss@gmail.com',
        motDePasse: 'Tarek@1234',
        confirmationMotDePasse: 'Tarek@1234',
        telephone: '25112233',
        role: UserRole.client,
      );

      expect(client.id, isNotNull);
      expect(client.email, 'tarek.driss@gmail.com');
      expect(client.role, UserRole.client);
      expect(client.statut, UserStatus.actif);
      expect(client.isActif, isTrue);
      expect(client.canLogin, isTrue);

      // Vérifie que le mot de passe est bien haché
      expect(
        PasswordHasher.verifyPassword('Tarek@1234', client.passwordSalt, client.motDePasse),
        isTrue,
      );

      // Vérifie qu'il peut se connecter immédiatement
      final loggedIn = await service.login(
        email: 'tarek.driss@gmail.com',
        password: 'Tarek@1234',
      );
      expect(loggedIn.id, client.id);
    });

    test("une agence peut s'inscrire avec ses coordonnées professionnelles", () async {
      final agence = await service.register(
        nom: 'Hammami',
        prenom: 'Wassim',
        email: 'contact@carthagerent.tn',
        motDePasse: 'Carthage@1234',
        confirmationMotDePasse: 'Carthage@1234',
        telephone: '71987654',
        role: UserRole.agence,
        nomAgence: 'Carthage Rent',
        adresseAgence: 'Les Berges du Lac 2, Tunis',
      );

      expect(agence.id, isNotNull);
      expect(agence.isAgence, isTrue);
      expect(agence.statut, UserStatus.actif);
      expect(agence.nomAgence, 'Carthage Rent');
      expect(agence.adresseAgence, 'Les Berges du Lac 2, Tunis');

      // Vérifie qu'elle peut se connecter immédiatement
      final loggedIn = await service.login(
        email: 'contact@carthagerent.tn',
        password: 'Carthage@1234',
      );
      expect(loggedIn.id, agence.id);
      expect(loggedIn.isAgence, isTrue);
    });

    test("interdit l'inscription en tant qu'administrateur", () async {
      await expectLater(
        service.register(
          nom: 'Hacker',
          prenom: 'Joe',
          email: 'hacker@ekrili.tn',
          motDePasse: 'Admin@1234',
          confirmationMotDePasse: 'Admin@1234',
          telephone: '20112233',
          role: UserRole.admin,
        ),
        throwsA(isA<UserRuleFailure>()),
      );
    });

    test("refuse l'inscription si les mots de passe ne correspondent pas", () async {
      await expectLater(
        service.register(
          nom: 'Gharbi',
          prenom: 'Walid',
          email: 'walid@gmail.com',
          motDePasse: 'Secret@123',
          confirmationMotDePasse: 'DifferentPassword@123',
          telephone: '22112233',
          role: UserRole.client,
        ),
        throwsA(isA<UserValidationFailure>()
            .having((e) => e.hasError('confirmationMotDePasse'), 'confirmationMotDePasse error', isTrue)),
      );
    });

    test("refuse l'inscription si l'email existe déjà", () async {
      await expectLater(
        service.register(
          nom: 'Doublon',
          prenom: 'Test',
          email: 'admin@ekrili.tn', // déjà présent
          motDePasse: 'Valid@1234',
          confirmationMotDePasse: 'Valid@1234',
          telephone: '23112233',
          role: UserRole.client,
        ),
        throwsA(isA<UserConflictFailure>()
            .having((e) => e.field, 'field', 'email')),
      );
    });

    test("refuse l'inscription d'une agence sans nom d'agence ou sans adresse", () async {
      await expectLater(
        service.register(
          nom: 'Agence',
          prenom: 'Incomplète',
          email: 'incomplète@agence.tn',
          motDePasse: 'Valid@1234',
          confirmationMotDePasse: 'Valid@1234',
          telephone: '71112233',
          role: UserRole.agence,
          nomAgence: '',
          adresseAgence: '',
        ),
        throwsA(isA<UserValidationFailure>().having(
          (e) => e.hasError('nomAgence') && e.hasError('adresseAgence'),
          'agency fields required',
          isTrue,
        )),
      );
    });
  });
}

