import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/custom_app_bar.dart';

class MileageRecord {
  final String date;
  final int mileage;
  final String reason;
  final bool isLatest;

  const MileageRecord({
    required this.date,
    required this.mileage,
    required this.reason,
    this.isLatest = false,
  });
}

class VehicleMileageScreen extends StatefulWidget {
  final String vehicleModel;
  final int initialMileage;

  const VehicleMileageScreen({
    super.key,
    this.vehicleModel = 'Peugeot 208',
    this.initialMileage = 82450,
  });

  @override
  State<VehicleMileageScreen> createState() => _VehicleMileageScreenState();
}

class _VehicleMileageScreenState extends State<VehicleMileageScreen> {
  late int _currentMileage;
  late String _lastUpdated;
  late List<MileageRecord> _history;

  @override
  void initState() {
    super.initState();
    _currentMileage = widget.initialMileage;
    _lastUpdated = 'Mis à jour le 12 Oct 2026';
    _history = [
      const MileageRecord(
        date: '12 Oct',
        mileage: 82450,
        reason: 'Après location · 550 km',
        isLatest: true,
      ),
      const MileageRecord(
        date: '05 Oct',
        mileage: 81900,
        reason: 'Retour véhicule',
        isLatest: false,
      ),
      const MileageRecord(
        date: '28 Sep',
        mileage: 81200,
        reason: 'Contrôle agence',
        isLatest: false,
      ),
    ];
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]} ',
    );
  }

  void _showAddMileageDialog() {
    final mileageCtrl = TextEditingController();
    final reasonCtrl = TextEditingController(text: 'Après location');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ajouter un relevé',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: mileageCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Nouveau kilométrage (km)',
                hintText: 'ex: 83 000',
                filled: true,
                fillColor: AppColors.cardSubtleBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.cardBorderSubtle),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              decoration: InputDecoration(
                labelText: 'Motif / Contexte',
                hintText: 'ex: Retour véhicule, Entretien...',
                filled: true,
                fillColor: AppColors.cardSubtleBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.cardBorderSubtle),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.headerNavyStart,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  final val = int.tryParse(mileageCtrl.text.replaceAll(' ', ''));
                  if (val != null && val > 0) {
                    setState(() {
                      _currentMileage = val;
                      _lastUpdated = 'Mis à jour aujourd\'hui';
                      final diff = val - (_history.isNotEmpty ? _history.first.mileage : 0);
                      final diffStr = diff > 0 ? ' · +$diff km' : '';
                      _history.insert(
                        0,
                        MileageRecord(
                          date: 'Aujourd\'hui',
                          mileage: val,
                          reason: '${reasonCtrl.text.trim()}$diffStr',
                          isLatest: true,
                        ),
                      );
                    });
                    Navigator.pop(ctx);
                  }
                },
                child: const Text(
                  'Enregistrer le kilométrage',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            CustomHeader(
              title: 'Kilométrage',
              subtitle: widget.vehicleModel,
              showBackButton: true,
              onBack: () => Navigator.of(context).pop(),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Navy Hero Card
                    _buildCurrentMileageCard(),

                    const SizedBox(height: 16),

                    // Add Mileage Button
                    _buildAddMileageButton(),

                    const SizedBox(height: 28),

                    // Historique Section
                    const Text(
                      'Historique',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // History Card with items
                    _buildHistoryCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentMileageCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E3A5F),
            Color(0xFF163758),
            Color(0xFF102842),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x20163758),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Top row with speedometer icon on left
          Align(
            alignment: Alignment.topLeft,
            child: Icon(
              Icons.speed_rounded,
              color: const Color(0xFF38BDF8).withValues(alpha: 0.9),
              size: 28,
            ),
          ),

          const SizedBox(height: 4),

          // Label
          const Text(
            'KILOMÉTRAGE ACTUEL',
            style: TextStyle(
              color: Color(0xFF7E9AB5),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
            ),
          ),

          const SizedBox(height: 10),

          // Mileage Big Value
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _formatNumber(_currentMileage),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'km',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Subtitle
          Text(
            _lastUpdated,
            style: const TextStyle(
              color: Color(0xFF94AEC6),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddMileageButton() {
    return InkWell(
      onTap: _showAddMileageDialog,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFF163758),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF163758).withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'Ajouter un kilométrage',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder, width: 1),
        boxShadow: const [AppColors.softShadow],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _history.length,
        separatorBuilder: (_, __) => const Divider(
          height: 1,
          thickness: 1,
          color: Color(0xFFF1F5F9),
        ),
        itemBuilder: (context, index) {
          final item = _history[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Date indicator column
                SizedBox(
                  width: 70,
                  child: Row(
                    children: [
                      // Dot indicator
                      if (item.isLatest)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryBlue,
                            shape: BoxShape.circle,
                          ),
                        )
                      else
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF94A3B8),
                              width: 1.5,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        item.date,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Content column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_formatNumber(item.mileage)} km',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.reason,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
