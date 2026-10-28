import 'package:ekrili_karhba/features/users/domain/user.dart';
import 'package:ekrili_karhba/features/users/domain/user_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserValidators - Nom et Prénom', () {
    test('valide les noms corrects', () {
      expect(UserValidators.validateNom('Ben Salem'), isNull);
      expect(UserValidators.validateNom("O'Connor"), isNull);
      expect(UserValidators.validateNom('Jean-Luc'), isNull);
      expect(UserValidators.validateNom('Éléonore'), isNull);
      expect(UserValidators.validateNom('Al'), isNull); // 2 chars
    });

    test('refuse les noms vides ou trop courts/longs', () {
      expect(UserValidators.validateNom(null), isNotNull);
      expect(UserValidators.validateNom(''), isNotNull);
      expect(UserValidators.validateNom('   '), isNotNull);
      expect(UserValidators.validateNom('A'), isNotNull); // 1 char
      expect(UserValidators.validateNom('A' * 51), isNotNull); // 51 chars
    });

    test('refuse les caractères spéciaux ou chiffres dans le nom/prénom', () {
      expect(UserValidators.validateNom('Ben123'), isNotNull);
      expect(UserValidators.validateNom('Salem@Home'), isNotNull);
      expect(UserValidators.validatePrenom('Ahmed99'), isNotNull);
      expect(UserValidators.validatePrenom('Sonia!'), isNotNull);
    });
  });

  group('UserValidators - Email', () {
    test('valide les formats emails valides', () {
      expect(UserValidators.validateEmail('admin@ekrili.tn'), isNull);
      expect(UserValidators.validateEmail('user.name+tag@domain.com'), isNull);
      expect(UserValidators.validateEmail('agency_12@sub.domain.org'), isNull);
    });

    test('refuse les emails malformés ou vides', () {
      expect(UserValidators.validateEmail(null), isNotNull);
      expect(UserValidators.validateEmail(''), isNotNull);
      expect(UserValidators.validateEmail('notanemail'), isNotNull);
      expect(UserValidators.validateEmail('@domain.com'), isNotNull);
      expect(UserValidators.validateEmail('user@'), isNotNull);
      expect(UserValidators.validateEmail('user@domain'), isNotNull);
    });

    test('normalise les emails en minuscules sans espaces', () {
      expect(UserValidators.normalizeEmail('  Admin@Ekrili.TN  '), 'admin@ekrili.tn');
    });
  });

  group('UserValidators - Mot de passe', () {
    test('valide les mots de passe respectant les règles (>=8, maj, min, chiffre)', () {
      expect(UserValidators.validatePassword('Secret123'), isNull);
      expect(UserValidators.validatePassword('Password1A!'), isNull);
      expect(UserValidators.validatePassword('Tunisie2026'), isNull);
    });

    test('refuse les mots de passe trop courts ou incomplets', () {
      expect(UserValidators.validatePassword(null), isNotNull);
      expect(UserValidators.validatePassword(''), isNotNull);
      expect(UserValidators.validatePassword('Short1A'), isNotNull); // 7 chars
      expect(UserValidators.validatePassword('nouppercase123'), isNotNull);
      expect(UserValidators.validatePassword('NOLOWERCASE123'), isNotNull);
      expect(UserValidators.validatePassword('NoDigitsHereSecret'), isNotNull);
    });

    test('gère le cas facultatif lors des mises à jour', () {
      expect(UserValidators.validatePassword(null, isOptional: true), isNull);
      expect(UserValidators.validatePassword('', isOptional: true), isNull);
      expect(UserValidators.validatePassword('Invalid', isOptional: true), isNotNull);
      expect(UserValidators.validatePassword('Valid123A', isOptional: true), isNull);
    });
  });

  group('UserValidators - Téléphone tunisien', () {
    test('valide et normalise les numéros tunisiens (8 chiffres avec ou sans préfixe)', () {
      expect(UserValidators.validateTelephone('98123456'), isNull);
      expect(UserValidators.validateTelephone('20123456'), isNull);
      expect(UserValidators.validateTelephone('+21698123456'), isNull);
      expect(UserValidators.validateTelephone('00216 98 123 456'), isNull);
      expect(UserValidators.validateTelephone('+216 71 123 456'), isNull);
      expect(UserValidators.normalizePhone('+216 98 123-456'), '98123456');
    });

    test('refuse les numéros non tunisiens ou malformés', () {
      expect(UserValidators.validateTelephone(null), isNotNull);
      expect(UserValidators.validateTelephone(''), isNotNull);
      expect(UserValidators.validateTelephone('123'), isNotNull);
      expect(UserValidators.validateTelephone('981234567'), isNotNull); // 9 digits
      expect(UserValidators.validateTelephone('9812345'), isNotNull); // 7 digits
      expect(UserValidators.validateTelephone('abcdefgh'), isNotNull);
    });
  });

  group('UserValidators - Champs Agence', () {
    test('nomAgence et adresseAgence obligatoires seulement pour AGENCE', () {
      // Client
      expect(UserValidators.validateNomAgence(null, UserRole.client), isNull);
      expect(UserValidators.validateAdresseAgence(null, UserRole.client), isNull);

      // Admin
      expect(UserValidators.validateNomAgence(null, UserRole.admin), isNull);
      expect(UserValidators.validateAdresseAgence(null, UserRole.admin), isNull);

      // Agence : obligatoires
      expect(UserValidators.validateNomAgence(null, UserRole.agence), isNotNull);
      expect(UserValidators.validateNomAgence('', UserRole.agence), isNotNull);
      expect(UserValidators.validateNomAgence('A', UserRole.agence), isNotNull);
      expect(UserValidators.validateNomAgence('Ekrili Tunis Centre', UserRole.agence), isNull);

      expect(UserValidators.validateAdresseAgence(null, UserRole.agence), isNotNull);
      expect(UserValidators.validateAdresseAgence('', UserRole.agence), isNotNull);
      expect(UserValidators.validateAdresseAgence('Av. Habib Bourguiba', UserRole.agence), isNull);
    });
  });

  group('User - canLogin', () {
    final now = DateTime(2026, 10, 28);
    User buildUser(UserStatus status) => User(
          id: 1,
          nom: 'Ben Salem',
          prenom: 'Ahmed',
          email: 'ahmed@test.tn',
          motDePasse: 'hash',
          passwordSalt: 'salt',
          telephone: '98123456',
          role: UserRole.client,
          statut: status,
          createdAt: now,
          updatedAt: now,
        );

    test('autorise la connexion uniquement si ACTIF', () {
      final actif = buildUser(UserStatus.actif);
      final desactive = buildUser(UserStatus.desactive);
      final banni = buildUser(UserStatus.banni);

      expect(actif.canLogin, isTrue);
      expect(User.canLoginUser(actif), isTrue);

      expect(desactive.canLogin, isFalse);
      expect(User.canLoginUser(desactive), isFalse);

      expect(banni.canLogin, isFalse);
      expect(User.canLoginUser(banni), isFalse);
    });
  });
}

