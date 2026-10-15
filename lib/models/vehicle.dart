class Vehicle {
  final String id;
  final String brandAndModel;
  final String registrationPlate;
  final String category;
  final int year;
  final int currentMileage;
  final String status; // 'Disponible', 'En réparation', 'En maintenance'
  final String imageAsset;

  const Vehicle({
    required this.id,
    required this.brandAndModel,
    required this.registrationPlate,
    required this.category,
    required this.year,
    required this.currentMileage,
    required this.status,
    required this.imageAsset,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'brandAndModel': brandAndModel,
      'registrationPlate': registrationPlate,
      'category': category,
      'year': year,
      'currentMileage': currentMileage,
      'status': status,
      'imageAsset': imageAsset,
    };
  }

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      id: map['id'] ?? '',
      brandAndModel: map['brandAndModel'] ?? '',
      registrationPlate: map['registrationPlate'] ?? '',
      category: map['category'] ?? '',
      year: map['year']?.toInt() ?? 2024,
      currentMileage: map['currentMileage']?.toInt() ?? 0,
      status: map['status'] ?? 'Disponible',
      imageAsset: map['imageAsset'] ?? '',
    );
  }
}
