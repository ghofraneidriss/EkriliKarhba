import 'package:flutter/material.dart';

import '../domain/enums.dart';
import '../services/demo_session.dart';
import '../services/fleet_service.dart';
import 'client/client_catalog_view.dart';
import 'profile_selector_view.dart';
import 'role_home_view.dart';

/// Point d'entrée du module, affiché dans l'onglet « Véhicules » :
/// choix du profil, puis l'espace correspondant au profil
/// (client : catalogue ; agence et admin : gestion de la flotte).
class VehiclesEntryScreen extends StatefulWidget {
  const VehiclesEntryScreen({super.key});

  @override
  State<VehiclesEntryScreen> createState() => _VehiclesEntryScreenState();
}

class _VehiclesEntryScreenState extends State<VehiclesEntryScreen> {
  @override
  void initState() {
    super.initState();
    // Prépare la base dès l'ouverture de l'app (création + démo au 1er
    // lancement), pour que l'onglet s'affiche sans attente. Une erreur
    // éventuelle est ignorée ici : l'écran de la flotte l'affichera.
    FleetService.instance.ensureReady().ignore();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DemoSession.instance,
      builder: (context, _) {
        final session = DemoSession.instance;
        final Widget child;
        if (!session.isSignedIn) {
          child = const ProfileSelectorView(key: ValueKey('selector'));
        } else if (session.role == UserRole.client) {
          child = const ClientCatalogView(key: ValueKey('client'));
        } else {
          child = RoleHomeView(
            key: ValueKey('${session.role}-${session.agency?.id}'),
          );
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: child,
        );
      },
    );
  }
}
