import 'package:cabine_flow/app/domain/entities/orders/queue_order.dart';
import 'package:cabine_flow/app/domain/repositories/order_requeue_repository.dart';
import 'package:flutter/material.dart';

/// Returns null on cancellation. Verification is always an explicit staff action.
Future<QueueOrder?> returnOrderToSharedQueue(
  BuildContext context,
  OrderRequeueRepository repository,
  QueueOrder order,
) async {
  final reason = await _reason(
    context,
    'Remettre dans la file d’attente',
    'La commande ${order.reference} sera proposée aux Agents de sa zone.',
    'Remettre dans la file',
  );
  if (reason == null || !context.mounted) return null;
  try {
    return await repository.returnOrderToQueue(
      orderId: order.id,
      reason: reason,
    );
  } catch (error) {
    if (!error.toString().contains('EXECUTION_REQUIRES_MANAGER_VERIFICATION') ||
        !context.mounted) {
      rethrow;
    }
    final verification = await _reason(
      context,
      'Vérification préalable obligatoire',
      'Le traitement a pu commencer. Vérifiez son résultat auprès de l’Agent et de l’opérateur. '
          'Continuez uniquement si vous avez confirmé qu’aucune opération n’a été exécutée. '
          'Indiquez les éléments vérifiés.',
      'J’ai vérifié : aucune exécution',
      minimum: 10,
    );
    if (verification == null || !context.mounted) return null;
    await repository.verifyOrderNotExecuted(
      orderId: order.id,
      reason: verification,
      assignmentVersion: order.assignmentVersion,
    );
    return repository.returnOrderToQueue(orderId: order.id, reason: reason);
  }
}

Future<String?> _reason(
  BuildContext context,
  String title,
  String explanation,
  String action, {
  int minimum = 3,
}) async {
  String enteredReason = '';
  final key = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Form(
        key: key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(explanation),
            const SizedBox(height: 16),
            TextFormField(
              onChanged: (value) => enteredReason = value,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Motif'),
              validator: (value) => (value?.trim().length ?? 0) < minimum
                  ? 'Précisez le motif ($minimum caractères minimum).'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            if (key.currentState!.validate()) {
              Navigator.pop(context, enteredReason.trim());
            }
          },
          child: Text(action),
        ),
      ],
    ),
  );
}
