/// Agence de location propriétaire d'une partie de la flotte.
///
/// Le compte de connexion de l'agence relève du module Utilisateurs ;
/// ici on gère sa fiche métier (nom, ville, contact, activité).
class Agency {
  const Agency({
    required this.id,
    required this.name,
    required this.city,
    this.address = '',
    this.phone = '',
    this.email = '',
    this.isActive = true,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String city;
  final String address;
  final String phone;
  final String email;

  /// Une agence désactivée n'apparaît plus côté client,
  /// ses véhicules non plus.
  final bool isActive;
  final DateTime createdAt;

  /// Initiales pour l'avatar (ex. « Auto Mobility Tunis » -> « AM »).
  String get initials {
    final words =
        name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first[0].toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  Agency copyWith({
    String? name,
    String? city,
    String? address,
    String? phone,
    String? email,
    bool? isActive,
  }) {
    return Agency(
      id: id,
      name: name ?? this.name,
      city: city ?? this.city,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'city': city,
        'address': address,
        'phone': phone,
        'email': email,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory Agency.fromMap(Map<String, Object?> map) => Agency(
        id: map['id'] as String,
        name: map['name'] as String,
        city: map['city'] as String,
        address: (map['address'] as String?) ?? '',
        phone: (map['phone'] as String?) ?? '',
        email: (map['email'] as String?) ?? '',
        isActive: (map['is_active'] as int? ?? 1) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
