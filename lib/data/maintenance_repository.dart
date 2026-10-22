import 'package:flutter/foundation.dart';
import '../models/maintenance_item.dart';
import '../models/vehicle.dart';
import '../models/incident_item.dart';
import 'mock_data.dart';
import '../databases/database_helper.dart';

class MaintenanceRepository extends ChangeNotifier {
  static final MaintenanceRepository _instance = MaintenanceRepository._internal();
  factory MaintenanceRepository() => _instance;

  MaintenanceRepository._internal() {
    _vehicles = List.from(MockData.vehicles);
    _maintenances = List.from(MockData.maintenances);
    _incidents = List.from(MockData.incidents);
    _loadSavedIncidents();
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

  Future<void> addIncident(IncidentItem incident) async {
    await DatabaseHelper.instance.insertIncident(_incidentToRow(incident));
    _incidents.insert(0, incident);
    notifyListeners();
  }

  Future<void> _loadSavedIncidents() async {
    final rows = await DatabaseHelper.instance.getIncidents();
    final saved = rows.where((row) => row['appIncidentId'] != null).map(_incidentFromRow).toList();
    if (saved.isEmpty) return;
    _incidents = [...saved, ..._incidents.where((item) => saved.every((s) => s.id != item.id))];
    notifyListeners();
  }

  Map<String, dynamic> _incidentToRow(IncidentItem item) => {
        'appIncidentId': item.id,
        'title': item.title,
        'description': item.description,
        'severity': item.severity.name,
        'status': item.status.name,
        'latitude': item.latitude,
        'longitude': item.longitude,
        'createdAt': DateTime.now().toIso8601String(),
        'vehicleModel': item.vehicleModel,
        'vehiclePlate': item.vehiclePlate,
        'timeAgo': item.timeAgo,
        'date': item.date,
        'mileage': item.mileage,
        'location': item.location,
        'isImmobilized': item.isImmobilized ? 1 : 0,
      };

  IncidentItem _incidentFromRow(Map<String, dynamic> row) => IncidentItem(
        id: row['appIncidentId'] as String,
        title: row['title'] as String,
        vehicleModel: row['vehicleModel'] as String? ?? '',
        vehiclePlate: row['vehiclePlate'] as String? ?? '',
        timeAgo: row['timeAgo'] as String? ?? '',
        severity: IncidentSeverity.values.firstWhere((v) => v.name == row['severity'], orElse: () => IncidentSeverity.faible),
        status: IncidentStatus.values.firstWhere((v) => v.name == row['status'], orElse: () => IncidentStatus.ouvert),
        date: row['date'] as String? ?? '',
        mileage: row['mileage'] as int? ?? 0,
        location: row['location'] as String? ?? '',
        description: row['description'] as String? ?? '',
        isImmobilized: row['isImmobilized'] == 1,
        latitude: (row['latitude'] as num?)?.toDouble(),
        longitude: (row['longitude'] as num?)?.toDouble(),
      );

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
        latitude: current.latitude,
        longitude: current.longitude,
      );
      notifyListeners();
    }
  }
}
