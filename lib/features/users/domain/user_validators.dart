import 'user.dart';

/// Résultat de validation contenant les éventuelles erreurs par champ.
class ValidationResult {
  const ValidationResult([Map<String, String>? errors])
      : errors = errors ?? const {};

  final Map<String, String> errors;

  bool get isValid => errors.isEmpty;
  bool get hasErrors => errors.isNotEmpty;

  String? get(String field) => errors[field];
  bool has(String field) => errors.containsKey(field);

  @override
  String toString() {
    if (isValid) return 'ValidationResult(valide)';
    return 'ValidationResult(erreurs: $errors)';
  }
}

/// Règles de validation métier et de saisie pour les utilisateurs.
/// Ce fichier est en Dart pur (aucun import Flutter).
class UserValidators {
  UserValidators._();

  static final RegExp _nameRegExp =
      RegExp(r"^[a-zA-ZÀ-ÿ\s'-]{2,50}$");

  static final RegExp _emailRegExp =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  static final RegExp _hasUppercase = RegExp(r'[A-Z]');
  static final RegExp _hasLowercase = RegExp(r'[a-z]');
  static final RegExp _hasDigit = RegExp(r'[0-9]');

  /// Valide le nom de famille (2 à 50 caractères, lettres, tirets, espaces, apostrophes).
  static String? validateNom(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Le nom est obligatoire';
    }
    final trimmed = value.trim();
    if (trimmed.length < 2 || trimmed.length > 50) {
      return 'Le nom doit comporter entre 2 et 50 caractères';
    }
    if (!_nameRegExp.hasMatch(trimmed)) {
      return 'Le nom contient des caractères non autorisés';
    }
    return null;
  }

  /// Valide le prénom (2 à 50 caractères, lettres, tirets, espaces, apostrophes).
  static String? validatePrenom(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Le prénom est obligatoire';
    }
    final trimmed = value.trim();
    if (trimmed.length < 2 || trimmed.length > 50) {
      return 'Le prénom doit comporter entre 2 et 50 caractères';
    }
    if (!_nameRegExp.hasMatch(trimmed)) {
      return 'Le prénom contient des caractères non autorisés';
    }
    return null;
  }

  /// Valide le format de l'adresse email.
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "L'adresse email est obligatoire";
    }
    final trimmed = value.trim();
    if (!_emailRegExp.hasMatch(trimmed)) {
      return "Format d'adresse email invalide";
    }
    return null;
  }

  /// Valide la robustesse du mot de passe :
  /// min 8 caractères, 1 majuscule, 1 minuscule, 1 chiffre.
  /// Si [isOptional] est vrai (ex. modification de profil sans changer le MDP),
  /// une valeur vide ou nulle est acceptée.
  static String? validatePassword(String? value, {bool isOptional = false}) {
    if (value == null || value.isEmpty) {
      if (isOptional) return null;
      return 'Le mot de passe est obligatoire';
    }
    if (value.length < 8) {
      return 'Le mot de passe doit contenir au moins 8 caractères';
    }
    if (!_hasUppercase.hasMatch(value)) {
      return 'Le mot de passe doit contenir au moins une lettre majuscule';
    }
    if (!_hasLowercase.hasMatch(value)) {
      return 'Le mot de passe doit contenir au moins une lettre minuscule';
    }
    if (!_hasDigit.hasMatch(value)) {
      return 'Le mot de passe doit contenir au moins un chiffre';
    }
    return null;
  }

  /// Valide un numéro de téléphone tunisien :
  /// 8 chiffres, précédé optionnellement de +216 ou 00216.
  static String? validateTelephone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Le numéro de téléphone est obligatoire';
    }
    final clean = normalizePhone(value);
    if (!RegExp(r'^\d{8}$').hasMatch(clean)) {
      return 'Numéro tunisien invalide (8 chiffres attendus)';
    }
    return null;
  }

  /// Valide le nom de l'agence (obligatoire uniquement pour le rôle AGENCE).
  static String? validateNomAgence(String? value, UserRole role) {
    if (role != UserRole.agence) return null;
    if (value == null || value.trim().isEmpty) {
      return "Le nom de l'agence est obligatoire pour ce rôle";
    }
    if (value.trim().length < 2 || value.trim().length > 100) {
      return "Le nom de l'agence doit comporter entre 2 et 100 caractères";
    }
    return null;
  }

  /// Valide l'adresse de l'agence (obligatoire uniquement pour le rôle AGENCE).
  static String? validateAdresseAgence(String? value, UserRole role) {
    if (role != UserRole.agence) return null;
    if (value == null || value.trim().isEmpty) {
      return "L'adresse de l'agence est obligatoire pour ce rôle";
    }
    if (value.trim().length < 3 || value.trim().length > 255) {
      return "L'adresse de l'agence doit comporter entre 3 et 255 caractères";
    }
    return null;
  }

  /// Normalise un numéro tunisien pour ne garder que les 8 chiffres locaux.
  static String normalizePhone(String value) {
    var digits = value.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
    if (digits.startsWith('+216')) {
      digits = digits.substring(4);
    } else if (digits.startsWith('00216')) {
      digits = digits.substring(5);
    } else if (digits.startsWith('216') && digits.length == 11) {
      digits = digits.substring(3);
    }
    return digits;
  }

  /// Normalise une adresse email.
  static String normalizeEmail(String value) => value.trim().toLowerCase();

  /// Validation globale pour la création d'un utilisateur.
  static ValidationResult validateCreate({
    required String nom,
    required String prenom,
    required String email,
    required String motDePasse,
    required String telephone,
    required UserRole role,
    String? nomAgence,
    String? adresseAgence,
  }) {
    final errors = <String, String>{};

    final nomErr = validateNom(nom);
    if (nomErr != null) errors['nom'] = nomErr;

    final prenomErr = validatePrenom(prenom);
    if (prenomErr != null) errors['prenom'] = prenomErr;

    final emailErr = validateEmail(email);
    if (emailErr != null) errors['email'] = emailErr;

    final pwdErr = validatePassword(motDePasse);
    if (pwdErr != null) errors['motDePasse'] = pwdErr;

    final telErr = validateTelephone(telephone);
    if (telErr != null) errors['telephone'] = telErr;

    final agencyNameErr = validateNomAgence(nomAgence, role);
    if (agencyNameErr != null) errors['nomAgence'] = agencyNameErr;

    final agencyAddrErr = validateAdresseAgence(adresseAgence, role);
    if (agencyAddrErr != null) errors['adresseAgence'] = agencyAddrErr;

    return ValidationResult(errors);
  }

  /// Validation globale pour la mise à jour d'un utilisateur par l'admin.
  static ValidationResult validateUpdate({
    required String nom,
    required String prenom,
    required String email,
    required String telephone,
    required UserRole role,
    String? motDePasse, // facultatif lors de la mise à jour
    String? nomAgence,
    String? adresseAgence,
  }) {
    final errors = <String, String>{};

    final nomErr = validateNom(nom);
    if (nomErr != null) errors['nom'] = nomErr;

    final prenomErr = validatePrenom(prenom);
    if (prenomErr != null) errors['prenom'] = prenomErr;

    final emailErr = validateEmail(email);
    if (emailErr != null) errors['email'] = emailErr;

    if (motDePasse != null && motDePasse.isNotEmpty) {
      final pwdErr = validatePassword(motDePasse);
      if (pwdErr != null) errors['motDePasse'] = pwdErr;
    }

    final telErr = validateTelephone(telephone);
    if (telErr != null) errors['telephone'] = telErr;

    final agencyNameErr = validateNomAgence(nomAgence, role);
    if (agencyNameErr != null) errors['nomAgence'] = agencyNameErr;

    final agencyAddrErr = validateAdresseAgence(adresseAgence, role);
    if (agencyAddrErr != null) errors['adresseAgence'] = agencyAddrErr;

    return ValidationResult(errors);
  }

  /// Validation lors de la mise à jour de son propre profil
  /// (l'utilisateur peut modifier nom, prenom, email, telephone, et éventuellement mot de passe).
  static ValidationResult validateProfileUpdate({
    required String nom,
    required String prenom,
    required String telephone,
    String? email,
    String? nouveauMotDePasse,
    String? nomAgence,
    String? adresseAgence,
    required UserRole role,
  }) {
    final errors = <String, String>{};

    final nomErr = validateNom(nom);
    if (nomErr != null) errors['nom'] = nomErr;

    final prenomErr = validatePrenom(prenom);
    if (prenomErr != null) errors['prenom'] = prenomErr;

    if (email != null) {
      final emailErr = validateEmail(email);
      if (emailErr != null) errors['email'] = emailErr;
    }

    final telErr = validateTelephone(telephone);
    if (telErr != null) errors['telephone'] = telErr;

    if (nouveauMotDePasse != null && nouveauMotDePasse.isNotEmpty) {
      final pwdErr = validatePassword(nouveauMotDePasse);
      if (pwdErr != null) errors['nouveauMotDePasse'] = pwdErr;
    }

    if (role == UserRole.agence) {
      final agencyNameErr = validateNomAgence(nomAgence, role);
      if (agencyNameErr != null) errors['nomAgence'] = agencyNameErr;

      final agencyAddrErr = validateAdresseAgence(adresseAgence, role);
      if (agencyAddrErr != null) errors['adresseAgence'] = agencyAddrErr;
    }

    return ValidationResult(errors);
  }
}

