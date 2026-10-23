import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Photo d'un véhicule : asset (assets/...), fichier local, ou visuel
/// neutre (dégradé + icône + marque) si aucune photo n'est disponible.
class VehiclePhoto extends StatelessWidget {
  const VehiclePhoto({
    super.key,
    required this.path,
    this.label,
    this.width = double.infinity,
    this.height = 140,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.fit = BoxFit.cover,
  });

  final String? path;

  /// Texte affiché sur le visuel neutre (ex. la marque).
  final String? label;
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(width: width, height: height, child: _image()),
    );
  }

  Widget _image() {
    final placeholder = _Placeholder(label: label);
    final value = path;
    if (value == null || value.isEmpty) return placeholder;
    if (value.startsWith('assets/')) {
      return Image.asset(
        value,
        fit: fit,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }
    final file = File(value);
    if (!file.existsSync()) return placeholder;
    return Image.file(
      file,
      fit: fit,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final text = label;
    return LayoutBuilder(
      builder: (context, constraints) {
        final big = constraints.maxHeight > 120;
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.blueLight, AppColors.sectionBg],
            ),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.directions_car_filled_rounded,
                size: big ? 64 : 38,
                color: AppColors.primaryBlue.withValues(alpha: 0.35),
              ),
              if (text != null && text.isNotEmpty && big) ...[
                const SizedBox(height: 6),
                Text(
                  text.toUpperCase(),
                  style: TextStyle(
                    color: AppColors.primaryNavy.withValues(alpha: 0.35),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
