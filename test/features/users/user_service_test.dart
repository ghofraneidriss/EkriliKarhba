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
    await service.ensureInitialized();
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
  });
}

