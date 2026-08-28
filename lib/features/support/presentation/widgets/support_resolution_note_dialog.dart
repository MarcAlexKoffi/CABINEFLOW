import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Formulaire mobile-first utilisé pour saisir la note de résolution d'une
/// demande client.
///
/// Il est conçu pour être affiché dans un `showModalBottomSheet` avec
/// `isScrollControlled: true`. Le padding animé suit le clavier Android/iOS
/// afin que le champ et les actions restent toujours accessibles.
class SupportResolutionNoteDialog extends StatefulWidget {
  const SupportResolutionNoteDialog({super.key});

  @override
  State<SupportResolutionNoteDialog> createState() =>
      _SupportResolutionNoteDialogState();
}

class _SupportResolutionNoteDialogState
    extends State<SupportResolutionNoteDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _cancel() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
  }

  void _validateAndSubmit() {
    final String note = _controller.text.trim();
    if (note.length < 3) {
      setState(() {
        _errorText = 'Ajoutez une note de résolution.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(note);
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Material(
          color: AppColors.surfaceContainerHigh,
          elevation: 18,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
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
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Résoudre la demande',
                            style: TextStyle(
                              color: AppColors.onBackground,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Indiquez brièvement ce qui a été vérifié ou corrigé. Cette note restera dans l’historique.',
                            style: TextStyle(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      tooltip: 'Fermer',
                      onPressed: _cancel,
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.onSurfaceVariant,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Note de résolution',
                  style: TextStyle(
                    color: AppColors.onBackground,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  autofocus: false,
                  minLines: 3,
                  maxLines: 4,
                  maxLength: 1000,
                  textInputAction: TextInputAction.newline,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(
                    color: AppColors.inputText,
                    fontSize: 15,
                    height: 1.35,
                  ),
                  cursorColor: AppColors.primary,
                  decoration: InputDecoration(
                    hintText: 'Ex. : Paiement retrouvé et commande régularisée.',
                    hintStyle: const TextStyle(
                      color: AppColors.inputHint,
                      fontSize: 14,
                      height: 1.35,
                    ),
                    errorText: _errorText,
                    counterText: '',
                    alignLabelWithHint: true,
                    contentPadding: const EdgeInsets.all(14),
                  ),
                  onChanged: (_) {
                    if (_errorText != null) {
                      setState(() => _errorText = null);
                    } else {
                      setState(() {});
                    }
                  },
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${_controller.text.length}/1000',
                    style: const TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    if (constraints.maxWidth < 320) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton(
                            onPressed: _validateAndSubmit,
                            child: const Text('Valider'),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: _cancel,
                            child: const Text('Annuler'),
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _cancel,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              foregroundColor: AppColors.onSurfaceVariant,
                              side: BorderSide(
                                color: AppColors.outline.withAlpha(110),
                              ),
                            ),
                            child: const Text('Annuler'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: _validateAndSubmit,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                            ),
                            child: const Text('Valider'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
