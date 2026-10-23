import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/agency.dart';
import '../../domain/enums.dart';
import '../../domain/fleet_dates.dart';
import '../../domain/fleet_vehicle.dart';
import '../../domain/vehicle_category.dart';
import '../../domain/vehicle_filter.dart';
import '../../services/demo_session.dart';
import '../../services/fleet_service.dart';
import '../details/vehicle_details_screen.dart';
import '../feedback.dart';
import '../widgets/fleet_vehicle_tile.dart';
import 'admin_widgets.dart';

/// Valide ou refuse un véhicule ; renvoie true si l'action a réussi.
/// Partagé par l'écran Validation et la fiche du véhicule.
Future<bool> reviewVehicleAction(
  BuildContext context,
  FleetVehicle vehicle, {
  required bool approve,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  String? reason;
  if (!approve) {
    reason = await askText(
      context,
      title: 'Motif du refus',
      hint: 'Ex. : photos floues, carte grise à ajouter…',
      mandatory: true,
      confirmLabel: 'Refuser',
    );
    if (reason == null) return false;
  }
  try {
    await FleetService.instance.reviewVehicle(
      vehicle.id,
      approve: approve,
      reason: reason,
      actor: DemoSession.instance.actor,
    );
    showFleetSnack(
      messenger,
      approve
          ? '${vehicle.fullName} validé : visible par les clients'
          : "${vehicle.fullName} refusé : l'agence voit le motif",
    );
    return true;
  } catch (e) {
    showFleetSnack(messenger, fleetErrorMessage(e), error: true);
    return false;
  }
}

/// Écran « Validation des véhicules » de l'administrateur.
///
/// Un véhicule ajouté par une agence n'est visible des clients qu'après
/// validation. L'admin voit la check-list (assurance, visite technique,
/// prix dans la fourchette de la catégorie) et valide ou refuse avec un
/// motif. Un véhicule refusé puis corrigé par l'agence revient ici.
class ValidationScreen extends StatefulWidget {
  const ValidationScreen({super.key});

  @override
  State<ValidationScreen> createState() => _ValidationScreenState();
}

class _ValidationScreenState extends State<ValidationScreen> {
  final FleetService _service = FleetService.instance;

  ValidationStatus _tab = ValidationStatus.enAttente;
  List<FleetVehicle> _pending = const [];
  List<FleetVehicle> _refused = const [];
  Map<String, List<String>> _problems = const {};
  Map<String, Agency> _agencies = const {};
  Map<String, VehicleCategory> _categories = const {};
  final Set<String> _busy = {};
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
    final actor = DemoSession.instance.actor;
    try {
      final pending = await _service.search(
        const VehicleFilter(validation: ValidationStatus.enAttente),
        actor,
      );
      final refused = await _service.search(
        const VehicleFilter(validation: ValidationStatus.refuse),
        actor,
      );
      final problems = <String, List<String>>{
        for (final v in [...pending, ...refused])
          v.id: await _service.validationProblems(v.id),
      };
      final agencies = await _service.agencyMap();
      final categories = await _service.categoryMap();
      if (!mounted || request != _requestId) return;
      setState(() {
        _pending = pending;
        _refused = refused;
        _problems = problems;
        _agencies = agencies;
        _categories = categories;
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

  Future<void> _review(FleetVehicle vehicle, {required bool approve}) async {
    setState(() => _busy.add(vehicle.id));
    await reviewVehicleAction(context, vehicle, approve: approve);
    if (mounted) setState(() => _busy.remove(vehicle.id));
  }

  void _openDetails(FleetVehicle vehicle) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VehicleDetailsScreen(vehicleId: vehicle.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list =
        _tab == ValidationStatus.enAttente ? _pending : _refused;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar('Validation des véhicules'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          children: [
            const Text(
              "Un véhicule ajouté par une agence n'est visible des clients "
              "qu'après votre validation. Assurance et visite technique "
              'valides et prix dans la fourchette de la catégorie sont '
              'obligatoires.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            SegmentedButton<ValidationStatus>(
              segments: [
                ButtonSegment(
                  value: ValidationStatus.enAttente,
                  icon: const Icon(Icons.hourglass_top_rounded, size: 18),
                  label: Text('En attente (${_pending.length})'),
                ),
                ButtonSegment(
                  value: ValidationStatus.refuse,
                  icon: const Icon(Icons.block_rounded, size: 18),
                  label: Text('Refusés (${_refused.length})'),
                ),
              ],
              selected: {_tab},
              showSelectedIcon: false,
              onSelectionChanged: (value) =>
                  setState(() => _tab = value.first),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              AdminBanner.error(text: _error!)
            else if (list.isEmpty)
              AdminEmptyState(
                icon: Icons.task_alt_rounded,
                title: _tab == ValidationStatus.enAttente
                    ? 'Aucun véhicule en attente'
                    : 'Aucun véhicule refusé',
                message: _tab == ValidationStatus.enAttente
                    ? 'Les véhicules ajoutés par les agences apparaîtront ici.'
                    : 'Les véhicules refusés et pas encore corrigés '
                        'apparaîtront ici.',
              )
            else
              for (final vehicle in list) ...[
                _ReviewCard(
                  vehicle: vehicle,
                  agency: _agencies[vehicle.agencyId],
                  category: _categories[vehicle.categoryId],
                  problems: _problems[vehicle.id] ?? const [],
                  busy: _busy.contains(vehicle.id),
                  onOpen: () => _openDetails(vehicle),
                  onApprove: () => _review(vehicle, approve: true),
                  onRefuse: vehicle.validation == ValidationStatus.refuse
                      ? null
                      : () => _review(vehicle, approve: false),
                ),
                const SizedBox(height: 14),
              ],
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.vehicle,
    required this.agency,
    required this.category,
    required this.problems,
    required this.busy,
    required this.onOpen,
    required this.onApprove,
    required this.onRefuse,
  });

  final FleetVehicle vehicle;
  final Agency? agency;
  final VehicleCategory? category;
  final List<String> problems;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onApprove;

  /// Null pour un véhicule déjà refusé.
  final VoidCallback? onRefuse;

  @override
  Widget build(BuildContext context) {
    final cat = category;
    final added = [
      'Ajouté le ${FleetDates.display(vehicle.createdAt)}',
      if (agency != null) 'par ${agency!.name}',
    ].join(' ');
    final price = cat == null
        ? FleetFormat.dt(vehicle.pricePerDay)
        : '${FleetFormat.dt(vehicle.pricePerDay)} / jour '
            '(${cat.name} : ${FleetFormat.dt(cat.minPricePerDay)} – '
            '${FleetFormat.dt(cat.maxPricePerDay)})';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FleetVehicleTile(
          vehicle: vehicle,
          categoryName: cat?.name,
          agencyName: agency?.name,
          showPlate: true,
          onTap: onOpen,
        ),
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$added · $price',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
              if (vehicle.rejectionReason != null) ...[
                const SizedBox(height: 8),
                AdminBanner.error(
                    text: 'Motif du refus : ${vehicle.rejectionReason}'),
              ],
              const SizedBox(height: 10),
              if (problems.isEmpty)
                const _CheckLine(
                  ok: true,
                  text: 'Assurance, visite technique et prix en règle',
                )
              else
                for (final problem in problems)
                  _CheckLine(ok: false, text: problem),
              if (vehicle.photos.isEmpty)
                const _CheckLine(
                  ok: null,
                  text: 'Aucune photo (conseillé pour les clients)',
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (onRefuse != null) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : onRefuse,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.redDark,
                          side: const BorderSide(color: AppColors.redBorder),
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Refuser'),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy || problems.isNotEmpty ? null : onApprove,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.green,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(onRefuse == null
                          ? 'Valider quand même'
                          : 'Valider'),
                    ),
                  ),
                ],
              ),
              if (problems.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  "Validation bloquée : refusez avec un motif pour que "
                  "l'agence complète le dossier.",
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Ligne de la check-list : ok (vert), problème (rouge), conseil (orange).
class _CheckLine extends StatelessWidget {
  const _CheckLine({required this.ok, required this.text});

  /// true : en règle ; false : bloquant ; null : simple conseil.
  final bool? ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (ok) {
      true => (Icons.check_circle_rounded, AppColors.green),
      false => (Icons.cancel_rounded, AppColors.redDark),
      null => (Icons.info_rounded, AppColors.orange),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: ok == true ? AppColors.textPrimary : color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
