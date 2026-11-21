import 'package:flutter/material.dart';
import 'package:cabine_flow/app/domain/entities/offers/admin_offer.dart';
import 'package:cabine_flow/app/domain/repositories/catalog_bonus_repository.dart';
import 'package:cabine_flow/app/modules/backoffice/widgets/backoffice_modal.dart';

const _networks = {'orange': 'Orange', 'mtn': 'MTN', 'moov': 'Moov'};
const _categories = {
  'maxit': 'MAXIT',
  'internet': 'Internet',
  'calls': 'Appel',
  'mixed': 'Mixte',
  'cchic': 'C’CHIC',
  'folie': 'Folie',
};
const _statuses = {
  'draft': 'Brouillon',
  'validated': 'Validé',
  'active': 'Actif',
  'suspended': 'Suspendu',
  'expired': 'Expiré',
  'archived': 'Archivé',
};

String _message(Object e) {
  final raw = e.toString();
  if (raw.contains('CONFLICT')) {
    return 'Une autre campagne couvre déjà cette offre sur ces horaires. Suspendez-la ou modifiez la période.';
  }
  if (raw.contains('VERSION_CHANGED') || raw.contains('rule_changed')) {
    return 'La configuration a changé. Actualisez avant de réessayer.';
  }
  if (raw.contains('VOLUME_MISMATCH')) {
    return 'Vérifiez les volumes structurés et les offres sélectionnées.';
  }
  if (raw.contains('VALIDATION_REQUIRED')) {
    return 'Validez la campagne avec sa référence opérateur avant de l’activer.';
  }
  if (raw.contains('EXPIRED')) {
    return 'La période de cette campagne est expirée.';
  }
  return 'Action indisponible. Vérifiez votre connexion, vos droits et la configuration serveur.';
}

Future<String?> _reference(BuildContext context) async {
  String value = '';
  final key = GlobalKey<FormState>();
  return showBackofficeModal<String>(
    context: context,
    builder: (context) => BackofficeModalShell(
      title: 'Confirmer la validation opérateur',
      subtitle:
          'Indiquez la source et le parcours vérifiés auprès de l’opérateur. Une génération de code ne prouve pas un achat.',
      body: Form(
        key: key,
        child: TextFormField(
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Référence opérateur et éléments vérifiés',
          ),
          onChanged: (text) => value = text.trim(),
          validator: (text) => (text?.trim().length ?? 0) < 10
              ? 'Indiquez au moins 10 caractères.'
              : null,
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () {
            if (key.currentState!.validate()) Navigator.pop(context, value);
          },
          child: const Text('Confirmer la validation'),
        ),
      ],
    ),
  );
}

class CatalogCampaignsDialog extends StatefulWidget {
  const CatalogCampaignsDialog({
    super.key,
    required this.repository,
    required this.offers,
  });
  final CatalogBonusRepository repository;
  final List<AdminOffer> offers;
  @override
  State<CatalogCampaignsDialog> createState() => _CampaignsState();
}

class _CampaignsState extends State<CatalogCampaignsDialog> {
  late Future<List<Map<String, dynamic>>> _future = widget.repository
      .campaigns();
  bool _busy = false;
  String? _error;
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) setState(() => _future = widget.repository.campaigns());
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? campaign]) async {
    final payload = await showBackofficeModal<Map<String, dynamic>>(
      context: context,
      builder: (_) =>
          _CampaignEditor(offers: widget.offers, campaign: campaign),
    );
    if (payload != null && mounted) {
      await _run(
        () => widget.repository.saveCampaign(
          payload,
          id: campaign?['id'] as String?,
          version: campaign?['version'] as int?,
        ),
      );
    }
  }

  Future<void> _status(Map<String, dynamic> campaign, String status) async {
    String? reference;
    if (status == 'validated') {
      reference = await _reference(context);
      if (reference == null || !mounted) return;
    }
    await _run(
      () => widget.repository.campaignStatus(
        campaign,
        status,
        reference: reference,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => BackofficeModalShell(
    title: 'Jours de bonus',
    maxWidth: 1000,
    subtitle:
        'Africa/Abidjan · Aucun prix modifié · Seules les campagnes validées puis actives sont publiques.',
    actions: [
      OutlinedButton(
        onPressed: _busy
            ? null
            : () => setState(() => _future = widget.repository.campaigns()),
        child: const Text('Actualiser'),
      ),
      FilledButton.icon(
        onPressed: _busy ? null : () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle campagne'),
      ),
    ],
    body: SizedBox(
      height: 500,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, s) {
                if (s.hasError) {
                  return const Center(
                    child: Text(
                      'Campagnes indisponibles. Vérifiez la migration serveur et vos droits.',
                    ),
                  );
                }
                if (!s.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (s.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aucune campagne configurée. Aucun bonus ne sera affiché sans validation.',
                    ),
                  );
                }
                return ListView(
                  children: s.data!
                      .map(
                        (c) => Card(
                          child: ListTile(
                            title: Text(
                              '${c['name']} · ${_networks[c['network']]}',
                            ),
                            subtitle: Text(
                              '${_statuses[c['effective_status']]} · ${(c['offers'] as List?)?.length ?? 0} offres\n${c['starts_at']} → ${c['ends_at']}\n${c['daily_start']}–${c['daily_end']} · jours ${(c['weekdays'] as List).join(', ')}',
                            ),
                            trailing: PopupMenuButton<String>(
                              enabled: !_busy,
                              onSelected: (action) {
                                if (action == 'edit') {
                                  _edit(c);
                                } else {
                                  _status(c, action);
                                }
                              },
                              itemBuilder: (_) => [
                                if (c['status'] != 'archived') ...[
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Modifier le brouillon'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'validated',
                                    child: Text(
                                      'Valider avec une référence opérateur',
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'active',
                                    child: Text('Activer'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'suspended',
                                    child: Text('Suspendre'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'archived',
                                    child: Text('Archiver'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _CampaignEditor extends StatefulWidget {
  const _CampaignEditor({required this.offers, this.campaign});
  final List<AdminOffer> offers;
  final Map<String, dynamic>? campaign;
  @override
  State<_CampaignEditor> createState() => _CampaignEditorState();
}

class _CampaignEditorState extends State<_CampaignEditor> {
  final _key = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  final _selected = <String>{};
  final _days = <int>{};
  String _network = 'orange', _kind = 'percentage';
  String? _category, _error;
  @override
  void initState() {
    super.initState();
    final c = widget.campaign;
    _network = c?['network'] as String? ?? 'orange';
    _kind = c?['bonus_kind'] as String? ?? 'percentage';
    _days.addAll((c?['weekdays'] as List? ?? []).cast<int>());
    _selected.addAll(
      (c?['offers'] as List? ?? []).map((v) => v['offer_id'] as String),
    );
    String date(String key) => c?[key] == null
        ? ''
        : DateTime.parse(
            c![key] as String,
          ).toUtc().toIso8601String().substring(0, 16).replaceFirst('T', ' ');
    final values = {
      'name': c?['name']?.toString() ?? '',
      'starts_at': date('starts_at'),
      'ends_at': date('ends_at'),
      'daily_start': c?['daily_start']?.toString().substring(0, 5) ?? '00:00',
      'daily_end': c?['daily_end']?.toString().substring(0, 5) ?? '00:00',
      'bonus_value': c?['bonus_value']?.toString() ?? '',
      'operator_reference': c?['operator_reference']?.toString() ?? '',
    };
    for (final e in values.entries) {
      _fields[e.key] = TextEditingController(text: e.value);
    }
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  num? _volume(AdminOffer o) {
    final d = o.importData;
    final n = num.tryParse(
      (d?['volume_data']?.toString() ?? '').replaceAll(',', '.'),
    );
    return switch (d?['unite_data']?.toString().toUpperCase()) {
      'MO' => n,
      'GO' => n == null ? null : n * 1000,
      _ => null,
    };
  }

  Widget _text(String key, String label, {bool optional = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: _fields[key],
      decoration: InputDecoration(labelText: label),
      validator: (v) =>
          !optional && (v?.trim().isEmpty ?? true) ? 'Champ obligatoire' : null,
    ),
  );
  void _save() {
    if (!_key.currentState!.validate()) return;
    try {
      final start = DateTime.parse(
        '${_fields['starts_at']!.text.trim().replaceFirst(' ', 'T')}Z',
      );
      final end = DateTime.parse(
        '${_fields['ends_at']!.text.trim().replaceFirst(' ', 'T')}Z',
      );
      final value = num.parse(
        _fields['bonus_value']!.text.replaceAll(',', '.'),
      );
      if (_days.isEmpty ||
          _selected.isEmpty ||
          !end.isAfter(start) ||
          value <= 0) {
        throw const FormatException();
      }
      if (!RegExp(
            r'^([01][0-9]|2[0-3]):[0-5][0-9]$',
          ).hasMatch(_fields['daily_start']!.text) ||
          !RegExp(
            r'^([01][0-9]|2[0-3]):[0-5][0-9]$',
          ).hasMatch(_fields['daily_end']!.text)) {
        throw const FormatException();
      }
      final targets = widget.offers
          .where((o) => _selected.contains(o.id))
          .map((o) => {'offer_id': o.id, 'base_volume_mb': _volume(o)})
          .toList();
      Navigator.pop(context, {
        'name': _fields['name']!.text.trim(),
        'network': _network,
        'weekdays': _days.toList()..sort(),
        'starts_at': start.toIso8601String(),
        'ends_at': end.toIso8601String(),
        'daily_start': _fields['daily_start']!.text,
        'daily_end': _fields['daily_end']!.text,
        'bonus_kind': _kind,
        'bonus_value': value,
        'operator_reference': _fields['operator_reference']!.text.trim(),
        'offers': targets,
      });
    } catch (_) {
      setState(
        () => _error =
            'Vérifiez dates, horaires, valeur, jours et sélection des offres.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => BackofficeModalShell(
    title: widget.campaign == null
        ? 'Nouvelle campagne'
        : 'Modifier la campagne',
    maxWidth: 850,
    subtitle:
        'Enregistrement en brouillon. Toute modification annule la validation précédente. Prix catalogue conservés.',
    actions: [
      FilledButton(
        onPressed: _save,
        child: const Text('Enregistrer le brouillon'),
      ),
    ],
    body: Form(
      key: _key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          _text('name', 'Nom de la campagne'),
          DropdownButtonFormField<String>(
            initialValue: _network,
            decoration: const InputDecoration(labelText: 'Opérateur'),
            items: _networks.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) => setState(() {
              _network = v!;
              _selected.clear();
            }),
          ),
          const SizedBox(height: 12),
          _text('starts_at', 'Début — AAAA-MM-JJ HH:mm (Africa/Abidjan)'),
          _text('ends_at', 'Fin — AAAA-MM-JJ HH:mm (Africa/Abidjan)'),
          _text('daily_start', 'Heure de début — HH:mm'),
          _text('daily_end', 'Heure de fin — HH:mm ; heures identiques = 24 h'),
          const Text(
            'Jours de début de promotion (une plage peut traverser minuit)',
          ),
          Wrap(
            spacing: 6,
            children: [
              for (final d in const {
                1: 'Lun',
                2: 'Mar',
                3: 'Mer',
                4: 'Jeu',
                5: 'Ven',
                6: 'Sam',
                7: 'Dim',
              }.entries)
                FilterChip(
                  label: Text(d.value),
                  selected: _days.contains(d.key),
                  onSelected: (v) => setState(() {
                    v ? _days.add(d.key) : _days.remove(d.key);
                  }),
                ),
            ],
          ),
          DropdownButtonFormField<String>(
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Type de bonus'),
            items: const [
              DropdownMenuItem(
                value: 'percentage',
                child: Text('Bonus calculé — pourcentage ajouté'),
              ),
              DropdownMenuItem(
                value: 'added_mb',
                child: Text('Volume ajouté — Mo'),
              ),
              DropdownMenuItem(
                value: 'total_mb',
                child: Text('Volume garanti final — Mo'),
              ),
            ],
            onChanged: (v) => setState(() => _kind = v!),
          ),
          const SizedBox(height: 12),
          _text(
            'bonus_value',
            _kind == 'percentage'
                ? 'Bonus ajouté (%)'
                : 'Volume en Mo (1 Go = 1 000 Mo)',
          ),
          _text(
            'operator_reference',
            'Référence opérateur (la validation reste une action distincte)',
            optional: true,
          ),
          DropdownButtonFormField<String>(
            initialValue: _category ?? '',
            decoration: const InputDecoration(
              labelText: 'Filtrer les offres par catégorie',
            ),
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('Toutes les catégories'),
              ),
              ..._categories.entries.map(
                (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
              ),
            ],
            onChanged: (v) => setState(() => _category = v!.isEmpty ? null : v),
          ),
          const SizedBox(height: 12),
          Text(
            '${_selected.length} offres sélectionnées · le filtre ne définit pas l’éligibilité',
          ),
          SizedBox(
            height: 230,
            child: Material(
              color: Colors.transparent,
              child: ListView(
                children: widget.offers
                    .where(
                      (o) =>
                          o.isActive &&
                          o.network.name == _network &&
                          (_category == null || o.category == _category),
                    )
                    .map(
                      (o) => CheckboxListTile(
                        value: _selected.contains(o.id),
                        title: Text(o.title),
                        subtitle: Text(
                          '${o.category.toUpperCase()} · ${o.sellingPrice} FCFA · ${_volume(o) ?? 'volume structuré absent'} Mo',
                        ),
                        onChanged: _volume(o) == null
                            ? null
                            : (v) => setState(() {
                                v == true
                                    ? _selected.add(o.id)
                                    : _selected.remove(o.id);
                              }),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class CatalogRoutesDialog extends StatefulWidget {
  const CatalogRoutesDialog({
    super.key,
    required this.repository,
    required this.canValidate,
  });
  final CatalogBonusRepository repository;
  final bool canValidate;
  @override
  State<CatalogRoutesDialog> createState() => _RoutesState();
}

class _RoutesState extends State<CatalogRoutesDialog> {
  late Future<List<Map<String, dynamic>>> _future = widget.repository.routes();
  bool _busy = false;
  String? _error;
  Future<void> _validate(Map<String, dynamic> row, bool operator) async {
    final reference = operator ? await _reference(context) : null;
    if (!mounted || (operator && reference == null)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.validateRoute(row, operatorReference: reference);
      if (mounted) setState(() => _future = widget.repository.routes());
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => BackofficeModalShell(
    title: 'Souscriptions par catégorie',
    maxWidth: 1100,
    subtitle:
        'Une syntaxe configurée ne confirme aucun achat. Internet et Mixte Moov restent à valider chez l’opérateur.',
    body: SizedBox(
      height: 530,
      child: Column(
        children: [
          if (_error != null) Text(_error!),
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, s) {
                if (s.hasError) {
                  return const Center(
                    child: Text(
                      'Routage indisponible. Vérifiez la migration et vos droits.',
                    ),
                  );
                }
                if (!s.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView(
                  children: s.data!
                      .map(
                        (r) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_networks[r['network']]} · ${_categories[r['category']]} · ${r['offers']} offres',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                SelectableText(r['action'] as String),
                                Text(
                                  'Configuré : ${r['configured'] == true ? 'oui' : 'non'} · Validé techniquement : ${r['technical_validated_at'] != null ? 'oui' : 'non'}',
                                ),
                                Text(
                                  r['operator_validated_at'] == null
                                      ? 'Validation opérateur nécessaire'
                                      : 'Validé chez l’opérateur · ${r['operator_reference']}',
                                ),
                                if (widget.canValidate)
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _validate(r, false),
                                        child: const Text(
                                          'Tester la génération',
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _validate(r, true),
                                        child: const Text(
                                          'Valider chez l’opérateur',
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
