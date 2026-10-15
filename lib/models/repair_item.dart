class RepairPart {
  final String name;
  final int quantity;
  final double unitPrice;

  const RepairPart({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  double get total => quantity * unitPrice;
}

class RepairDetails {
  final String id;
  final String incidentId;
  final String vehicleModel;
  final String garageName;
  final String technicianName;
  final String startDate;
  final String? endDate;
  final String status;
  final String workPerformed;
  final List<RepairPart> parts;
  final double laborCost;

  const RepairDetails({
    required this.id,
    required this.incidentId,
    required this.vehicleModel,
    required this.garageName,
    required this.technicianName,
    required this.startDate,
    this.endDate,
    required this.status,
    required this.workPerformed,
    required this.parts,
    required this.laborCost,
  });

  double get partsCost => parts.fold(0.0, (acc, item) => acc + item.total);
  double get totalCost => laborCost + partsCost;
}
