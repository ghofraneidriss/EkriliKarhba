/// Règles de saisie du module Véhicules, utilisables directement comme
/// `validator:` d'un TextFormField (renvoient null si la valeur est bonne).
class FleetValidators {
  FleetValidators._();

  static final RegExp _plate =
      RegExp(r'^(\d{1,3})\s*TUN\s*(\d{1,4})$', caseSensitive: false);

  static final RegExp _phone = RegExp(r'^(\+216)?\s?\d{2}\s?\d{3}\s?\d{3}$');

  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? notEmpty(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label obligatoire';
    return null;
  }

  static String? name(String? value, String label) {
    final error = notEmpty(value, label);
    if (error != null) return error;
    final length = value!.trim().length;
    if (length < 2 || length > 40) return '$label : 2 à 40 caractères';
    return null;
  }

  /// Matricule tunisien : « 123 TUN 4567 ».
  static String? registrationPlate(String? value) {
    final error = notEmpty(value, 'Matricule');
    if (error != null) return error;
    if (!_plate.hasMatch(value!.trim())) {
      return 'Format attendu : 123 TUN 4567';
    }
    return null;
  }

  /// « 234tun1987 » -> « 234 TUN 1987 ».
  static String normalizePlate(String value) {
    final match = _plate.firstMatch(value.trim());
    if (match == null) return value.trim().toUpperCase();
    return '${match.group(1)} TUN ${match.group(2)}';
  }

  static String? year(String? value) {
    final error = notEmpty(value, 'Année');
    if (error != null) return error;
    final year = int.tryParse(value!.trim());
    final max = DateTime.now().year + 1;
    if (year == null || year < 1990 || year > max) {
      return 'Année entre 1990 et $max';
    }
    return null;
  }

  static String? price(String? value, {String label = 'Prix par jour'}) {
    final error = notEmpty(value, label);
    if (error != null) return error;
    final price = double.tryParse(value!.trim().replaceAll(',', '.'));
    if (price == null || price <= 0) return '$label doit être positif';
    if (price > 5000) return '$label trop élevé (max 5000 DT)';
    return null;
  }

  static String? deposit(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final deposit = double.tryParse(value.trim().replaceAll(',', '.'));
    if (deposit == null || deposit < 0) return 'Caution invalide';
    if (deposit > 20000) return 'Caution trop élevée (max 20 000 DT)';
    return null;
  }

  static String? mileage(String? value) {
    final error = notEmpty(value, 'Kilométrage');
    if (error != null) return error;
    final km = int.tryParse(value!.trim().replaceAll(' ', ''));
    if (km == null || km < 0 || km > 1000000) {
      return 'Kilométrage entre 0 et 1 000 000';
    }
    return null;
  }

  static String? seats(String? value) =>
      _intRange(value, 'Nombre de places', 2, 9);

  static String? doors(String? value) =>
      _intRange(value, 'Nombre de portes', 2, 5);

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (!_phone.hasMatch(value.trim())) return 'Ex. : +216 71 200 340';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (!_email.hasMatch(value.trim())) return 'E-mail invalide';
    return null;
  }

  static String? _intRange(String? value, String label, int min, int max) {
    final error = notEmpty(value, label);
    if (error != null) return error;
    final n = int.tryParse(value!.trim());
    if (n == null || n < min || n > max) return '$label : $min à $max';
    return null;
  }
}
