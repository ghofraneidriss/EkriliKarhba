class NearbyGarage {
  final String osmType;
  final String osmId;
  final String? name;
  final double latitude;
  final double longitude;
  final String? address;
  final String? phone;
  final String? website;
  final String? openingHours;
  final double distanceMetres;

  const NearbyGarage({
    required this.osmType,
    required this.osmId,
    required this.latitude,
    required this.longitude,
    required this.distanceMetres,
    this.name,
    this.address,
    this.phone,
    this.website,
    this.openingHours,
  });
}
