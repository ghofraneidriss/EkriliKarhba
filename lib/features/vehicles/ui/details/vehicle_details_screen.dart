import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/actor.dart';
import '../../../users/domain/user.dart';
import '../../domain/enums.dart';
import '../../domain/fleet_dates.dart';
import '../../domain/fleet_vehicle.dart';
import '../../domain/history_entry.dart';
import '../../domain/unavailability_period.dart';
import '../../domain/vehicle_category.dart';
import '../../domain/vehicle_document.dart';
import '../../services/fleet_service.dart';
import '../admin/validation_screen.dart';
import '../feedback.dart';
import '../manage/document_sheet.dart';
import '../manage/status_sheet.dart';
import '../manage/transfer_sheet.dart';
import '../manage/unavailability_sheet.dart';
import '../manage/vehicle_form_screen.dart';
import '../widgets/availability_calendar.dart';
import '../widgets/status_chip.dart';
import '../widgets/vehicle_photo.dart';

/// Fiche détaillée d'un véhicule, mise à jour en direct : dès qu'une
/// agence ou l'administrateur modifie le véhicule (prix, statut, dates,
/// photos…), l'écran se rafraîchit tout seul.
///
/// Le client consulte et vérifie ses dates ; l'agence et l'admin voient
/// en plus le matricule, la validation et l'historique des changements.
class VehicleDetailsScreen extends StatefulWidget {
  const VehicleDetailsScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  State<VehicleDetailsScreen> createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen> {
  final FleetService _service = FleetService.instance;

  FleetVehicle? _vehicle;
  User? _agency;
  VehicleCategory? _category;
  List<UnavailabilityPeriod> _periods = const [];
  List<HistoryEntry> _history = const [];
  List<VehicleDocument> _documents = const [];

  /// Véhicule pas encore validé : ce qui bloque la validation
  /// (check-list pour l'admin, rappel pour l'agence).
  List<String> _problems = const [];
  bool _reviewing = false;
  DateTime? _updatedAt;
  bool _loading = true;
  bool _gone = false;
  String? _error;
  int _photoIndex = 0;
  int _requestId = 0;

  Actor get _actor => const Actor.admin();
  bool get _isClient => _actor.isClient;

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
      final vehicle = await _service.getVehicleFor(widget.vehicleId, _actor);
      if (vehicle == null) {
        if (!mounted || request != _requestId) return;
        setState(() {
          _gone = true;
          _loading = false;
        });
        return;
      }
      final agency = await _service.agency(vehicle.agencyId);
      final category = await _service.category(vehicle.categoryId);
      final periods = await _service.unavailabilities(vehicle.id);
      final history = _isClient
          ? const <HistoryEntry>[]
          : await _service.history(vehicle.id);
      final documents = _isClient
          ? const <VehicleDocument>[]
          : await _service.documents(vehicle.id);
      final problems =
          !_isClient && vehicle.validation != ValidationStatus.valide
              ? await _service.validationProblems(vehicle.id)
              : const <String>[];
      if (!mounted || request != _requestId) return;
      setState(() {
        _vehicle = vehicle;
        _agency = agency;
        _category = category;
        _periods = periods;
        _history = history.take(8).toList();
        _documents = documents;
        _problems = problems;
        _updatedAt = DateTime.now();
        _gone = false;
        _loading = false;
        _error = null;
        if (_photoIndex >= vehicle.photos.length) _photoIndex = 0;
      });
    } catch (e) {
      if (!mounted || request != _requestId) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_gone || _error != null || _vehicle == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(),
        body: _Unavailable(
          message: _error ??
              "Ce véhicule n'est plus proposé. Il a peut-être été retiré "
                  "du catalogue par l'agence.",
        ),
      );
    }
    final vehicle = _vehicle!;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _Gallery(
              photos: vehicle.photos,
              brand: vehicle.brand,
              index: _photoIndex,
              onPageChanged: (i) => setState(() => _photoIndex = i),
              onDelete: _isClient ? null : () => _delete(vehicle),
            ),
          ),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -26),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: _buildContent(vehicle),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _isClient
          ? _BottomBar(
              price: vehicle.pricePerDay,
              onCheckDates: () => _showDateCheck(vehicle),
            )
          : _StaffBar(
              onEdit: () => _edit(vehicle),
              onStatus: () => showStatusSheet(context, vehicle),
              onTransfer: _actor.isAdmin
                  ? () => showTransferSheet(context, vehicle)
                  : null,
            ),
    );
  }

  Widget _buildContent(FleetVehicle vehicle) {
    final subtitle = [
      if (_category != null) _category!.name,
      '${vehicle.year}',
      if (!_isClient) vehicle.registrationPlate,
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _isClient
                ? StatusChip.forClient(vehicle.status)
                : StatusChip.vehicle(vehicle.status),
            if (!_isClient &&
                vehicle.validation != ValidationStatus.valide) ...[
              const SizedBox(width: 6),
              StatusChip.validation(vehicle.validation, compact: true),
            ],
            const Spacer(),
            _LiveBadge(updatedAt: _updatedAt),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          vehicle.fullName,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        if (!_isClient && vehicle.rejectionReason != null) ...[
          const SizedBox(height: 10),
          _InfoBanner(
            color: AppColors.redLight,
            textColor: AppColors.redDark,
            icon: Icons.report_gmailerrorred_rounded,
            text: 'Refusé : ${vehicle.rejectionReason}',
          ),
        ],
        if (_actor.isAdmin &&
            vehicle.validation != ValidationStatus.valide) ...[
          const SizedBox(height: 12),
          _ReviewPanel(
            problems: _problems,
            busy: _reviewing,
            onApprove: () => _review(vehicle, approve: true),
            onRefuse: vehicle.validation == ValidationStatus.refuse
                ? null
                : () => _review(vehicle, approve: false),
          ),
        ],
        if (_actor.isAgency && _problems.isNotEmpty) ...[
          const SizedBox(height: 10),
          _InfoBanner(
            color: AppColors.orangeLight,
            textColor: AppColors.orangeDark,
            icon: Icons.assignment_late_outlined,
            text: "Pour que l'administrateur puisse valider ce véhicule, "
                'complétez : ${_problems.join(' · ')}.',
          ),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _SpecTile(
                  Icons.settings_outlined, vehicle.transmission.label),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SpecTile(
                  Icons.speed_rounded, FleetFormat.km(vehicle.mileage)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SpecTile(
                  Icons.event_seat_outlined, '${vehicle.seats} places'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SpecTile(
                  Icons.local_gas_station_outlined, vehicle.fuel.label),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Pill(Icons.sensor_door_outlined, '${vehicle.doors} portes'),
            if (vehicle.color.isNotEmpty)
              _Pill(Icons.palette_outlined, vehicle.color),
            if (_category != null)
              _Pill(Icons.category_outlined, _category!.name),
          ],
        ),
        if (vehicle.description.isNotEmpty) ...[
          const _SectionTitle('Description'),
          Text(
            vehicle.description,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
        const _SectionTitle('Tarif'),
        Row(
          children: [
            Expanded(
              child: _PriceCard(
                label: 'Prix par jour',
                value: FleetFormat.dt(vehicle.pricePerDay),
                highlight: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PriceCard(
                label: 'Caution',
                value: FleetFormat.dt(vehicle.deposit),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Disponibilité',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: _showCalendar,
                child: const Text('Voir le calendrier'),
              ),
            ],
          ),
        ),
        AvailabilityStrip(periods: _periods),
        if (!_isClient) ...[
          const SizedBox(height: 12),
          ..._buildPeriodRows(),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => showUnavailabilitySheet(
                context,
                vehicleId: vehicle.id,
                periods: _periods,
              ),
              icon: const Icon(Icons.block_rounded, size: 18),
              label: const Text('Bloquer une période'),
            ),
          ),
        ],
        if (!_isClient) ...[
          const _SectionTitle('Documents'),
          ..._buildDocumentRows(vehicle),
        ],
        if (_agency != null) ...[
          const _SectionTitle('Agence'),
          _AgencyCard(agency: _agency!, onContact: () => _showContact(_agency!)),
        ],
        if (!_isClient) ...[
          const _SectionTitle('Historique des changements'),
          if (_history.isEmpty)
            const Text(
              'Aucun changement enregistré.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            )
          else
            for (final entry in _history) _HistoryRow(entry: entry),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  Future<void> _review(FleetVehicle vehicle, {required bool approve}) async {
    setState(() => _reviewing = true);
    await reviewVehicleAction(context, vehicle, approve: approve);
    if (mounted) setState(() => _reviewing = false);
  }

  Future<void> _edit(FleetVehicle vehicle) async {
    final result = await Navigator.of(context).push<VehicleFormResult>(
      MaterialPageRoute<VehicleFormResult>(
        builder: (_) => VehicleFormScreen(vehicleId: vehicle.id),
      ),
    );
    if (result == VehicleFormResult.deleted && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete(FleetVehicle vehicle) async {
    final ok = await confirmAction(
      context,
      title: 'Supprimer ce véhicule ?',
      message: '${vehicle.fullName} (${vehicle.registrationPlate}) sera '
          "retiré de la flotte. L'historique est conservé.",
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await _service.deleteVehicle(vehicle.id, _actor);
      navigator.pop();
      showFleetSnack(messenger, '${vehicle.fullName} supprimé');
    } catch (e) {
      showFleetSnack(messenger, fleetErrorMessage(e), error: true);
    }
  }

  Future<void> _removePeriod(UnavailabilityPeriod period) async {
    final ok = await confirmAction(
      context,
      title: 'Débloquer cette période ?',
      message: 'Du ${FleetDates.display(period.start)} au '
          '${FleetDates.display(period.end)} (${period.reason}).',
      confirmLabel: 'Débloquer',
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.removeUnavailability(period.id!, _actor);
      showFleetSnack(messenger, 'Période débloquée');
    } catch (e) {
      showFleetSnack(messenger, fleetErrorMessage(e), error: true);
    }
  }

  List<Widget> _buildPeriodRows() {
    final today = FleetDates.dayOnly(DateTime.now());
    final upcoming =
        _periods.where((p) => !p.end.isBefore(today)).toList();
    if (upcoming.isEmpty) {
      return const [
        Text(
          'Aucune période bloquée à venir.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ];
    }
    return [
      for (final p in upcoming)
        _ManageRow(
          icon: p.reason.startsWith('Réservation')
              ? Icons.event_available_rounded
              : Icons.block_rounded,
          iconColor: p.reason.startsWith('Réservation')
              ? AppColors.primaryBlue
              : AppColors.redDark,
          title: 'Du ${FleetDates.display(p.start)} au '
              '${FleetDates.display(p.end)} · ${p.days} j',
          subtitle: p.reason.startsWith('Réservation')
              ? 'Occupé — géré par le module Réservations'
              : p.reason,
          action: p.reason.startsWith('Réservation')
              ? null
              : IconButton(
                  tooltip: 'Débloquer',
                  onPressed: () => _removePeriod(p),
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.red),
                ),
        ),
    ];
  }

  List<Widget> _buildDocumentRows(FleetVehicle vehicle) {
    final now = DateTime.now();
    final used = _documents.map((d) => d.type).toSet();
    return [
      for (final doc in _documents)
        _ManageRow(
          icon: Icons.description_outlined,
          iconColor: doc.stateAt(now).color,
          title: doc.type.label,
          subtitle: [
            if (doc.reference.isNotEmpty) doc.reference,
            doc.expiryDate == null
                ? 'Sans expiration'
                : 'Expire le ${FleetDates.display(doc.expiryDate!)}',
          ].join(' · '),
          badge: doc.stateAt(now),
          onTap: () => showDocumentSheet(
            context,
            vehicleId: vehicle.id,
            existing: doc,
            usedTypes: used,
          ),
        ),
      if (used.length < DocumentType.values.length)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => showDocumentSheet(
              context,
              vehicleId: vehicle.id,
              usedTypes: used,
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Ajouter un document'),
          ),
        ),
    ];
  }

  void _showCalendar() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Calendrier de disponibilité',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            AvailabilityCalendar(periods: _periods),
            if (!_isClient && _periods.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Périodes bloquées',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              for (final p in _periods)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.block_rounded,
                      size: 18, color: AppColors.redDark),
                  title: Text('Du ${FleetDates.display(p.start)} '
                      'au ${FleetDates.display(p.end)}'),
                  subtitle: Text(p.reason),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDateCheck(FleetVehicle vehicle) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _DateCheckSheet(vehicle: vehicle, periods: _periods),
    );
  }

  void _showContact(User agency) {
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        Widget row(IconData icon, String label, String value) {
          return ListTile(
            leading: Icon(icon, color: AppColors.primaryBlue),
            title: Text(value),
            subtitle: Text(label),
            trailing: IconButton(
              tooltip: 'Copier',
              icon: const Icon(Icons.copy_rounded, size: 18),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                messenger.showSnackBar(
                  SnackBar(content: Text('$label copié : $value')),
                );
              },
            ),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  agency.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(agency.adresseAgence ?? ''),
              ),
              if (agency.telephone.isNotEmpty)
                row(Icons.phone_outlined, 'Téléphone', agency.telephone),
              if (agency.email.isNotEmpty)
                row(Icons.mail_outline_rounded, 'E-mail', agency.email),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------- Galerie

class _Gallery extends StatelessWidget {
  const _Gallery({
    required this.photos,
    required this.brand,
    required this.index,
    required this.onPageChanged,
    this.onDelete,
  });

  final List<String> photos;
  final String brand;
  final int index;
  final ValueChanged<int> onPageChanged;
  final VoidCallback? onDelete;

  static const double _height = 310;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: Stack(
        children: [
          Positioned.fill(
            child: photos.isEmpty
                ? VehiclePhoto(
                    path: null,
                    label: brand,
                    height: _height,
                    borderRadius: BorderRadius.zero,
                  )
                : PageView.builder(
                    itemCount: photos.length,
                    onPageChanged: onPageChanged,
                    itemBuilder: (_, i) => VehiclePhoto(
                      path: photos[i],
                      label: brand,
                      height: _height,
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _RoundButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
                    if (onDelete != null)
                      _RoundButton(
                        icon: Icons.delete_outline_rounded,
                        color: AppColors.red,
                        onTap: onDelete!,
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (photos.length > 1)
            Positioned(
              right: 16,
              bottom: 40,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${index + 1}/${photos.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onTap,
    this.color = AppColors.textPrimary,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: color),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- Morceaux

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.updatedAt});
  final DateTime? updatedAt;

  @override
  Widget build(BuildContext context) {
    final time = updatedAt;
    final hhmm = time == null
        ? ''
        : ' · ${time.hour.toString().padLeft(2, '0')}:'
            '${time.minute.toString().padLeft(2, '0')}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppColors.green,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'En direct$hhmm',
          style: const TextStyle(
            color: AppColors.greenDark,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SpecTile extends StatelessWidget {
  const _SpecTile(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: AppColors.primaryNavy),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.sectionBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? AppColors.primaryNavy : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: highlight ? null : Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: highlight ? AppColors.textFleetSub : AppColors.textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: highlight ? Colors.white : AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgencyCard extends StatelessWidget {
  const _AgencyCard({required this.agency, required this.onContact});

  final User agency;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    final initials = agency.displayName.isNotEmpty
        ? agency.displayName.substring(0, 1).toUpperCase()
        : 'A';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.darkBlueCard,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agency.displayName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  agency.adresseAgence ?? '',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: onContact,
            child: const Text('Contacter'),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});
  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.primaryBlue,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.summary,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${FleetDates.displayWithTime(entry.timestamp)} · '
                  '${entry.actor}'
                  '${entry.comment == null ? '' : ' · ${entry.comment}'}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.color,
    required this.textColor,
    required this.icon,
    required this.text,
  });

  final Color color;
  final Color textColor;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: textColor, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.price, required this.onCheckDates});

  final double price;
  final VoidCallback onCheckDates;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    FleetFormat.dt(price),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    'par jour',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onCheckDates,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.event_available_rounded),
                  label: const Text('Vérifier mes dates'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_car_outlined,
                size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Retour au catalogue'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffBar extends StatelessWidget {
  const _StaffBar({
    required this.onEdit,
    required this.onStatus,
    this.onTransfer,
  });

  final VoidCallback onEdit;
  final VoidCallback onStatus;

  /// Administrateur seulement.
  final VoidCallback? onTransfer;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: onEdit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: shape,
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifier'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onStatus,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    minimumSize: const Size.fromHeight(52),
                    shape: shape,
                  ),
                  icon: const Icon(Icons.swap_vert_rounded),
                  label: const Text('Statut'),
                ),
              ),
              if (onTransfer != null) ...[
                const SizedBox(width: 12),
                SizedBox(
                  width: 52,
                  height: 52,
                  child: IconButton.outlined(
                    tooltip: 'Transférer vers une agence',
                    onPressed: onTransfer,
                    style: IconButton.styleFrom(shape: shape),
                    icon: const Icon(Icons.swap_horiz_rounded),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Validation par l'administrateur, directement depuis la fiche.
class _ReviewPanel extends StatelessWidget {
  const _ReviewPanel({
    required this.problems,
    required this.busy,
    required this.onApprove,
    required this.onRefuse,
  });

  final List<String> problems;
  final bool busy;
  final VoidCallback onApprove;

  /// Null si le véhicule est déjà refusé.
  final VoidCallback? onRefuse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Validation administrateur',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (problems.isEmpty)
            const _CheckRow(
              ok: true,
              text: 'Assurance, visite technique et prix en règle',
            )
          else
            for (final problem in problems) _CheckRow(ok: false, text: problem),
          const SizedBox(height: 10),
          Row(
            children: [
              if (onRefuse != null) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onRefuse,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.redDark,
                      side: const BorderSide(color: AppColors.redBorder),
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Refuser'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: busy || problems.isNotEmpty ? null : onApprove,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.green,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Valider'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16,
            color: ok ? AppColors.green : AppColors.redDark,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: ok ? AppColors.textPrimary : AppColors.redDark,
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

class _ManageRow extends StatelessWidget {
  const _ManageRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.badge,
    this.action,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final DocumentState? badge;
  final Widget? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final state = badge;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (state != null)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: state.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      state.label,
                      style: TextStyle(
                        color: state.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (action != null) action!,
                if (action == null && onTap != null)
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------- Vérification des dates

class _DateCheckSheet extends StatefulWidget {
  const _DateCheckSheet({required this.vehicle, required this.periods});

  final FleetVehicle vehicle;
  final List<UnavailabilityPeriod> periods;

  @override
  State<_DateCheckSheet> createState() => _DateCheckSheetState();
}

class _DateCheckSheetState extends State<_DateCheckSheet> {
  DateTime? _start;
  DateTime? _end;
  bool _checking = false;
  String? _problem;
  bool _checked = false;
  int _requestId = 0;

  Future<void> _onRangeChanged(DateTime? start, DateTime? end) async {
    setState(() {
      _start = start;
      _end = end;
      _checked = false;
      _problem = null;
    });
    if (start == null) return;
    final request = ++_requestId;
    setState(() => _checking = true);
    final problem = await FleetService.instance
        .availabilityProblem(widget.vehicle.id, start, end ?? start);
    if (!mounted || request != _requestId) return;
    setState(() {
      _checking = false;
      _checked = true;
      _problem = problem;
    });
  }

  @override
  Widget build(BuildContext context) {
    final start = _start;
    final end = _end ?? _start;
    final days = start == null || end == null
        ? 0
        : FleetDates.dayOnly(end).difference(FleetDates.dayOnly(start)).inDays +
            1;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Vérifier mes dates',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Touchez la date de départ puis la date de retour.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          AvailabilityCalendar(
            periods: widget.periods,
            onRangeChanged: _onRangeChanged,
          ),
          const SizedBox(height: 14),
          if (start != null && end != null)
            Text(
              start == end
                  ? 'Le ${FrenchDates.shortDay(start)} · 1 jour'
                  : 'Du ${FrenchDates.shortDay(start)} au '
                      '${FrenchDates.shortDay(end)} · $days jours',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 10),
          if (_checking)
            const LinearProgressIndicator()
          else if (_checked)
            _problem == null
                ? _InfoBanner(
                    color: AppColors.greenLight,
                    textColor: AppColors.greenDark,
                    icon: Icons.check_circle_rounded,
                    text: 'Disponible sur ces dates · '
                        '${FleetFormat.dt(widget.vehicle.pricePerDay)} par jour, '
                        'caution ${FleetFormat.dt(widget.vehicle.deposit)}.',
                  )
                : _InfoBanner(
                    color: AppColors.redLight,
                    textColor: AppColors.redDark,
                    icon: Icons.event_busy_rounded,
                    text: _problem!,
                  ),
          const SizedBox(height: 12),
          const Text(
            'La réservation et le calcul du montant total se font dans le '
            'module Réservations.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
