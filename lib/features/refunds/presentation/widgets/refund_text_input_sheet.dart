import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class RefundTextInputSheet extends StatefulWidget {
  const RefundTextInputSheet({
    super.key,
    required this.title,
    required this.label,
    required this.hint,
    required this.confirmLabel,
    this.description,
    this.maxLength = 500,
    this.minLength = 3,
    this.maxLines = 4,
  });

  final String title;
  final String label;
  final String hint;
  final String confirmLabel;
  final String? description;
  final int maxLength;
  final int minLength;
  final int maxLines;

  @override
  State<RefundTextInputSheet> createState() => _RefundTextInputSheetState();
}

class _RefundTextInputSheetState extends State<RefundTextInputSheet> {
  late final TextEditingController _controller;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        color: AppColors.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outline.withAlpha(90),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: AppColors.onBackground,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (widget.description != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.description!,
                    style: const TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: AppColors.onBackground,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                TextField(
                  controller: _controller,
                  minLines: widget.maxLines > 1 ? 2 : 1,
                  maxLines: widget.maxLines,
                  maxLength: widget.maxLength,
                  style: const TextStyle(color: AppColors.inputText),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    filled: true,
                    fillColor: AppColors.inputBackground,
                    hintStyle: const TextStyle(color: AppColors.inputHint),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('Annuler'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: Text(widget.confirmLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    final String value = _controller.text.trim();
    if (value.length < widget.minLength) {
      setState(() {
        _errorMessage = 'Saisissez au moins ${widget.minLength} caractères.';
      });
      return;
    }
    Navigator.of(context).pop(value);
  }
}
