import 'enums.dart';

/// Critères de recherche dans la flotte. Tous les critères sont facultatifs.
class VehicleFilter {
  const VehicleFilter({
    this.query = '',
    this.statuses = const {},
    this.categoryId,
    this.agencyId,
    this.city,
    this.fuel,
    this.transmission,
    this.minPrice,
    this.maxPrice,
    this.minSeats,
    this.availableFrom,
    this.availableTo,
    this.validation,
    this.sort = VehicleSort.plusRecents,
  });

  /// Recherche libre sur marque, modèle et matricule.
  final String query;
  final Set<VehicleStatus> statuses;
  final String? categoryId;
  final int? agencyId;
  final String? city;
  final FuelType? fuel;
  final Transmission? transmission;
  final double? minPrice;
  final double? maxPrice;
  final int? minSeats;

  /// Si renseignées : seulement les véhicules libres sur toute la période.
  final DateTime? availableFrom;
  final DateTime? availableTo;
  final ValidationStatus? validation;
  final VehicleSort sort;

  bool get hasDateRange => availableFrom != null && availableTo != null;

  /// Nombre de critères actifs (hors recherche texte et tri), pour la
  /// pastille du bouton Filtres.
  int get activeCount {
    var count = 0;
    if (statuses.isNotEmpty) count++;
    if (categoryId != null) count++;
    if (agencyId != null) count++;
    if (city != null) count++;
    if (fuel != null) count++;
    if (transmission != null) count++;
    if (minPrice != null || maxPrice != null) count++;
    if (minSeats != null) count++;
    if (hasDateRange) count++;
    if (validation != null) count++;
    return count;
  }

  VehicleFilter copyWith({
    String? query,
    Set<VehicleStatus>? statuses,
    String? categoryId,
    int? agencyId,
    String? city,
    FuelType? fuel,
    Transmission? transmission,
    double? minPrice,
    double? maxPrice,
    int? minSeats,
    DateTime? availableFrom,
    DateTime? availableTo,
    ValidationStatus? validation,
    VehicleSort? sort,
    bool clearCategory = false,
    bool clearAgency = false,
    bool clearCity = false,
    bool clearFuel = false,
    bool clearTransmission = false,
    bool clearPrices = false,
    bool clearSeats = false,
    bool clearDates = false,
    bool clearValidation = false,
  }) {
    return VehicleFilter(
      query: query ?? this.query,
      statuses: statuses ?? this.statuses,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      agencyId: clearAgency ? null : (agencyId ?? this.agencyId),
      city: clearCity ? null : (city ?? this.city),
      fuel: clearFuel ? null : (fuel ?? this.fuel),
      transmission:
          clearTransmission ? null : (transmission ?? this.transmission),
      minPrice: clearPrices ? null : (minPrice ?? this.minPrice),
      maxPrice: clearPrices ? null : (maxPrice ?? this.maxPrice),
      minSeats: clearSeats ? null : (minSeats ?? this.minSeats),
      availableFrom: clearDates ? null : (availableFrom ?? this.availableFrom),
      availableTo: clearDates ? null : (availableTo ?? this.availableTo),
      validation: clearValidation ? null : (validation ?? this.validation),
      sort: sort ?? this.sort,
    );
  }
}

/// Chiffres de la flotte pour les tableaux de bord agence et admin.
class FleetStats {
  const FleetStats({
    required this.total,
    required this.byStatus,
    required this.byCategory,
    required this.byAgency,
    required this.pendingValidation,
    required this.averagePricePerDay,
    required this.documentsExpiringSoon,
    required this.documentsExpired,
  });

  /// Véhicules non archivés.
  final int total;
  final Map<VehicleStatus, int> byStatus;

  /// Nom de catégorie -> nombre de véhicules.
  final Map<String, int> byCategory;

  /// Nom d'agence -> nombre de véhicules.
  final Map<String, int> byAgency;
  final int pendingValidation;
  final double averagePricePerDay;
  final int documentsExpiringSoon;
  final int documentsExpired;

  int count(VehicleStatus status) => byStatus[status] ?? 0;

  /// Véhicules occupés (réservation ou location en cours).
  int get occupied =>
      VehicleStatus.occupiedStatuses.fold(0, (sum, s) => sum + count(s));

  /// Part des véhicules disponibles, en pourcentage (0-100).
  int get availabilityRate =>
      total == 0 ? 0 : (count(VehicleStatus.disponible) * 100 / total).round();

  /// Part des véhicules occupés, en pourcentage (0-100).
  int get occupancyRate =>
      total == 0 ? 0 : (occupied * 100 / total).round();
}
