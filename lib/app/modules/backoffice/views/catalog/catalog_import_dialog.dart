import 'dart:convert';
import 'dart:math';
import 'package:cabine_flow/app/domain/entities/offers/admin_offer.dart';
import 'package:cabine_flow/app/domain/entities/offers/catalog_import.dart';
import 'package:cabine_flow/app/domain/repositories/catalog_import_repository.dart';
import 'package:cabine_flow/app/theme/backoffice_theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

const _kindLabels = <String, String>{
  'create': 'Créations',
  'update': 'Mises à jour',
  'deactivate': 'Désactivations',
  'unchanged': 'Inchangées',
  'error': 'Erreurs',
  'conflict': 'Conflits',
};

/// Uses the existing BO dialog surface, typography, buttons and spacing.
class CatalogPanelDialog extends StatelessWidget {
  const CatalogPanelDialog({
    super.key,
    required this.title,
    required this.child,
    required this.actions,
    this.busy = false,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final bool busy;
  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): () {
        if (!busy) Navigator.of(context).maybePop();
      },
    },
    child: Focus(
      autofocus: true,
      skipTraversal: true,
      child: PopScope(
        canPop: !busy,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980, maxHeight: 820),
            child: RepaintBoundary(
              key: const ValueKey('catalog-dialog-surface'),
              child: Container(
                decoration: backofficePanelDecoration(
                  radius: 22,
                  elevated: true,
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 20, 14, 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: BackofficePalette.primarySoft,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Symbols.local_offer_rounded,
                                color: BackofficePalette.primaryStrong,
                                fill: 1,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  if (subtitle != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      subtitle!,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Fermer',
                              onPressed: busy
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              icon: const Icon(Symbols.close_rounded),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      if (busy) const LinearProgressIndicator(minHeight: 2),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                          child: child,
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            alignment: WrapAlignment.end,
                            children: actions,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget catalogNotice(String text, {bool error = false}) => Container(
  margin: const EdgeInsets.symmetric(vertical: 10),
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
    color: (error ? BackofficePalette.danger : BackofficePalette.primary)
        .withValues(alpha: .055),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: (error ? BackofficePalette.danger : BackofficePalette.primary)
          .withValues(alpha: .16),
    ),
  ),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        error ? Symbols.error_rounded : Symbols.info_rounded,
        color: error ? BackofficePalette.danger : BackofficePalette.primary,
        size: 20,
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(text)),
    ],
  ),
);

class CatalogImportDialog extends StatefulWidget {
  const CatalogImportDialog({
    super.key,
    required this.repository,
    this.importId,
  });
  final CatalogImportRepository repository;
  final String? importId;
  @override
  State<CatalogImportDialog> createState() => _CatalogImportDialogState();
}

class _CatalogImportDialogState extends State<CatalogImportDialog> {
  CatalogImportPage? _page;
  bool _busy = false, _partial = false, _confirmed = false, _changed = false;
  int _step = 0, _offset = 0;
  String _filter = 'all';
  String? _error, _requestId, _fileName;
  Uint8List? _bytes;
  @override
  void initState() {
    super.initState();
    if (widget.importId != null) {
      _requestId = widget.importId;
      _load(widget.importId!);
    }
  }

  Future<void> _guard(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
    } catch (error) {
      if (mounted) setState(() => _error = catalogImportError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load(String id) => _guard(() async {
    final value = await widget.repository.importPage(
      id,
      offset: _offset,
      filter: _filter,
    );
    if (mounted) {
      setState(() {
        _page = value;
        _step = value.status == 'preview' ? 1 : 3;
      });
    }
  });
  Future<void> _pick() async {
    if (_busy) return;
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Importer les offres IzyTel',
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
      );
      if (file == null) return;
      if (await file.length() > 5 * 1024 * 1024) {
        throw const FormatException('CATALOG_FILE_TOO_LARGE');
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      _bytes = bytes;
      _fileName = file.name;
      _requestId = newCatalogImportId();
      await _prepare();
    } catch (error) {
      if (mounted) setState(() => _error = catalogImportError(error));
    }
  }

  Future<void> _prepare() => _guard(() async {
    final id = await widget.repository.prepareImport(
      bytes: _bytes!,
      fileName: _fileName!,
      requestId: _requestId!,
    );
    final value = await widget.repository.importPage(id);
    if (mounted) {
      setState(() {
        _page = value;
        _step = value.status == 'preview' ? 1 : 3;
        _offset = 0;
        _filter = 'all';
        _partial = false;
        _confirmed = false;
      });
    }
  });
  Future<void> _downloadTemplate() => _guard(() async {
    final data = await rootBundle.load(
      'assets/templates/Modele_import_offres_IzyTel.xlsx',
    );
    await FilePicker.saveFile(
      dialogTitle: 'Modèle des offres IzyTel',
      fileName: 'Modele_import_offres_IzyTel.xlsx',
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      bytes: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  });
  Future<void> _run() => _guard(() async {
    var value = _page!;
    if (value.status == 'preview') {
      value = await widget.repository.confirmImport(
        value.id,
        allowPartial: _partial,
      );
    }
    if (mounted) {
      setState(() {
        _page = value;
        _step = 3;
        _changed = true;
      });
    }
    while (mounted && value.status == 'running') {
      value = await widget.repository.applyImportBatch(value.id);
      if (mounted) setState(() => _page = value);
    }
  });
  Future<void> _report() => _guard(() async {
    final current = _page!;
    final lines = <Map<String, dynamic>>[];
    for (var offset = 0; offset < current.total; offset += 20) {
      final chunk = await widget.repository.importPage(
        current.id,
        offset: offset,
      );
      lines.addAll(chunk.lines);
    }
    await FilePicker.saveFile(
      dialogTitle: 'Rapport d’import',
      fileName: 'import-${current.id}.json',
      mimeType: 'application/json',
      bytes: Uint8List.fromList(utf8.encode(catalogReportJson(current, lines))),
    );
  });
  Future<void> _restore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurer cette révision ?'),
        content: const Text(
          'Les anciennes valeurs seront restaurées. Les offres créées par ce lot deviendront inactives, sans suppression. Les commandes et les mouvements financiers sont conservés. Toute modification ultérieure d’une offre bloque la restauration.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _guard(() async {
      final value = await widget.repository.restoreImport(_page!.id);
      if (mounted) {
        setState(() {
          _page = value;
          _changed = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    return CatalogPanelDialog(
      title: 'Importer des offres',
      subtitle:
          'Validation serveur, aperçu des écarts et confirmation explicite.',
      busy: _busy,
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, _changed),
          child: Text(_step == 3 ? 'Revenir au catalogue' : 'Fermer'),
        ),
        if (_step == 1)
          FilledButton(
            onPressed: _busy || (page!.count('error') > 0 && !_partial)
                ? null
                : () => setState(() => _step = 2),
            child: const Text('Continuer'),
          ),
        if (_step == 2)
          OutlinedButton(
            onPressed: _busy ? null : () => setState(() => _step = 1),
            child: const Text('Revoir l’aperçu'),
          ),
        if (_step == 2)
          FilledButton(
            onPressed: _busy || !_confirmed ? null : _run,
            child: const Text('Confirmer l’import'),
          ),
        if (_step == 3 && page?.status == 'running')
          FilledButton(
            onPressed: _busy ? null : _run,
            child: const Text('Reprendre le traitement'),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (var index = 0; index < 4; index++)
                Chip(
                  backgroundColor: _step == index
                      ? BackofficePalette.primarySoft
                      : null,
                  label: Text(
                    '${index + 1}. ${['Fichier', 'Aperçu', 'Confirmation', 'Résultat'][index]}',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_error != null) catalogNotice(_error!, error: true),
          if (_step == 0) ...[
            catalogNotice(
              'Seule la feuille OFFRES est importée. GUIDE, REFERENTIEL et EXEMPLES_MAJ sont ignorées. Maximum : 5 Mo, 20 Mo décompressés, 5 000 offres. Aucune formule ni macro.',
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: backofficePanelDecoration(),
              child: Column(
                children: [
                  const Icon(
                    Symbols.upload_file_rounded,
                    size: 40,
                    color: BackofficePalette.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _fileName ?? 'Choisissez un fichier XLSX',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _busy ? null : _pick,
                    icon: const Icon(Symbols.folder_open_rounded),
                    label: const Text('Choisir un fichier'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _busy ? null : _downloadTemplate,
                    icon: const Icon(Symbols.download_rounded),
                    label: const Text('Télécharger le modèle'),
                  ),
                ],
              ),
            ),
            catalogNotice(
              'Le modèle contient 40 propositions en brouillon, non vérifiées. Les offres absentes du fichier restent intactes. Le code offre est permanent ; les prix opérateurs excluent les frais IzyTel du paiement.',
            ),
            if (_requestId != null) ...[
              SelectableText(
                'Identifiant de reprise : $_requestId',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_bytes != null)
                TextButton(
                  onPressed: _busy ? null : _prepare,
                  child: const Text('Réessayer la même préparation'),
                ),
            ],
          ],
          if (page != null && _step > 0) ...[
            Text(
              page.job['file_name'].toString(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _summary(page),
            if (_step == 1) ...[
              catalogNotice(
                'Aucune modification d’offre pendant cet aperçu. Une ligne identique ne produit pas d’écriture. Les doublons de code sont tous bloqués.',
              ),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Text('${page.total} lignes dans OFFRES'),
                  SizedBox(
                    width: 210,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(_filter),
                      initialValue: _filter,
                      decoration: const InputDecoration(labelText: 'Résultats'),
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('Toutes les lignes'),
                        ),
                        for (final entry in _kindLabels.entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) {
                              _filter = value ?? 'all';
                              _offset = 0;
                              _load(page.id);
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _lines(page),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_offset + 1}–${min(_offset + page.lines.length, page.filteredTotal)} sur ${page.filteredTotal}',
                    ),
                  ),
                  IconButton(
                    tooltip: 'Page précédente',
                    onPressed: _busy || _offset == 0
                        ? null
                        : () {
                            _offset = max(0, _offset - 20);
                            _load(page.id);
                          },
                    icon: const Icon(Symbols.chevron_left_rounded),
                  ),
                  IconButton(
                    tooltip: 'Page suivante',
                    onPressed: _busy || _offset + 20 >= page.filteredTotal
                        ? null
                        : () {
                            _offset += 20;
                            _load(page.id);
                          },
                    icon: const Icon(Symbols.chevron_right_rounded),
                  ),
                ],
              ),
              if (page.count('error') > 0)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _partial,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _partial = value ?? false),
                  title: const Text('Traiter uniquement les lignes valides'),
                  subtitle: Text(
                    '${page.count('error')} lignes seront exclues. Les codes concernés restent inchangés.',
                  ),
                ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _step = 0;
                        _page = null;
                        _confirmed = false;
                      }),
                child: const Text('Choisir un autre fichier'),
              ),
            ],
            if (_step == 2) ...[
              catalogNotice(
                '${page.changes} changements proposés, ${page.count('error')} lignes exclues. Les IDs, les dates de création et les commandes historiques sont conservés. Les lots déjà appliqués ne sont pas annulés en cas de perte réseau.',
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _confirmed,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _confirmed = value ?? false),
                title: const Text(
                  'Je confirme ces changements et le périmètre des lignes exclues.',
                ),
                subtitle: const Text(
                  'L’autorisation, les valeurs et les versions seront de nouveau vérifiées côté serveur.',
                ),
              ),
            ],
            if (_step == 3) ...[
              const SizedBox(height: 14),
              Text(
                page.status == 'restored'
                    ? 'Révision restaurée'
                    : page.status == 'completed'
                    ? 'Traitement terminé'
                    : 'Import reprenable',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: page.cursor / page.total),
              const SizedBox(height: 8),
              Text(
                '${page.cursor} / ${page.total} lignes examinées · ${page.count('applied')} changements appliqués · ${page.count('conflict')} conflits',
              ),
              const SizedBox(height: 8),
              SelectableText(
                'Import : ${page.id}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (page.count('conflict') > 0)
                catalogNotice(
                  'Des offres ont changé depuis l’aperçu ou ne respectent plus les règles de publication. Elles n’ont pas été écrasées. Téléchargez le rapport pour les détails.',
                  error: true,
                ),
              catalogNotice(
                page.status == 'running'
                    ? 'Le même identifiant retrouve les lots déjà appliqués. Vous pouvez fermer puis reprendre depuis l’historique.'
                    : 'Les commandes et mouvements financiers sont conservés. La restauration enregistre une révision compensatoire.',
              ),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _report,
                    icon: const Icon(Symbols.download_rounded),
                    label: const Text('Télécharger le rapport'),
                  ),
                  if (page.status == 'completed' && page.count('applied') > 0)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _restore,
                      icon: const Icon(Symbols.history_rounded),
                      label: const Text('Restaurer la version précédente'),
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _summary(CatalogImportPage page) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final key in [
        'create',
        'update',
        'deactivate',
        'unchanged',
        'error',
      ])
        Chip(
          label: Text('${page.count(key)} ${_kindLabels[key]}'),
          backgroundColor: key == 'error' && page.count(key) > 0
              ? BackofficePalette.danger.withValues(alpha: .08)
              : null,
        ),
    ],
  );
  Widget _lines(CatalogImportPage page) => Column(
    children: page.lines.map((line) {
      final changes = catalogMap(line['changes']),
          errors = (line['errors'] as List? ?? const [])
              .map((e) => e.toString())
              .toList();
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: backofficePanelDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                Text(
                  'Ligne ${line['line_number']} · ${line['code']}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  _kindLabels[line['kind']] ?? line['kind'].toString(),
                  style: TextStyle(
                    color: errors.isEmpty
                        ? BackofficePalette.primary
                        : BackofficePalette.danger,
                  ),
                ),
              ],
            ),
            if (line['kind'] == 'create')
              Text(
                '${catalogMap(line['data'])['nom_affiche']} · ${catalogMap(line['data'])['prix_fcfa']} FCFA · ${catalogMap(line['data'])['statut']}',
              ),
            for (final change in changes.entries)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${change.key} : ${catalogMap(change.value)['before'] ?? 'vide'} → ${catalogMap(change.value)['after'] ?? 'vide'}',
                ),
              ),
            for (final error in errors)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  error,
                  style: const TextStyle(color: BackofficePalette.danger),
                ),
              ),
            if (line['kind'] == 'unchanged')
              const Text('Aucun champ modifié · aucune écriture.'),
          ],
        ),
      );
    }).toList(),
  );
}

String newCatalogImportId() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final value = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${value.substring(0, 8)}-${value.substring(8, 12)}-${value.substring(12, 16)}-${value.substring(16, 20)}-${value.substring(20)}';
}

Future<void> showCatalogImportHistory(
  BuildContext context,
  CatalogImportRepository repository,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _CatalogHistoryDialog(repository: repository),
  );
}

class _CatalogHistoryDialog extends StatefulWidget {
  const _CatalogHistoryDialog({required this.repository});
  final CatalogImportRepository repository;
  @override
  State<_CatalogHistoryDialog> createState() => _CatalogHistoryDialogState();
}

class _CatalogHistoryDialogState extends State<_CatalogHistoryDialog> {
  late Future<List<Map<String, dynamic>>> _future;
  int _offset = 0;
  @override
  void initState() {
    super.initState();
    _future = widget.repository.importHistory();
  }

  void _load() {
    setState(() => _future = widget.repository.importHistory(offset: _offset));
  }

  @override
  Widget build(BuildContext context) => CatalogPanelDialog(
    title: 'Historique des imports',
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Fermer'),
      ),
    ],
    child: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Column(
            children: [
              catalogNotice(catalogImportError(snapshot.error!), error: true),
              TextButton(onPressed: _load, child: const Text('Réessayer')),
            ],
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snapshot.data!;
        return Column(
          children: [
            if (rows.isEmpty) const Text('Aucun import à afficher.'),
            for (final row in rows)
              ListTile(
                contentPadding: EdgeInsets.zero,
                isThreeLine: true,
                title: Text(row['file_name'].toString()),
                subtitle: Text(
                  '${row['id']}\n${row['created_at']} · ${row['status']} · ${row['cursor']}/${row['total']}',
                ),
                trailing: const Icon(Symbols.chevron_right_rounded),
                onTap: () async {
                  await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => CatalogImportDialog(
                      repository: widget.repository,
                      importId: row['id'].toString(),
                    ),
                  );
                  if (mounted) _load();
                },
              ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: _offset == 0
                      ? null
                      : () {
                          _offset = max(0, _offset - 20);
                          _load();
                        },
                  child: const Text('Précédent'),
                ),
                TextButton(
                  onPressed: rows.length < 20
                      ? null
                      : () {
                          _offset += 20;
                          _load();
                        },
                  child: const Text('Suivant'),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

Future<void> showCatalogOfferHistory(
  BuildContext context,
  CatalogImportRepository repository,
  AdminOffer offer,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => CatalogPanelDialog(
      title: 'Historique de l’offre',
      subtitle: offer.stableCode,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: repository.offerHistory(offer.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return catalogNotice(
              catalogImportError(snapshot.error!),
              error: true,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              for (final event in snapshot.data!)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(event['action'].toString()),
                  subtitle: Text(
                    '${event['created_at']} · ${event['actor_name']}',
                  ),
                ),
              if (snapshot.data!.isEmpty)
                const Text('Aucune révision enregistrée.'),
            ],
          );
        },
      ),
    ),
  );
}
