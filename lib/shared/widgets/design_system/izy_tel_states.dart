import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:flutter/material.dart';

import 'izy_tel_buttons.dart';

class IzyTelEmptyState extends StatelessWidget {
  const IzyTelEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.actionText,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: CustomerAppColors.primaryContainer.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: CustomerAppColors.primary),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: CustomerAppColors.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 15,
              color: CustomerAppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 32),
            IzyTelSecondaryButton(text: actionText!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

class IzyTelErrorState extends StatelessWidget {
  const IzyTelErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: CustomerAppColors.errorContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: CustomerAppColors.error,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Une erreur est survenue',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: CustomerAppColors.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 15,
              color: CustomerAppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 32),
            IzyTelSecondaryButton(
              text: 'Réessayer',
              onPressed: onRetry,
              icon: Icons.refresh_rounded,
            ),
          ],
        ],
      ),
    );
  }
}

class IzyTelSkeleton extends StatelessWidget {
  const IzyTelSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 16,
  });

  final double? width;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: CustomerAppColors.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
