import 'package:flutter/foundation.dart';
import '../models/maintenance_item.dart';
import '../models/vehicle.dart';
import '../models/incident_item.dart';
import 'mock_data.dart';

class MaintenanceRepository extends ChangeNotifier {
  static final MaintenanceRepository _instance = MaintenanceRepository._internal();
  factory MaintenanceRepository() => _instance;

  MaintenanceRepository._internal() {
    _vehicles = List.from(MockData.vehicles);
    _maintenances = List.from(MockData.maintenances);
    _incidents = List.from(MockData.incidents);
  }

  late List<Vehicle> _vehicles;
  late List<MaintenanceItem> _maintenances;
  late List<IncidentItem> _incidents;

  List<Vehicle> get vehicles => List.unmodifiable(_vehicles);
  List<MaintenanceItem> get maintenances => List.unmodifiable(_maintenances);
  List<IncidentItem> get incidents => List.unmodifiable(_incidents);

  // Statistics
  int get totalMaintenances => 24; // As shown in badge / mock
  int get upcomingCount => 5;
  int get overdueCount => 2;
  int get inRepairCount => 3;
  int get operationalVehicles => 21;
  int get fleetAvailabilityPercentage => 87;

  // Filtered lists
  MaintenanceItem? get urgentMaintenance {
    try {
      return _maintenances.firstWhere((m) => m.status == MaintenanceStatus.overdue);
    } catch (_) {
      return _maintenances.isNotEmpty ? _maintenances.first : null;
    }
  }

  List<MaintenanceItem> get upcomingMaintenances {
    return _maintenances.where((m) => m.status == MaintenanceStatus.upcoming).toList();
  }

  List<MaintenanceItem> get historyMaintenances {
    return _maintenances.where((m) => m.status == MaintenanceStatus.completed).toList();
  }

  MaintenanceItem? findById(String id) {
    try {
      return _maintenances.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  void addMaintenance(MaintenanceItem item) {
    _maintenances.insert(0, item);
    notifyListeners();
  }

  void updateMaintenance(MaintenanceItem updated) {
    final index = _maintenances.indexWhere((m) => m.id == updated.id);
    if (index != -1) {
      _maintenances[index] = updated;
      notifyListeners();
    }
  }

  void deleteMaintenance(String id) {
    _maintenances.removeWhere((m) => m.id == id);
    notifyListeners();
  }

  void addIncident(IncidentItem incident) {
    _incidents.insert(0, incident);
    notifyListeners();
  }

  void resolveIncident(String id) {
    final index = _incidents.indexWhere((i) => i.id == id);
    if (index != -1) {
      final current = _incidents[index];
      // Note: for immutable IncidentItem, create new with resolu status
      _incidents[index] = IncidentItem(
        id: current.id,
        title: current.title,
        vehicleModel: current.vehicleModel,
        vehiclePlate: current.vehiclePlate,
        timeAgo: 'À l\'instant',
        severity: current.severity,
        status: IncidentStatus.resolu,
        date: current.date,
        mileage: current.mileage,
        location: current.location,
        description: current.description,
        isImmobilized: false,
        assignedGarage: current.assignedGarage,
        assignedTechnician: current.assignedTechnician,
      );
      notifyListeners();
    }
  }
}
