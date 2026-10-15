import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'maintenance/maintenance_dashboard_screen.dart';
import 'maintenance/maintenance_form_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 3; // Maintenance is 4th tab (index 3) matching screenshot

  final List<Widget> _screens = [
    const _PlaceholderScreen(title: 'Dashboard'),
    const _PlaceholderScreen(title: 'Véhicules'),
    const _PlaceholderScreen(title: 'Réservations'),
    const MaintenanceDashboardScreen(),
    const _PlaceholderScreen(title: 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 24.0, right: 8.0),
        child: SizedBox(
          width: 58,
          height: 58,
          child: FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MaintenanceFormScreen(),
                ),
              );
            },
            backgroundColor: AppColors.primaryBlue,
            elevation: 8,
            shape: const CircleBorder(),
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Dashboard',
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.directions_car_outlined,
                  activeIcon: Icons.directions_car_rounded,
                  label: 'Véhicules',
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.calendar_today_outlined,
                  activeIcon: Icons.calendar_today_rounded,
                  label: 'Réservations',
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.build_rounded,
                  activeIcon: Icons.build_rounded,
                  label: 'Maintenance',
                  isWrench: true,
                ),
                _buildNavItem(
                  index: 4,
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Profil',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    bool isWrench = false,
  }) {
    final isSelected = _currentIndex == index;

    return InkWell(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected && isWrench)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.blueSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  activeIcon,
                  size: 20,
                  color: AppColors.primaryBlue,
                ),
              )
            else
              Icon(
                isSelected ? activeIcon : icon,
                size: 22,
                color: isSelected ? AppColors.primaryBlue : AppColors.textSecondary,
              ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primaryBlue : AppColors.textSecondary,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.dashboard_customize_rounded,
                size: 56,
                color: AppColors.primaryBlue.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Module Ekrili Karhba',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
