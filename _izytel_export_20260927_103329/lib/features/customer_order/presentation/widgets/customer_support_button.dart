import 'package:cabine_flow/core/services/customer_support_whatsapp.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
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

    IzyTelFeedback.error(
      context,
      'Impossible d’ouvrir WhatsApp. Vous pouvez contacter le ${CustomerSupportWhatsApp.displayPhone}.',
    );
  }

  Widget _whatsAppIcon() {
    return Image.asset(
      'assets/images/whatsapp_logo.png',
      width: 21,
      height: 21,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget button = switch (style) {
      CustomerSupportButtonStyle.text => TextButton.icon(
        onPressed: () {
          _open(context);
        },
        icon: _whatsAppIcon(),
        label: Text(label),
      ),
      CustomerSupportButtonStyle.outlined => OutlinedButton.icon(
        onPressed: () {
          _open(context);
        },
        icon: _whatsAppIcon(),
        label: Text(label),
      ),
      CustomerSupportButtonStyle.filled => FilledButton.icon(
        onPressed: () {
          _open(context);
        },
        icon: _whatsAppIcon(),
        label: Text(label),
      ),
    };

    if (!fullWidth) {
      return button;
    }

    return SizedBox(width: double.infinity, child: button);
  }
}
