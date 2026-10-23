/// Catégorie de véhicule gérée par l'administrateur
/// (Économique, Citadine, Berline, SUV, Luxe, Utilitaire…).
///
/// La fourchette de prix encadre le prix par jour des véhicules
/// de la catégorie : un véhicule hors fourchette est refusé.
class VehicleCategory {
  const VehicleCategory({
    required this.id,
    required this.name,
    this.description = '',
    required this.minPricePerDay,
    required this.maxPricePerDay,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String description;
  final double minPricePerDay;
  final double maxPricePerDay;

  /// Une catégorie inactive ne peut plus recevoir de nouveaux véhicules.
  final bool isActive;

  bool acceptsPrice(double pricePerDay) =>
      pricePerDay >= minPricePerDay && pricePerDay <= maxPricePerDay;

  VehicleCategory copyWith({
    String? name,
    String? description,
    double? minPricePerDay,
    double? maxPricePerDay,
    bool? isActive,
  }) {
    return VehicleCategory(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      minPricePerDay: minPricePerDay ?? this.minPricePerDay,
      maxPricePerDay: maxPricePerDay ?? this.maxPricePerDay,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'min_price': minPricePerDay,
        'max_price': maxPricePerDay,
        'is_active': isActive ? 1 : 0,
      };

  factory VehicleCategory.fromMap(Map<String, Object?> map) => VehicleCategory(
        id: map['id'] as String,
        name: map['name'] as String,
        description: (map['description'] as String?) ?? '',
        minPricePerDay: (map['min_price'] as num).toDouble(),
        maxPricePerDay: (map['max_price'] as num).toDouble(),
        isActive: (map['is_active'] as int? ?? 1) == 1,
      );
}
