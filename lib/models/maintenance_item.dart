enum MaintenanceStatus {
  completed,
  upcoming,
  overdue,
  inProgress,
}

class MaintenanceItem {
  final String id;
  final String vehicleId;
  final String vehicleModel;
  final String vehiclePlate;
  final String vehicleCategory;
  final String type; // e.g., 'Vidange moteur', 'Remplacement pneus', 'Batterie', 'Freins'
  final String date;
  final int mileage;
  final int? targetMileage;
  final double cost;
  final String garageName;
  final String garageContact;
  final String description;
  final String nextMaintenanceDate;
  final int nextMaintenanceMileage;
  final MaintenanceStatus status;
  final List<String> photos;
  final String vehicleImage;

  const MaintenanceItem({
    required this.id,
    required this.vehicleId,
    required this.vehicleModel,
    required this.vehiclePlate,
    this.vehicleCategory = 'Berline',
    required this.type,
    required this.date,
    required this.mileage,
    this.targetMileage,
    required this.cost,
    this.garageName = 'Garage Auto Plus',
    this.garageContact = 'Rue du Lac, Tunis • +216 71 200 340',
    this.description = 'Vidange moteur et remplacement du filtre à huile. Contrôle général des niveaux et de la pression des pneus.',
    this.nextMaintenanceDate = '15 Jan 2027',
    this.nextMaintenanceMileage = 90000,
    required this.status,
    this.photos = const [],
    this.vehicleImage = '',
  });

  String get statusLabel {
    switch (status) {
      case MaintenanceStatus.completed:
        return 'Terminée';
      case MaintenanceStatus.upcoming:
        return 'À venir';
      case MaintenanceStatus.overdue:
        return 'Entretien en retard';
      case MaintenanceStatus.inProgress:
        return 'En réparation';
    }
  }

  MaintenanceItem copyWith({
    String? id,
    String? vehicleId,
    String? vehicleModel,
    String? vehiclePlate,
    String? vehicleCategory,
    String? type,
    String? date,
    int? mileage,
    int? targetMileage,
    double? cost,
    String? garageName,
    String? garageContact,
    String? description,
    String? nextMaintenanceDate,
    int? nextMaintenanceMileage,
    MaintenanceStatus? status,
    List<String>? photos,
    String? vehicleImage,
  }) {
    return MaintenanceItem(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      vehicleCategory: vehicleCategory ?? this.vehicleCategory,
      type: type ?? this.type,
      date: date ?? this.date,
      mileage: mileage ?? this.mileage,
      targetMileage: targetMileage ?? this.targetMileage,
      cost: cost ?? this.cost,
      garageName: garageName ?? this.garageName,
      garageContact: garageContact ?? this.garageContact,
      description: description ?? this.description,
      nextMaintenanceDate: nextMaintenanceDate ?? this.nextMaintenanceDate,
      nextMaintenanceMileage: nextMaintenanceMileage ?? this.nextMaintenanceMileage,
      status: status ?? this.status,
      photos: photos ?? this.photos,
      vehicleImage: vehicleImage ?? this.vehicleImage,
    );
  }
}
