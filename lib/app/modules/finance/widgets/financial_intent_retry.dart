import 'package:flutter/material.dart';

/// Reuses the caller's captured draft for every explicit retry.
Future<T> runFinancialIntent<T>(
  BuildContext context,
  Future<T> Function() action, {
  required bool canRetry,
}) async {
  while (true) {
    try {
      return await action();
    } catch (error) {
      if (!canRetry || !context.mounted) rethrow;
      final retry = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Opération non confirmée'),
          content: Text(
            '$error\n\nRéessayer reprend la même opération. Avant une nouvelle saisie, vérifiez son historique.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Fermer'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
      if (retry != true || !context.mounted) rethrow;
    }
  }
}
