import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class IzyTelTextInput extends StatelessWidget {
  const IzyTelTextInput({
    super.key,
    required this.controller,
    this.label,
    this.hintText,
    this.helperText,
    this.keyboardType,
    this.validator,
    this.prefixIcon,
    this.suffixText,
    this.maxLength,
    this.onChanged,
    this.onFieldSubmitted,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String? label;
  final String? hintText;
  final String? helperText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;
  final String? suffixText;
  final int? maxLength;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: CustomerAppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          autofillHints: autofillHints,
          inputFormatters: inputFormatters,
          validator: validator,
          maxLength: maxLength,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          enableInteractiveSelection: true,
          decoration: InputDecoration(
            hintText: hintText,
            helperText: helperText,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
            suffixText: suffixText,
            counterText: '',
          ),
        ),
      ],
    );
  }
}
