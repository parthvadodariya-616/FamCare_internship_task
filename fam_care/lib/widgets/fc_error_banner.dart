import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'fc_icons.dart';

class FcErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const FcErrorBanner({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.redBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.redText.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(TIcons.alertCircle, size: 18, color: AppTheme.redText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.redText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRetry,
              child: Text(
                'Retry',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.redText,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
