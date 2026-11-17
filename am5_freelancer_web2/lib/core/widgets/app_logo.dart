import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.light = false,
    this.showText = true,
    this.compact = false,
  });

  /// True when placed on a dark/primary background (text becomes white).
  final bool light;

  /// Whether to show the "AM5 ROYAL" text next to the icon.
  final bool showText;

  /// Smaller version for app bars and tight spaces.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color mainColor = light ? AppColors.white : AppColors.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 38 : 46,
          height: compact ? 38 : 46,
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            'A',
            style: TextStyle(
              fontSize: compact ? 20 : 24,
              fontWeight: FontWeight.w900,
              color: AppColors.primaryDark,
            ),
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 12),
          Text(
            'AM5 ROYAL',
            style: AppTextStyles.logo.copyWith(
              fontSize: compact ? 20 : 24,
              color: mainColor,
            ),
          ),
        ],
      ],
    );
  }
}
