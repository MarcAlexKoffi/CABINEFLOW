import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 72,
    this.icon = Icons.all_inbox_rounded,
    this.subtitle,
    this.titleFontSize = 28,
  });

  final double size;
  final IconData icon;
  final String? subtitle;
  final double titleFontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(size * 0.24),
            border: Border.all(color: AppColors.outlineVariant.withAlpha(130)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Icon(icon, size: size * 0.5, color: AppColors.primary),
        ),
        const SizedBox(height: 16),
        Text(
          'CabineFlow',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: titleFontSize,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: AppColors.onBackground,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
