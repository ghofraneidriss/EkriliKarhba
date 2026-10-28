import 'package:flutter/material.dart';

import '../services/fleet_service.dart';
import 'role_home_view.dart';

/// Point d'entrée du module Véhicules.
class VehiclesEntryScreen extends StatefulWidget {
  const VehiclesEntryScreen({super.key});

  @override
  State<VehiclesEntryScreen> createState() => _VehiclesEntryScreenState();
}

class _VehiclesEntryScreenState extends State<VehiclesEntryScreen> {
  @override
  void initState() {
    super.initState();
    FleetService.instance.ensureReady().ignore();
  }

  @override
  Widget build(BuildContext context) {
    return const RoleHomeView();
  }
}
