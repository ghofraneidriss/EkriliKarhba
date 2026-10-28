import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/actor.dart';
import '../../domain/fleet_dates.dart';
import '../../domain/vehicle_category.dart';
import '../../services/fleet_service.dart';
import '../feedback.dart';
import 'admin_widgets.dart';
import 'category_form_sheet.dart';

/// Gestion des catégories par l'administrateur.
///
/// Règles : nom unique ; la fourchette de prix ne peut pas exclure un
/// véhicule existant ; une catégorie utilisée ne se supprime pas (on la
/// désactive : elle n'accepte plus de nouveaux véhicules).
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final FleetService _service = FleetService.instance;

  List<VehicleCategory> _categories = const [];
  Map<String, int> _counts = const {};
  bool _loading = true;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _service.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _service.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_requestId;
    try {
      final categories = await _service.categories();
      final counts = await _service.vehicleCountByCategory();
      if (!mounted || request != _requestId) return;
      setState(() {
        _categories = categories;
        _counts = counts;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || request != _requestId) return;
      setState(() {
        _loading = false;
        _error = fleetErrorMessage(e);
      });
    }
  }

  Future<void> _openForm([VehicleCategory? category]) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showCategoryFormSheet(
      context,
      category: category,
      vehicleCount: category == null ? 0 : (_counts[category.id] ?? 0),
    );
    if (saved != null) {
      showFleetSnack(
        messenger,
        category == null
            ? 'Catégorie ${saved.name} ajoutée'
            : 'Catégorie enregistrée',
      );
    }
  }

  Future<void> _setActive(VehicleCategory category, bool active) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.updateCategory(
        category.copyWith(isActive: active),
        const Actor.admin(),
      );
      showFleetSnack(
        messenger,
        active
            ? '${category.name} accepte de nouveau des véhicules'
            : "${category.name} désactivée : plus d'ajout dans cette catégorie",
      );
    } catch (e) {
      showFleetSnack(messenger, fleetErrorMessage(e), error: true);
    }
  }

  Future<void> _delete(VehicleCategory category) async {
    final count = _counts[category.id] ?? 0;
    final messenger = ScaffoldMessenger.of(context);
    if (count > 0) {
      showFleetSnack(
        messenger,
        'Catégorie utilisée par $count véhicule(s) : désactivez-la plutôt.',
        error: true,
      );
      return;
    }
    final ok = await confirmAction(
      context,
      title: 'Supprimer la catégorie ?',
      message: '« ${category.name} » sera supprimée définitivement.',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await _service.deleteCategory(category.id, const Actor.admin());
      showFleetSnack(messenger, 'Catégorie ${category.name} supprimée');
    } catch (e) {
      showFleetSnack(messenger, fleetErrorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar('Catégories'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          children: [
            const Text(
              'Chaque catégorie fixe la fourchette du prix par jour de ses '
              'véhicules.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            AdminPrimaryButton(
              label: 'Ajouter une catégorie',
              icon: Icons.add_rounded,
              onPressed: () => _openForm(),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              AdminBanner.error(text: _error!)
            else if (_categories.isEmpty)
              const AdminEmptyState(
                icon: Icons.category_outlined,
                title: 'Aucune catégorie',
                message: 'Ajoutez une catégorie pour classer les véhicules.',
              )
            else
              for (final category in _categories) ...[
                _CategoryCard(
                  category: category,
                  vehicleCount: _counts[category.id] ?? 0,
                  onTap: () => _openForm(category),
                  onActiveChanged: (value) => _setActive(category, value),
                  onDelete: () => _delete(category),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.vehicleCount,
    required this.onTap,
    required this.onActiveChanged,
    required this.onDelete,
  });

  final VehicleCategory category;
  final int vehicleCount;
  final VoidCallback onTap;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: category.isActive ? 1 : 0.7,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.blueLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.category_outlined,
                      color: AppColors.primaryBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (category.description.isNotEmpty)
                        Text(
                          category.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          AdminPill(
                            '${FleetFormat.dt(category.minPricePerDay)} – '
                            '${FleetFormat.dt(category.maxPricePerDay)} / jour',
                            color: AppColors.primaryNavy,
                            background: AppColors.blueSoft,
                          ),
                          AdminPill(
                            '$vehicleCount véhicule(s)',
                            icon: Icons.directions_car_outlined,
                          ),
                          if (!category.isActive)
                            const AdminPill(
                              'Désactivée',
                              color: AppColors.redDark,
                              background: AppColors.redLight,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Switch(
                      value: category.isActive,
                      activeTrackColor: AppColors.green,
                      onChanged: onActiveChanged,
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Actions',
                      icon: const Icon(Icons.more_vert_rounded,
                          color: AppColors.textSecondary),
                      onSelected: (action) {
                        if (action == 'edit') {
                          onTap();
                        } else {
                          onDelete();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Modifier')),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Supprimer',
                              style: TextStyle(color: AppColors.red)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
