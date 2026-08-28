import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class IzyTelCopyButton extends StatelessWidget {
  const IzyTelCopyButton({
    super.key,
    required this.value,
    this.tooltip = 'Copier',
    this.successMessage = 'Copié',
    this.compact = true,
  });

  final String value;
  final String tooltip;
  final String successMessage;
  final bool compact;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(successMessage),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        onPressed: () => _copy(context),
        icon: const Icon(
          Icons.copy_rounded,
          size: 18,
          color: CustomerAppColors.primary,
        ),
      );
    }

    return TextButton.icon(
      onPressed: () => _copy(context),
      icon: const Icon(Icons.copy_rounded, size: 18),
      label: Text(tooltip),
    );
  }
}
