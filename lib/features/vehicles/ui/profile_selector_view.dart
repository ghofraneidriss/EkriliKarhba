import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/agency.dart';
import '../domain/enums.dart';
import '../services/demo_session.dart';
import '../services/fleet_service.dart';

/// Choix du profil (Client, Agence, Administrateur) avant d'entrer dans
/// la gestion des véhicules. Équivalent de l'« Accès démonstration » de
/// la maquette Figma, en attendant le vrai login du module Utilisateurs.
class ProfileSelectorView extends StatelessWidget {
  const ProfileSelectorView({super.key});

  Future<void> _choose(BuildContext context, UserRole role) async {
    if (role != UserRole.agence) {
      DemoSession.instance.signInAs(role);
      return;
    }
    final agency = await showModalBottomSheet<Agency>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => const _AgencyPickerSheet(),
    );
    if (agency != null) {
      DemoSession.instance.signInAs(UserRole.agence, agency: agency);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
          children: [
            const _Hero(),
            const SizedBox(height: 26),
            const Text(
              'Choisissez votre profil',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Chaque profil voit et gère la flotte différemment.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            for (final role in UserRole.values) ...[
              _RoleCard(role: role, onTap: () => _choose(context, role)),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.blueLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 18, color: AppColors.primaryBlue),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Accès démonstration : la connexion réelle sera fournie '
                      'par le module Gestion des utilisateurs.',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.headerNavyStart, AppColors.headerNavyEnd],
        ),
        boxShadow: const [AppColors.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.directions_car_filled_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(height: 18),
          const Text(
            'GESTION DES VÉHICULES',
            style: TextStyle(
              color: AppColors.textFleetLabel,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ekrili Karhba',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Votre voiture, votre liberté.',
            style: TextStyle(color: AppColors.textFleetSub, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.onTap});

  final UserRole role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (Color accent, Color soft) = switch (role) {
      UserRole.client => (AppColors.primaryBlue, AppColors.blueLight),
      UserRole.agence => (AppColors.greenDark, AppColors.greenLight),
      UserRole.admin => (AppColors.primaryNavy, AppColors.sectionBg),
    };
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cardBorderSubtle),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: soft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(role.icon, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.label,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      role.description,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgencyPickerSheet extends StatelessWidget {
  const _AgencyPickerSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<Agency>>(
        future: FleetService.instance.agencies(activeOnly: true),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Erreur : ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final agencies = snapshot.data!;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'Quelle agence ?',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              for (final agency in agencies)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.darkBlueCard,
                    child: Text(
                      agency.initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  title: Text(
                    agency.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(agency.city),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).pop(agency),
                ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}
