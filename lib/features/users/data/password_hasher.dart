import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Utilitaire de hachage et vérification des mots de passe avec sel aléatoire.
/// Utilise SHA-256 avec salage par utilisateur.
class PasswordHasher {
  PasswordHasher._();

  /// Génère un sel cryptographique aléatoire encodé en base64.
  static String generateSalt([int length = 16]) {
    final rand = Random.secure();
    final bytes = List<int>.generate(length, (_) => rand.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Calcule le haché SHA-256 du sel combiné au mot de passe.
  static String hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    return sha256.convert(bytes).toString();
  }

  /// Vérifie qu'un mot de passe saisi correspond au haché enregistré.
  static bool verifyPassword(String password, String salt, String expectedHash) {
    final hash = hashPassword(password, salt);
    return hash == expectedHash;
  }
}

