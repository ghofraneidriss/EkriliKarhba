import 'package:flutter/material.dart';

class AppColors {
  // Primary brand navy colors
  static const Color primaryNavy = Color(0xFF0F1E36);
  static const Color headerNavyStart = Color(0xFF163758);
  static const Color headerNavyEnd = Color(0xFF102842);
  static const Color darkBlueCard = Color(0xFF1E3A5F);

  // Background and surfaces
  static const Color background = Color(0xFFF8FAFC);
  static const Color cardBackground = Colors.white;
  static const Color cardBorder = Color(0xFFF1F5F9);
  static const Color cardBorderSubtle = Color(0xFFE2E8F0);
  static const Color inputBackground = Colors.white;
  static const Color inputBorder = Color(0xFFE2E8F0);
  static const Color cardSubtleBg = Color(0xFFF8FAFC);
  static const Color sectionBg = Color(0xFFF1F5F9);

  // Brand Accent
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color blueLight = Color(0xFFEFF6FF);
  static const Color blueSoft = Color(0xFFE0EEFF);
  static const Color blueIcon = Color(0xFF0284C7);

  // Teal / Cyan (Fleet indicator)
  static const Color tealAccent = Color(0xFF2DD4BF);
  static const Color tealTrack = Color(0xFF1E4366);

  // Status: Warning & Overdue (Red)
  static const Color red = Color(0xFFEF4444);
  static const Color redDark = Color(0xFFDC2626);
  static const Color redLight = Color(0xFFFEE2E2);
  static const Color redBorder = Color(0xFFFECACA);

  // Status: Pending / Upcoming (Orange / Amber)
  static const Color orange = Color(0xFFF97316);
  static const Color orangeDark = Color(0xFFEA580C);
  static const Color orangeLight = Color(0xFFFFF7ED);
  static const Color orangePillBg = Color(0xFFFFEDD5);
  static const Color nextMaintenanceBg = Color(0xFFFFF8F0);
  static const Color nextMaintenanceBorder = Color(0xFFFED7AA);

  // Status: Done / Available (Green)
  static const Color green = Color(0xFF10B981);
  static const Color greenDark = Color(0xFF16A34A);
  static const Color greenLight = Color(0xFFDCFCE7);
  static const Color greenPrice = Color(0xFF059669);

  // Status: In repair / In progress (Cyan / Light Blue)
  static const Color cyanLight = Color(0xFFE0F2FE);
  static const Color cyanIcon = Color(0xFF0284C7);

  // Text Colors
  static const Color textPrimary = Color(0xFF0F1E36);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textHeaderSub = Color(0xFF8C9CAE);
  static const Color textFleetSub = Color(0xFF94AEC6);
  static const Color textFleetLabel = Color(0xFF7E9AB5);

  // Shadows
  static const BoxShadow softShadow = BoxShadow(
    color: Color(0x080F1E36),
    blurRadius: 12,
    offset: Offset(0, 4),
  );

  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 16,
    offset: Offset(0, 6),
  );

  static const BoxShadow fabShadow = BoxShadow(
    color: Color(0x402563EB),
    blurRadius: 18,
    offset: Offset(0, 8),
  );
}
