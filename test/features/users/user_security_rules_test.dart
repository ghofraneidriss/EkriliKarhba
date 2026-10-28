import 'package:ekrili_karhba/features/users/domain/user.dart';
import 'package:ekrili_karhba/features/users/domain/user_failures.dart';
import 'package:ekrili_karhba/features/users/domain/user_security_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 28);

  User makeAdmin({int id = 1, UserStatus status = UserStatus.actif}) => User(
        id: id,
        nom: 'Admin',
        prenom: 'Mohamed',
        email: 'admin$id@ekrili.tn',
        motDePasse: 'hash',
        passwordSalt: 'salt',
        telephone: '20123456',
        role: UserRole.admin,
        statut: status,
        createdAt: now,
        updatedAt: now,
      );

  User makeAgency({int id = 2, int vehicleCount = 0}) => User(
        id: id,
        nom: 'Ben Salem',
        prenom: 'Ali',
        nomAgence: 'Ekrili Tunis',
        adresseAgence: 'Tunis Centre',
        email: 'agency$id@ekrili.tn',
        motDePasse: 'hash',
        passwordSalt: 'salt',
        telephone: '71123456',
        role: UserRole.agence,
        statut: UserStatus.actif,
        createdAt: now,
        updatedAt: now,
      );

  User makeClient({int id = 3}) => User(
        id: id,
        nom: 'Gharbi',
        prenom: 'Karim',
        email: 'karim@gmail.com',
        motDePasse: 'hash',
        passwordSalt: 'salt',
        telephone: '98123456',
        role: UserRole.client,
        statut: UserStatus.actif,
        createdAt: now,
        updatedAt: now,
      );

  group('UserSecurityRules - Contrôle des droits', () {
    test('refuse les actions admin si l\'acteur est un client ou une agence', () {
      final client = makeClient();
      final agency = makeAgency();

      expect(
        () => UserSecurityRules.ensureAdmin(client),
        throwsA(isA<UserPermissionFailure>()),
      );
      expect(
        () => UserSecurityRules.ensureAdmin(agency),
        throwsA(isA<UserPermissionFailure>()),
      );
    });
  });

  group('UserSecurityRules - Changement de statut (Activer/Désactiver/Bannir)', () {
    test('interdit à un admin de se bannir ou désactiver lui-même', () {
      final admin = makeAdmin(id: 1);

      expect(
        () => UserSecurityRules.ensureCanChangeStatus(
          actor: admin,
          target: admin,
          newStatus: UserStatus.banni,
          activeAdminCount: 2,
        ),
        throwsA(isA<UserRuleFailure>().having(
          (e) => e.message,
          'message',
          contains('votre propre compte'),
        )),
      );

      expect(
        () => UserSecurityRules.ensureCanChangeStatus(
          actor: admin,
          target: admin,
          newStatus: UserStatus.desactive,
          activeAdminCount: 2,
        ),
        throwsA(isA<UserRuleFailure>()),
      );
    });

    test('interdit de désactiver ou bannir le DERNIER admin actif', () {
      final admin1 = makeAdmin(id: 1);
      final admin2 = makeAdmin(id: 2);

      expect(
        () => UserSecurityRules.ensureCanChangeStatus(
          actor: admin1,
          target: admin2,
          newStatus: UserStatus.banni,
          activeAdminCount: 1, // 1 seul admin actif
        ),
        throwsA(isA<UserRuleFailure>().having(
          (e) => e.message,
          'message',
          contains('dernier administrateur actif'),
        )),
      );
    });

    test('autorise le changement de statut si plusieurs admins actifs existent', () {
      final admin1 = makeAdmin(id: 1);
      final targetAgency = makeAgency(id: 2);

      expect(
        () => UserSecurityRules.ensureCanChangeStatus(
          actor: admin1,
          target: targetAgency,
          newStatus: UserStatus.banni,
          activeAdminCount: 2,
        ),
        returnsNormally,
      );
    });
  });

  group('UserSecurityRules - Suppression', () {
    test('interdit à un admin de se supprimer lui-même', () {
      final admin = makeAdmin(id: 1);

      expect(
        () => UserSecurityRules.ensureCanDelete(
          actor: admin,
          target: admin,
          activeAdminCount: 2,
          vehicleCount: 0,
        ),
        throwsA(isA<UserRuleFailure>().having(
          (e) => e.message,
          'message',
          contains('votre propre compte'),
        )),
      );
    });

    test('interdit de supprimer le DERNIER admin actif', () {
      final admin1 = makeAdmin(id: 1);
      final admin2 = makeAdmin(id: 2);

      expect(
        () => UserSecurityRules.ensureCanDelete(
          actor: admin1,
          target: admin2,
          activeAdminCount: 1,
          vehicleCount: 0,
        ),
        throwsA(isA<UserRuleFailure>().having(
          (e) => e.message,
          'message',
          contains('dernier administrateur actif'),
        )),
      );
    });

    test('interdit de supprimer une agence qui possède des véhicules', () {
      final admin = makeAdmin(id: 1);
      final agencyWithVehicles = makeAgency(id: 2);

      expect(
        () => UserSecurityRules.ensureCanDelete(
          actor: admin,
          target: agencyWithVehicles,
          activeAdminCount: 2,
          vehicleCount: 3, // Possède 3 véhicules
        ),
        throwsA(isA<UserRuleFailure>().having(
          (e) => e.message,
          'message',
          contains('possède encore 3 véhicule(s)'),
        )),
      );
    });

    test('autorise la suppression d\'une agence sans véhicule', () {
      final admin = makeAdmin(id: 1);
      final agencyEmpty = makeAgency(id: 2);

      expect(
        () => UserSecurityRules.ensureCanDelete(
          actor: admin,
          target: agencyEmpty,
          activeAdminCount: 2,
          vehicleCount: 0,
        ),
        returnsNormally,
      );
    });
  });
}

