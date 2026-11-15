import 'package:cabine_flow/app/domain/entities/offers/admin_offer.dart';
import 'package:cabine_flow/app/domain/entities/offers/catalog_import.dart';
import 'package:cabine_flow/app/domain/repositories/catalog_import_repository.dart';
import 'package:cabine_flow/app/modules/backoffice/views/catalog/catalog_import_dialog.dart';
import 'package:flutter/material.dart';

class CatalogBulkDialog extends StatefulWidget {
  const CatalogBulkDialog({
    super.key,
    required this.repository,
    required this.offers,
  });
  final CatalogImportRepository repository;
  final List<AdminOffer> offers;
  @override
  State<CatalogBulkDialog> createState() => _CatalogBulkDialogState();
}

class _CatalogBulkDialogState extends State<CatalogBulkDialog> {
  String _operation = 'deactivate', _requestId = newCatalogImportId();
  final _value = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CatalogPanelDialog(
    title: 'Modifier la sélection',
    subtitle:
        '${widget.offers.length} offres · aperçu obligatoire avant toute écriture',
    busy: _busy,
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: _busy ? null : _preview,
        child: const Text('Voir les impacts'),
      ),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) catalogNotice(_error!, error: true),
        DropdownButtonFormField<String>(
          initialValue: _operation,
          decoration: const InputDecoration(labelText: 'Modification'),
          items: const [
            DropdownMenuItem(value: 'deactivate', child: Text('Désactiver')),
            DropdownMenuItem(value: 'activate', child: Text('Activer')),
            DropdownMenuItem(
              value: 'family',
              child: Text('Changer de famille'),
            ),
            DropdownMenuItem(
              value: 'priority',
              child: Text('Changer de priorité'),
            ),
          ],
          onChanged: _busy
              ? null
              : (value) => setState(() {
                  _operation = value!;
                  _requestId = newCatalogImportId();
                }),
        ),
        if (['family', 'priority'].contains(_operation))
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: TextField(
              controller: _value,
              onChanged: (_) => _requestId = newCatalogImportId(),
              decoration: InputDecoration(
                labelText: _operation == 'family'
                    ? 'Code de famille'
                    : 'Priorité (entier positif ou nul)',
              ),
            ),
          ),
        catalogNotice(
          'Les données commerciales, la compatibilité des familles et les versions seront contrôlées côté serveur. Les offres historiques non structurées doivent être complétées dans leur fiche avant activation ou changement de famille.',
        ),
        for (final offer in widget.offers)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(offer.title),
            subtitle: Text('${offer.stableCode} · ${offer.statusLabel}'),
          ),
      ],
    ),
  );
  Future<void> _preview() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await widget.repository.prepareBulk(
        requestId: _requestId,
        operation: _operation,
        value: _value.text.trim(),
        items: widget.offers
            .map(
              (offer) => <String, dynamic>{
                'id': offer.id,
                'version': offer.catalogVersion,
              },
            )
            .toList(),
      );
      if (mounted) Navigator.pop(context, id);
    } catch (error) {
      if (mounted) setState(() => _error = catalogImportError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
