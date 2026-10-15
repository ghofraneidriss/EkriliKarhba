enum IncidentSeverity {
  critique,
  elevee,
  moyenne,
  faible,
}

enum IncidentStatus {
  ouvert,
  enReparation,
  resolu,
}

class IncidentItem {
  final String id;
  final String title;
  final String vehicleModel;
  final String vehiclePlate;
  final String timeAgo;
  final IncidentSeverity severity;
  final IncidentStatus status;
  final String date;
  final int mileage;
  final String location;
  final String description;
  final bool isImmobilized;
  final String? assignedGarage;
  final String? assignedTechnician;

  const IncidentItem({
    required this.id,
    required this.title,
    required this.vehicleModel,
    required this.vehiclePlate,
    required this.timeAgo,
    required this.severity,
    required this.status,
    required this.date,
    required this.mileage,
    required this.location,
    required this.description,
    this.isImmobilized = false,
    this.assignedGarage,
    this.assignedTechnician,
  });

  String get severityLabel {
    switch (severity) {
      case IncidentSeverity.critique:
        return 'Critique';
      case IncidentSeverity.elevee:
        return 'Élevée';
      case IncidentSeverity.moyenne:
        return 'Moyenne';
      case IncidentSeverity.faible:
        return 'Faible';
    }
  }

  String get statusLabel {
    switch (status) {
      case IncidentStatus.ouvert:
        return 'Ouvert';
      case IncidentStatus.enReparation:
        return 'En réparation';
      case IncidentStatus.resolu:
        return 'Résolu';
    }
  }
}
