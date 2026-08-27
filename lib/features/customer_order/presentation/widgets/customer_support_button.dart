import 'package:cabine_flow/core/services/customer_support_whatsapp.dart';
import 'package:flutter/material.dart';

enum CustomerSupportButtonStyle { text, outlined, filled }

class CustomerSupportButton extends StatelessWidget {
  const CustomerSupportButton({
    super.key,
    this.orderReference,
    this.label = 'Contacter le service client',
    this.style = CustomerSupportButtonStyle.text,
    this.fullWidth = false,
  });

  final String? orderReference;
  final String label;
  final CustomerSupportButtonStyle style;
  final bool fullWidth;

  Future<void> _open(BuildContext context) async {
    bool opened = false;

    try {
      opened = await CustomerSupportWhatsApp.open(
        orderReference: orderReference,
      );
    } catch (_) {
      opened = false;
    }

    if (opened || !context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Impossible d’ouvrir WhatsApp. Vous pouvez contacter le ${CustomerSupportWhatsApp.displayPhone}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget button = switch (style) {
      CustomerSupportButtonStyle.text => TextButton.icon(
        onPressed: () {
          _open(context);
        },
        icon: const Icon(Icons.support_agent_rounded),
        label: Text(label),
      ),
      CustomerSupportButtonStyle.outlined => OutlinedButton.icon(
        onPressed: () {
          _open(context);
        },
        icon: const Icon(Icons.support_agent_rounded),
        label: Text(label),
      ),
      CustomerSupportButtonStyle.filled => FilledButton.icon(
        onPressed: () {
          _open(context);
        },
        icon: const Icon(Icons.support_agent_rounded),
        label: Text(label),
      ),
    };

    if (!fullWidth) {
      return button;
    }

    return SizedBox(width: double.infinity, child: button);
  }
}
