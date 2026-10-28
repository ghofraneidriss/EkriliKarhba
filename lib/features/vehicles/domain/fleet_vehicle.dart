import 'dart:convert';

import 'enums.dart';

/// Véhicule de la flotte (module Gestion des véhicules).
///
/// Ce modèle est indépendant du modèle `Vehicle` du module Maintenance,
/// qui n'est pas modifié ; VehicleApi fournit la conversion.
class FleetVehicle {
  const FleetVehicle({
    required this.id,
    required this.agencyId,
    required this.categoryId,
    required this.brand,
    required this.model,
    required this.year,
    required this.registrationPlate,
    this.color = '',
    this.fuel = FuelType.essence,
    this.transmission = Transmission.manuelle,
    this.seats = 5,
    this.doors = 5,
    this.mileage = 0,
    required this.pricePerDay,
    this.deposit = 0,
    this.status = VehicleStatus.disponible,
    this.validation = ValidationStatus.enAttente,
    this.rejectionReason,
    this.description = '',
    this.photos = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final int agencyId;
  final String categoryId;
  final String brand;
  final String model;
  final int year;

  /// Matricule tunisien normalisé, ex. « 234 TUN 1987 ».
  final String registrationPlate;
  final String color;
  final FuelType fuel;
  final Transmission transmission;
  final int seats;
  final int doors;

  /// Kilométrage actuel (ne peut que croître).
  final int mileage;

  /// Prix de location par jour en DT. Le calcul du coût total d'une
  /// location appartient au module Réservations.
  final double pricePerDay;

  /// Caution en DT.
  final double deposit;
  final VehicleStatus status;
  final ValidationStatus validation;
  final String? rejectionReason;
  final String description;

  /// Chemins des photos (assets locaux ou fichiers de l'appareil).
  final List<String> photos;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get fullName => '$brand $model';

  /// Première photo ou null.
  String? get mainPhoto => photos.isEmpty ? null : photos.first;

  /// Un client peut-il voir ce véhicule dans le catalogue public ?
  /// (doit être validé, non archivé, et ni hors service ni en maintenance).
  bool get isListedForClients {
    if (validation != ValidationStatus.valide) return false;
    return status != VehicleStatus.archive &&
        status != VehicleStatus.horsService &&
        status != VehicleStatus.maintenance;
  }

  /// Peut-on louer ce véhicule dès maintenant ?
  bool get isAvailableNow =>
      isListedForClients && status == VehicleStatus.disponible;

  FleetVehicle copyWith({
    String? id,
    int? agencyId,
    String? categoryId,
    String? brand,
    String? model,
    int? year,
    String? registrationPlate,
    String? color,
    FuelType? fuel,
    Transmission? transmission,
    int? seats,
    int? doors,
    int? mileage,
    double? pricePerDay,
    double? deposit,
    VehicleStatus? status,
    ValidationStatus? validation,
    String? rejectionReason,
    bool clearRejectionReason = false,
    String? description,
    List<String>? photos,
    DateTime? updatedAt,
  }) {
    return FleetVehicle(
      id: id ?? this.id,
      agencyId: agencyId ?? this.agencyId,
      categoryId: categoryId ?? this.categoryId,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      registrationPlate: registrationPlate ?? this.registrationPlate,
      color: color ?? this.color,
      fuel: fuel ?? this.fuel,
      transmission: transmission ?? this.transmission,
      seats: seats ?? this.seats,
      doors: doors ?? this.doors,
      mileage: mileage ?? this.mileage,
      pricePerDay: pricePerDay ?? this.pricePerDay,
      deposit: deposit ?? this.deposit,
      status: status ?? this.status,
      validation: validation ?? this.validation,
      rejectionReason: clearRejectionReason
          ? null
          : (rejectionReason ?? this.rejectionReason),
      description: description ?? this.description,
      photos: photos ?? this.photos,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'agency_id': agencyId,
        'category_id': categoryId,
        'brand': brand,
        'model': model,
        'year': year,
        'registration_plate': registrationPlate,
        'color': color,
        'fuel': fuel.name,
        'transmission': transmission.name,
        'seats': seats,
        'doors': doors,
        'mileage': mileage,
        'price_per_day': pricePerDay,
        'deposit': deposit,
        'status': status.name,
        'validation': validation.name,
        'rejection_reason': rejectionReason,
        'description': description,
        'photos': jsonEncode(photos),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory FleetVehicle.fromMap(Map<String, Object?> map) {
    final rawPhotos = map['photos'] as String?;
    final photos = (rawPhotos == null || rawPhotos.isEmpty)
        ? const <String>[]
        : (jsonDecode(rawPhotos) as List<dynamic>).cast<String>();
    return FleetVehicle(
      id: map['id'] as String,
      agencyId: map['agency_id'] is int
          ? map['agency_id'] as int
          : int.parse(map['agency_id'].toString()),
      categoryId: map['category_id'] as String,
      brand: map['brand'] as String,
      model: map['model'] as String,
      year: map['year'] as int,
      registrationPlate: map['registration_plate'] as String,
      color: (map['color'] as String?) ?? '',
      fuel: FuelType.fromName(map['fuel'] as String?),
      transmission: Transmission.fromName(map['transmission'] as String?),
      seats: map['seats'] as int? ?? 5,
      doors: map['doors'] as int? ?? 5,
      mileage: map['mileage'] as int? ?? 0,
      pricePerDay: (map['price_per_day'] as num).toDouble(),
      deposit: (map['deposit'] as num? ?? 0).toDouble(),
      status: VehicleStatus.fromName(map['status'] as String?),
      validation: ValidationStatus.fromName(map['validation'] as String?),
      rejectionReason: map['rejection_reason'] as String?,
      description: (map['description'] as String?) ?? '',
      photos: photos,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
