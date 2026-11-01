part of 'backoffice_ussd_page.dart';

class _UssdBindingDeletion {
  const _UssdBindingDeletion({
    required this.offerId,
    required this.version,
    required this.title,
  });
  final String offerId, title;
  final int version;
}

class _UssdDeleteConfirmation extends StatelessWidget {
  const _UssdDeleteConfirmation({
    required this.title,
    required this.description,
    required this.detail,
    this.template,
  });
  final String title, description, detail;
  final String? template;

  @override
  Widget build(BuildContext context) => BackofficeModalShell(
    title: title,
    icon: Icons.delete_outline,
    iconColor: Theme.of(context).colorScheme.error,
    maxWidth: 600,
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Annuler'),
      ),
      FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
          foregroundColor: Theme.of(context).colorScheme.onError,
        ),
        onPressed: () => Navigator.pop(context, true),
        icon: const Icon(Icons.delete_outline),
        label: const Text('Confirmer la suppression'),
      ),
    ],
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(detail, style: Theme.of(context).textTheme.titleMedium),
        if (template != null) ...[
          const SizedBox(height: 12),
          SelectableText(
            template!,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ],
        const SizedBox(height: 16),
        Text(description),
      ],
    ),
  );
}

class _UssdFamilyManager extends StatelessWidget {
  const _UssdFamilyManager({required this.families});
  final List<Map<String, dynamic>> families;

  @override
  Widget build(BuildContext context) => BackofficeModalShell(
    title: 'Gérer les familles',
    icon: Icons.folder_outlined,
    maxWidth: 700,
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Fermer'),
      ),
    ],
    body: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Sélectionnez la famille à supprimer. Les familles encore utilisées sont protégées.',
        ),
        const SizedBox(height: 16),
        if (families.isEmpty) const Text('Aucune famille créée.'),
        for (final family in families)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        family['label'] as String,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        '${ussdNetworks[family['network']]} · ${ussdServices[family['service']]}',
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Supprimer la famille ${family['label']}',
                  onPressed: () => Navigator.pop(context, family),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
