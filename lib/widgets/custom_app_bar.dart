import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class CustomHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool showBackButton;
  final VoidCallback? onBack;
  final Widget? trailing;

  const CustomHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.showBackButton = false,
    this.onBack,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showBackButton) ...[
            InkWell(
              onTap: onBack ?? () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorderSubtle, width: 1),
                  boxShadow: const [AppColors.softShadow],
                ),
                child: const Icon(
                  Icons.chevron_left_rounded,
                  color: AppColors.primaryNavy,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class NotificationBellButton extends StatelessWidget {
  final VoidCallback? onTap;

  const NotificationBellButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.cardBorderSubtle, width: 1),
          boxShadow: const [AppColors.softShadow],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.primaryNavy,
              size: 22,
            ),
            Positioned(
              top: 11,
              right: 12,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.redDark,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
