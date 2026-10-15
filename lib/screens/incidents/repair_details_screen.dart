import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/mock_data.dart';
import '../../models/repair_item.dart';
import '../../widgets/custom_app_bar.dart';

class RepairDetailsScreen extends StatefulWidget {
  const RepairDetailsScreen({super.key});

  @override
  State<RepairDetailsScreen> createState() => _RepairDetailsScreenState();
}

class _RepairDetailsScreenState extends State<RepairDetailsScreen> {
  late RepairDetails _repair;
  late List<RepairPart> _parts;

  @override
  void initState() {
    super.initState();
    _repair = MockData.repairs.first;
    _parts = List.from(_repair.parts);
  }

  double get _partsCost => _parts.fold(0.0, (acc, item) => acc + item.total);
  double get _totalCost => _repair.laborCost + _partsCost;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            CustomHeader(
              title: 'Dossier de réparation',
              subtitle: '#${_repair.id} • ${_repair.vehicleModel}',
              showBackButton: true,
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status and Garage Card
                    _buildCard(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _repair.vehicleModel,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.cyanLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _repair.status,
                                style: const TextStyle(
                                  color: AppColors.cyanIcon,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildRow('Garage assigné', _repair.garageName),
                        const Divider(height: 18),
                        _buildRow('Technicien en charge', _repair.technicianName),
                        const Divider(height: 18),
                        _buildRow('Date de début', _repair.startDate),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Work Performed Card
                    _buildCard(
                      children: [
                        const Text(
                          'Travaux effectués & Diagnostic',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _repair.workPerformed,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Parts and Materials
                    _buildCard(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Pièces & Fournitures',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            InkWell(
                              onTap: _showAddPartDialog,
                              child: const Text(
                                '+ Ajouter pièce',
                                style: TextStyle(
                                  color: AppColors.primaryBlue,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._parts.map((p) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${p.quantity}x ${p.name}',
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${p.total.toStringAsFixed(0)} DT',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                        const Divider(height: 20),
                        _buildRow('Main d\'œuvre', '${_repair.laborCost.toStringAsFixed(0)} DT'),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Coût total réparation',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${_totalCost.toStringAsFixed(0)} DT',
                              style: const TextStyle(
                                color: AppColors.greenPrice,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.greenPrice,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Réparation validée et clôturée')),
                          );
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Valider et clôturer la réparation',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [AppColors.softShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  void _showAddPartDialog() {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ajouter une pièce'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Désignation de la pièce'),
            ),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantité'),
            ),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Prix unitaire (DT)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
            onPressed: () {
              final name = nameCtrl.text.trim();
              final qty = int.tryParse(qtyCtrl.text) ?? 1;
              final price = double.tryParse(priceCtrl.text) ?? 0.0;
              if (name.isNotEmpty && price > 0) {
                setState(() {
                  _parts.add(RepairPart(name: name, quantity: qty, unitPrice: price));
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Ajouter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
