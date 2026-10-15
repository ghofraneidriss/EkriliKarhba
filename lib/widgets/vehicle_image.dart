import 'package:flutter/material.dart';

class VehicleImage extends StatelessWidget {
  final String? imagePath;
  final String modelName;
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final BoxFit fit;

  const VehicleImage({
    super.key,
    this.imagePath,
    required this.modelName,
    this.width = double.infinity,
    this.height = 140,
    this.borderRadius,
    this.fit = BoxFit.cover,
  });

  String _resolveAsset() {
    if (imagePath != null && imagePath!.isNotEmpty) {
      return imagePath!;
    }
    final lower = modelName.toLowerCase();
    if (lower.contains('peugeot') || lower.contains('208')) {
      return 'assets/images/peugeot_208.jpg';
    } else if (lower.contains('clio') || lower.contains('renault')) {
      return 'assets/images/renault_clio.jpg';
    } else if (lower.contains('bmw')) {
      return 'assets/images/bmw_serie3.jpg';
    }
    return 'assets/images/peugeot_208.jpg';
  }

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(16);
    final asset = _resolveAsset();

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: width,
        height: height,
        color: const Color(0xFF1E293B),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              asset,
              fit: fit,
              errorBuilder: (context, error, stackTrace) {
                return _buildFallback(radius);
              },
            ),
            // Gradient overlay for contrast
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.10),
                    Colors.black.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallback(BorderRadius radius) {
    return Container(
      decoration: BoxDecoration(
        gradient: _getGradientForModel(modelName),
      ),
      child: Center(
        child: Icon(
          Icons.directions_car_filled_rounded,
          size: height * 0.45,
          color: _getCarColor(modelName),
        ),
      ),
    );
  }

  LinearGradient _getGradientForModel(String model) {
    if (model.contains('BMW')) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0F3057), Color(0xFF00587A), Color(0xFF071E3D)],
      );
    } else if (model.contains('Clio') || model.contains('Renault')) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1F2937), Color(0xFF111827), Color(0xFF030712)],
      );
    } else {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2E384D), Color(0xFF1A2238), Color(0xFF101626)],
      );
    }
  }

  Color _getCarColor(String model) {
    if (model.contains('BMW')) {
      return const Color(0xFF38BDF8);
    } else if (model.contains('Clio')) {
      return const Color(0xFF94A3B8);
    } else {
      return const Color(0xFFE2E8F0);
    }
  }
}
