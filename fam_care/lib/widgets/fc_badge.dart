import 'package:flutter/material.dart';
import '../config/theme.dart';

enum BadgeVariant { blue, green, red, amber, gray }

class FcBadge extends StatelessWidget {
  final String label;
  final BadgeVariant variant;
  final IconData? icon;

  const FcBadge({
    super.key,
    required this.label,
    this.variant = BadgeVariant.blue,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (variant) {
      BadgeVariant.blue  => (AppTheme.blueBg,  AppTheme.blueText),
      BadgeVariant.green => (AppTheme.greenBg, AppTheme.greenText),
      BadgeVariant.red   => (AppTheme.redBg,   AppTheme.redText),
      BadgeVariant.amber => (AppTheme.amberBg, AppTheme.amberText),
      BadgeVariant.gray  => (AppTheme.grayBg,  AppTheme.grayText),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
