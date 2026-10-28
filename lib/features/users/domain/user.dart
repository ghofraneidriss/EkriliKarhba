/// Entités et enums du domaine Utilisateurs.
/// Ce fichier est en Dart pur (aucun import Flutter).
library;

enum UserRole {
  admin('ADMIN', 'Administrateur'),
  agence('AGENCE', 'Agence de location'),
  client('CLIENT', 'Client');

  const UserRole(this.code, this.label);

  final String code;
  final String label;

  static UserRole fromCode(String code) {
    return switch (code.toUpperCase().trim()) {
      'ADMIN' => UserRole.admin,
      'AGENCE' => UserRole.agence,
      'CLIENT' => UserRole.client,
      _ => throw ArgumentError('Rôle utilisateur inconnu: $code'),
    };
  }
}

enum UserStatus {
  actif('ACTIF', 'Actif'),
  desactive('DESACTIVE', 'Désactivé'),
  banni('BANNI', 'Banni');

  const UserStatus(this.code, this.label);

  final String code;
  final String label;

  static UserStatus fromCode(String code) {
    return switch (code.toUpperCase().trim()) {
      'ACTIF' => UserStatus.actif,
      'DESACTIVE' => UserStatus.desactive,
      'BANNI' => UserStatus.banni,
      _ => throw ArgumentError('Statut utilisateur inconnu: $code'),
    };
  }
}

class User {
  const User({
    this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.motDePasse,
    required this.passwordSalt,
    required this.telephone,
    required this.role,
    this.statut = UserStatus.actif,
    required this.createdAt,
    required this.updatedAt,
    this.niveauAcces,
    this.nomAgence,
    this.adresseAgence,
  });

  final int? id;
  final String nom;
  final String prenom;
  final String email;

  /// Mot de passe hashé (salé), jamais en clair.
  final String motDePasse;
  final String passwordSalt;
  final String telephone;
  final UserRole role;
  final UserStatus statut;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Champ optionnel pour ADMIN (ex. Super Admin, Support...)
  final String? niveauAcces;

  /// Champs obligatoires pour AGENCE
  final String? nomAgence;
  final String? adresseAgence;

  String get fullName => '$prenom $nom'.trim();

  String get displayName {
    if (isAgence && nomAgence != null && nomAgence!.trim().isNotEmpty) {
      return nomAgence!.trim();
    }
    return fullName;
  }

  bool get isAdmin => role == UserRole.admin;
  bool get isAgence => role == UserRole.agence;
  bool get isClient => role == UserRole.client;

  bool get isActif => statut == UserStatus.actif;
  bool get isDesactive => statut == UserStatus.desactive;
  bool get isBanni => statut == UserStatus.banni;

  /// Règle métier : un compte désactivé ou banni ne peut pas se connecter.
  bool get canLogin => statut == UserStatus.actif;

  static bool canLoginUser(User user) => user.canLogin;

  User copyWith({
    int? id,
    String? nom,
    String? prenom,
    String? email,
    String? motDePasse,
    String? passwordSalt,
    String? telephone,
    UserRole? role,
    UserStatus? statut,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? niveauAcces,
    String? nomAgence,
    String? adresseAgence,
  }) {
    return User(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      email: email ?? this.email,
      motDePasse: motDePasse ?? this.motDePasse,
      passwordSalt: passwordSalt ?? this.passwordSalt,
      telephone: telephone ?? this.telephone,
      role: role ?? this.role,
      statut: statut ?? this.statut,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      niveauAcces: niveauAcces ?? this.niveauAcces,
      nomAgence: nomAgence ?? this.nomAgence,
      adresseAgence: adresseAgence ?? this.adresseAgence,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nom': nom,
      'prenom': prenom,
      'email': email.trim().toLowerCase(),
      'mot_de_passe': motDePasse,
      'password_salt': passwordSalt,
      'telephone': telephone,
      'role': role.code,
      'statut': statut.code,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'niveau_acces': niveauAcces,
      'nom_agence': nomAgence,
      'adresse_agence': adresseAgence,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?,
      nom: (map['nom'] as String?) ?? '',
      prenom: (map['prenom'] as String?) ?? '',
      email: ((map['email'] as String?) ?? '').trim().toLowerCase(),
      motDePasse: (map['mot_de_passe'] as String?) ?? '',
      passwordSalt: (map['password_salt'] as String?) ?? '',
      telephone: (map['telephone'] as String?) ?? '',
      role: UserRole.fromCode(map['role'] as String),
      statut: UserStatus.fromCode(map['statut'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      niveauAcces: map['niveau_acces'] as String?,
      nomAgence: map['nom_agence'] as String?,
      adresseAgence: map['adresse_agence'] as String?,
    );
  }
}

