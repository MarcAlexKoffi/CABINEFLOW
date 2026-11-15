import 'dart:async';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/ussd/data/supabase_ussd_repository.dart';
import 'package:cabine_flow/features/ussd/domain/ussd_engine.dart';
import 'package:cabine_flow/features/ussd/domain/ussd_repository.dart';
import 'package:cabine_flow/features/ussd/presentation/ussd_activity_page.dart';
import 'package:flutter/material.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';

const ussdNetworks = {'orange': 'Orange', 'mtn': 'MTN', 'moov': 'Moov Africa'};
const ussdServices = {
  'internetSubscription': 'Internet',
  'callBundle': 'Appels',
  'unitTransfer': 'Recharge / transfert d’unités',
  'sms': 'SMS',
  'mixedBundle': 'Offres mixtes',
  'other': 'Autre',
};
const ussdScopes = {
  'agent': 'Agent',
  'cabiniste': 'Cabiniste',
  'both': 'Agent et Cabiniste',
};
const ussdStatuses = {
  'draft': 'Brouillon',
  'active': 'Actif',
  'disabled': 'Désactivé',
};

class BackofficeUssdPage extends StatefulWidget {
  const BackofficeUssdPage({super.key, required this.user, this.repository});
  final AppUser user;
  final UssdRepository? repository;
  @override
  State<BackofficeUssdPage> createState() => _BackofficeUssdPageState();
}

class _BackofficeUssdPageState extends State<BackofficeUssdPage> {
  late final UssdRepository _repository =
      widget.repository ?? createUssdRepository();
  late Future<Map<String, dynamic>> _future;
  Timer? _refresh;
  String _network = '', _service = '', _family = '', _status = '', _scope = '';
  bool _busy = false;
  bool get _admin => widget.user.role == UserRole.administrator;
  @override
  void initState() {
    super.initState();
    _future = _repository.configuration();
    _refresh = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted && !_busy && (ModalRoute.of(context)?.isCurrent ?? true)) {
        _reload();
      }
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  void _reload() {
    final future = _repository.configuration();
    setState(() {
      _future = future;
    });
  }

  List<Map<String, dynamic>> _rows(Object? value) => (value as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) _reload();
    } catch (e) {
      if (mounted) _notice(_error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notice(String text) => IzyTelFeedback.error(context, text);
  String _error(Object error) {
    if (error is TimeoutException) {
      return 'Réponse non reçue. Actualisez avant de réessayer pour éviter un doublon.';
    }
    final text = error.toString();
    for (final code in [
      'ambiguous_rule',
      'invalid_template',
      'unknown_variable',
      'rule_changed',
    ]) {
      if (text.contains(code)) return UssdEngine.message(code);
    }
    if (text.contains('active_binding_in_use')) {
      return 'Désactivez les règles concernées avant de modifier cette association.';
    }
    if (text.contains('missing_offer_context')) {
      return 'Renseignez le code opérateur et la quantité nécessaires pour chaque offre concernée.';
    }
    if (text.contains('invalid_association')) {
      return 'L’offre ou la famille ne correspond pas au réseau et au service.';
    }
    if (text.contains('sim_validation_required')) {
      return 'Une validation humaine sur la SIM concernée est obligatoire.';
    }
    if (text.contains('unsupported_order_service')) {
      return 'Ce service n’est pas encore proposé aux commandes. Conservez la règle en brouillon.';
    }
    return 'Action indisponible. Vérifiez votre connexion et vos droits d’accès, puis réessayez.';
  }

  Future<void> _edit(Map<String, dynamic> data, [UssdRule? rule]) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _RuleEditor(
        rule: rule,
        families: _rows(data['families']),
        offers: _rows(data['offers']),
      ),
    );
    if (payload == null || !mounted) return;
    await _run(
      () => _repository.saveRule(payload, id: rule?.id, version: rule?.version),
    );
  }

  Future<void> _statusChange(UssdRule rule) async {
    String? sim;
    if (rule.status != 'active') {
      sim = await showDialog<String>(
        context: context,
        builder: (_) => const _ActivationDialog(),
      );
      if (sim == null || !mounted) return;
    } else {
      final agreed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Désactiver le raccourci ?'),
          content: const Text(
            'Les nouveaux lancements seront refusés. Le traitement manuel reste disponible.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Désactiver'),
            ),
          ],
        ),
      );
      if (agreed != true || !mounted) return;
    }
    await _run(
      () => _repository.setStatus(
        rule,
        rule.status == 'active' ? 'disabled' : 'active',
        simType: sim,
      ),
    );
  }

  void _history(UssdRule rule) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Historique des versions'),
        content: SizedBox(
          width: 650,
          height: 460,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _repository.history(rule.id),
            builder: (_, snapshot) {
              if (snapshot.hasError) {
                return const Text('Historique indisponible.');
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView(
                children: snapshot.data!
                    .map(
                      (r) => ListTile(
                        title: SelectableText(
                          'V${r['version']} · ${ussdStatuses[r['status']] ?? r['status']} · ${r['ussd_template']}',
                        ),
                        subtitle: Text(
                          '${r['updated_at']} · ${r['updated_by']}\nValidation SIM : ${r['validation_sim_type'] ?? 'non validée'} · ${r['validated_at'] ?? ''}',
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _familyDialog() async {
    final value = await showDialog<(String, String, String)>(
      context: context,
      builder: (_) => const _FamilyEditor(),
    );
    if (value != null && mounted) {
      await _run(() => _repository.saveFamily(value.$1, value.$2, value.$3));
    }
  }

  Future<void> _bindingDialog(Map<String, dynamic> data) async {
    final value = await showDialog<(String, String?, String?, int?)>(
      context: context,
      builder: (_) => _BindingEditor(
        offers: _rows(data['offers']),
        families: _rows(data['families']),
        onHistory: _bindingHistory,
      ),
    );
    if (value != null && mounted) {
      await _run(
        () => _repository.saveBinding(value.$1, value.$2, value.$3, value.$4),
      );
    }
  }

  void _activity({required bool reports}) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => UssdActivityPage(
        user: widget.user,
        repository: _repository,
        reports: reports,
      ),
    ),
  );

  void _bindingHistory(String offerId) {
    final future = _repository.bindingHistory(offerId);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Historique de l’association offre'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: future,
            builder: (_, snapshot) {
              if (snapshot.hasError) {
                return const Text('Historique indisponible.');
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.isEmpty) {
                return const Text('Aucune association enregistrée.');
              }
              return ListView(
                children: snapshot.data!
                    .map(
                      (r) => ListTile(
                        title: Text(
                          'V${r['version']} · code offre : ${r['offer_code'] ?? 'absent'} · quantité : ${r['quantity'] ?? 'absente'}',
                        ),
                        subtitle: Text(
                          'Famille : ${r['family_id'] ?? 'aucune'}\n${r['updated_at']} · ${r['updated_by']}',
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Raccourcis USSD indisponibles.'),
              const Text(
                'Vérifiez votre connexion et vos droits d’accès, puis réessayez.',
              ),
              OutlinedButton(
                onPressed: _reload,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final data = snapshot.data!;
      final families = _rows(data['families']);
      final offers = _rows(data['offers']);
      final rules = _rows(data['rules'])
          .map(UssdRule.fromJson)
          .where(
            (r) =>
                (_network.isEmpty || r.network == _network) &&
                (_service.isEmpty || r.service == _service) &&
                (_family.isEmpty || r.familyId == _family) &&
                (_status.isEmpty || r.status == _status) &&
                (_scope.isEmpty || r.scope == _scope),
          )
          .toList();
      String familyLabel(String? id) => id == null
          ? 'Toutes'
          : families
                    .where((f) => f['id'] == id)
                    .map((f) => f['label'] as String)
                    .firstOrNull ??
                id;
      String offerLabel(String? id) => id == null
          ? 'Toutes'
          : offers
                    .where((f) => f['id'] == id)
                    .map((f) => f['title'] as String)
                    .firstOrNull ??
                id;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Catalogue / Raccourcis USSD',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _admin
                ? 'Règles centralisées, validation humaine sur SIM et historique des versions.'
                : 'Consultation des règles utiles à votre territoire. Les modifications sont réservées à l’Administrateur.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              if (_admin)
                FilledButton.icon(
                  onPressed: _busy ? null : () => _edit(data),
                  icon: const Icon(Icons.add),
                  label: const Text('Créer une règle'),
                ),
              if (_admin)
                OutlinedButton(
                  onPressed: _busy ? null : _familyDialog,
                  child: const Text('Créer une famille'),
                ),
              if (_admin)
                OutlinedButton(
                  onPressed: _busy ? null : () => _bindingDialog(data),
                  child: const Text('Associer les offres'),
                ),
              OutlinedButton(
                onPressed: () => _activity(reports: true),
                child: const Text('Anomalies USSD'),
              ),
              OutlinedButton(
                onPressed: () => _activity(reports: false),
                child: const Text('Journaux d’ouverture'),
              ),
              IconButton(
                onPressed: _busy ? null : _reload,
                tooltip: 'Actualiser',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _filter(
                'Réseau',
                _network,
                ussdNetworks,
                (v) => setState(() => _network = v),
              ),
              _filter(
                'Service',
                _service,
                ussdServices,
                (v) => setState(() => _service = v),
              ),
              _filter('Famille', _family, {
                for (final f in families)
                  f['id'] as String: f['label'] as String,
              }, (v) => setState(() => _family = v)),
              _filter(
                'Statut',
                _status,
                ussdStatuses,
                (v) => setState(() => _status = v),
              ),
              _filter(
                'Cible',
                _scope,
                ussdScopes,
                (v) => setState(() => _scope = v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: rules.isEmpty
                ? const Center(
                    child: Text(
                      'Aucune règle dans cette sélection. Aucun code opérateur n’est préchargé.',
                    ),
                  )
                : SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          for (final label in [
                            'Réseau',
                            'Service',
                            'Famille',
                            'Offre',
                            'Cible',
                            'Template',
                            'Priorité',
                            'Version',
                            'Statut',
                            'Modification / auteur',
                            'Actions',
                          ])
                            DataColumn(label: Text(label)),
                        ],
                        rows: rules
                            .map(
                              (r) => DataRow(
                                cells: [
                                  DataCell(
                                    Text(ussdNetworks[r.network] ?? r.network),
                                  ),
                                  DataCell(
                                    Text(ussdServices[r.service] ?? r.service),
                                  ),
                                  DataCell(Text(familyLabel(r.familyId))),
                                  DataCell(
                                    SizedBox(
                                      width: 180,
                                      child: Text(offerLabel(r.offerId)),
                                    ),
                                  ),
                                  DataCell(
                                    Text(ussdScopes[r.scope] ?? r.scope),
                                  ),
                                  DataCell(SelectableText(r.template)),
                                  DataCell(Text('${r.priority}')),
                                  DataCell(Text('${r.version}')),
                                  DataCell(
                                    Text(ussdStatuses[r.status] ?? r.status),
                                  ),
                                  DataCell(
                                    Text(
                                      '${r.updatedAt?.toLocal() ?? ''}\n${r.updatedBy}',
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_admin)
                                          IconButton(
                                            tooltip:
                                                'Modifier (remet en brouillon)',
                                            onPressed: _busy
                                                ? null
                                                : () => _edit(data, r),
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
                                          ),
                                        IconButton(
                                          tooltip:
                                              'Tester avec des valeurs fictives',
                                          onPressed: () => showDialog<void>(
                                            context: context,
                                            builder: (_) => _PreviewDialog(
                                              template: r.template,
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.science_outlined,
                                          ),
                                        ),
                                        if (_admin)
                                          IconButton(
                                            tooltip: r.status == 'active'
                                                ? 'Désactiver'
                                                : 'Activer après validation SIM',
                                            onPressed: _busy
                                                ? null
                                                : () => _statusChange(r),
                                            icon: Icon(
                                              r.status == 'active'
                                                  ? Icons.pause_circle_outline
                                                  : Icons.play_circle_outline,
                                            ),
                                          ),
                                        if (_admin)
                                          IconButton(
                                            tooltip: 'Historique',
                                            onPressed: () => _history(r),
                                            icon: const Icon(Icons.history),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
          ),
        ],
      );
    },
  );
  Widget _filter(
    String label,
    String selected,
    Map<String, String> values,
    ValueChanged<String> change,
  ) => SizedBox(
    width: 210,
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label-$selected'),
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: '', child: Text('Tous')),
        ...values.entries.map(
          (e) => DropdownMenuItem(
            value: e.key,
            child: Text(e.value, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: (v) => change(v!),
    ),
  );
}

class _RuleEditor extends StatefulWidget {
  const _RuleEditor({this.rule, required this.families, required this.offers});
  final UssdRule? rule;
  final List<Map<String, dynamic>> families, offers;
  @override
  State<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<_RuleEditor> {
  final _form = GlobalKey<FormState>();
  String? _associationError;
  late String _network = widget.rule?.network ?? 'moov',
      _service = widget.rule?.service ?? 'internetSubscription',
      _scope = widget.rule?.scope ?? 'both',
      _family = widget.rule?.familyId ?? '',
      _offer = widget.rule?.offerId ?? '';
  late final _template = TextEditingController(
    text: widget.rule?.template ?? '',
  );
  late final _priority = TextEditingController(
    text: '${widget.rule?.priority ?? 0}',
  );
  late final _from = TextEditingController(
    text: (widget.rule?.effectiveFrom ?? DateTime.now())
        .toUtc()
        .toIso8601String(),
  );
  late final _until = TextEditingController(
    text: widget.rule?.effectiveUntil?.toUtc().toIso8601String() ?? '',
  );
  late final _note = TextEditingController(text: widget.rule?.note ?? '');
  @override
  void dispose() {
    for (final c in [_template, _priority, _from, _until, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    if ((_offer.isNotEmpty &&
            !widget.offers.any(
              (o) =>
                  o['id'] == _offer &&
                  o['network'] == _network &&
                  o['service'] == _service,
            )) ||
        (_family.isNotEmpty &&
            !widget.families.any(
              (f) =>
                  f['id'] == _family &&
                  f['network'] == _network &&
                  f['service'] == _service,
            ))) {
      setState(
        () => _associationError =
            'L’association n’est plus disponible. Choisissez une autre offre/famille ou une règle générique.',
      );
      return;
    }
    final from = DateTime.parse(_from.text),
        until = DateTime.tryParse(_until.text);
    if (until != null && !until.isAfter(from)) return;
    Navigator.pop(context, <String, dynamic>{
      'network': _network,
      'service': _service,
      'actor_scope': _scope,
      'family_id': _family.isEmpty ? null : _family,
      'offer_id': _offer.isEmpty ? null : _offer,
      'ussd_template': _template.text,
      'priority': int.parse(_priority.text),
      'effective_from': from.toUtc().toIso8601String(),
      'effective_until': until?.toUtc().toIso8601String(),
      'internal_note': _note.text.trim(),
    });
  }

  Widget _select(
    String label,
    String value,
    Map<String, String> choices,
    ValueChanged<String> change,
  ) => DropdownButtonFormField<String>(
    key: ValueKey('$label-$value'),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: choices.entries
        .map(
          (e) => DropdownMenuItem(
            value: e.key,
            child: Text(e.value, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: (v) => setState(() => change(v!)),
  );
  @override
  Widget build(BuildContext context) {
    final families = widget.families
        .where((f) => f['network'] == _network && f['service'] == _service)
        .toList();
    final offers = widget.offers
        .where(
          (f) =>
              f['network'] == _network &&
              f['service'] == _service &&
              (_family.isEmpty ||
                  (f['binding'] as Map?)?['family_id'] == _family),
        )
        .toList();
    return AlertDialog(
      title: Text(
        widget.rule == null ? 'Créer un brouillon' : 'Modifier la règle',
      ),
      content: SizedBox(
        width: 610,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.rule?.status == 'active')
                  const Text(
                    'Enregistrer désactive la version active et crée un brouillon. Une nouvelle validation SIM sera requise.',
                  ),
                if (_associationError != null)
                  Text(
                    _associationError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                _select('Réseau', _network, ussdNetworks, (v) {
                  _network = v;
                  _family = '';
                  _offer = '';
                }),
                _select('Service', _service, ussdServices, (v) {
                  _service = v;
                  _family = '';
                  _offer = '';
                }),
                _select(
                  'Famille',
                  _family,
                  {
                    '': 'Aucune / générique',
                    if (_family.isNotEmpty &&
                        !families.any((f) => f['id'] == _family))
                      _family: 'Famille indisponible (à remplacer)',
                    for (final f in families)
                      f['id'] as String: f['label'] as String,
                  },
                  (v) {
                    _family = v;
                    _offer = '';
                  },
                ),
                _select('Offre', _offer, {
                  '': 'Toutes / générique',
                  if (_offer.isNotEmpty &&
                      !offers.any((o) => o['id'] == _offer))
                    _offer: 'Offre indisponible (à remplacer)',
                  for (final f in offers)
                    f['id'] as String: f['title'] as String,
                }, (v) => _offer = v),
                _select('Cible', _scope, ussdScopes, (v) => _scope = v),
                TextFormField(
                  controller: _template,
                  maxLength: 512,
                  decoration: const InputDecoration(
                    labelText: 'Template USSD',
                    helperText:
                        'Variables : {{msisdn_local}}, {{amount}}, {{offer_code}}, {{quantity}}',
                  ),
                  validator: (v) {
                    try {
                      UssdEngine.validateTemplate(v ?? '');
                      return null;
                    } on UssdValidationException catch (e) {
                      return UssdEngine.message(e.code);
                    }
                  },
                ),
                TextFormField(
                  controller: _priority,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Priorité (-100000 à 100000)',
                  ),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return n == null || n < -100000 || n > 100000
                        ? 'Priorité invalide'
                        : null;
                  },
                ),
                TextFormField(
                  controller: _from,
                  decoration: const InputDecoration(
                    labelText: 'Début (ISO 8601 avec fuseau / UTC)',
                  ),
                  validator: (v) => DateTime.tryParse(v ?? '') == null
                      ? 'Date invalide'
                      : null,
                ),
                TextFormField(
                  controller: _until,
                  decoration: const InputDecoration(
                    labelText: 'Fin facultative (ISO 8601)',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    final d = DateTime.tryParse(v),
                        f = DateTime.tryParse(_from.text);
                    return d == null || f == null || !d.isAfter(f)
                        ? 'Fin après le début requise'
                        : null;
                  },
                ),
                TextFormField(
                  controller: _note,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Note interne (sans données personnelles)',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        OutlinedButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => _PreviewDialog(template: _template.text),
          ),
          child: const Text('Tester'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Enregistrer en brouillon'),
        ),
      ],
    );
  }
}

class _PreviewDialog extends StatefulWidget {
  const _PreviewDialog({required this.template});
  final String template;
  @override
  State<_PreviewDialog> createState() => _PreviewDialogState();
}

class _PreviewDialogState extends State<_PreviewDialog> {
  final _phone = TextEditingController(),
      _amount = TextEditingController(),
      _offer = TextEditingController(),
      _quantity = TextEditingController();
  String? _result;
  @override
  void dispose() {
    for (final c in [_phone, _amount, _offer, _quantity]) {
      c.dispose();
    }
    super.dispose();
  }

  void _test() {
    try {
      final code = UssdEngine.generate(
        widget.template,
        UssdValues(
          beneficiary: _phone.text,
          amount: int.tryParse(_amount.text),
          offerCode: _offer.text,
          quantity: int.tryParse(_quantity.text),
        ),
      );
      setState(() => _result = code);
    } on UssdValidationException catch (e) {
      setState(() => _result = UssdEngine.message(e.code));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Prévisualisation fictive'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Utilisez uniquement des valeurs fictives. Ce test ne lance aucune opération télécom.',
            ),
            SelectableText(widget.template),
            for (final entry in [
              ('Bénéficiaire fictif', _phone),
              ('Montant fictif', _amount),
              ('Code offre fictif', _offer),
              ('Quantité fictive', _quantity),
            ])
              TextField(
                controller: entry.$2,
                decoration: InputDecoration(labelText: entry.$1),
              ),
            if (_result != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SelectableText(_result!),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Fermer'),
      ),
      FilledButton(onPressed: _test, child: const Text('Générer sans lancer')),
    ],
  );
}

class _ActivationDialog extends StatefulWidget {
  const _ActivationDialog();
  @override
  State<_ActivationDialog> createState() => _ActivationDialogState();
}

class _ActivationDialogState extends State<_ActivationDialog> {
  final _sim = TextEditingController();
  bool _checked = false;
  @override
  void dispose() {
    _sim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Validation humaine sur SIM'),
    content: SizedBox(
      width: 500,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Activez uniquement une syntaxe effectivement vérifiée sur le réseau et la SIM cabine concernés.',
          ),
          TextField(
            controller: _sim,
            maxLength: 100,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Type de SIM testé (aucun numéro)',
            ),
          ),
          CheckboxListTile(
            value: _checked,
            onChanged: (v) => setState(() => _checked = v!),
            title: const Text(
              'Je confirme avoir vérifié cette configuration sur une SIM appropriée.',
            ),
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
        onPressed: _checked && _sim.text.trim().isNotEmpty
            ? () => Navigator.pop(context, _sim.text.trim())
            : null,
        child: const Text('Activer cette version'),
      ),
    ],
  );
}

class _FamilyEditor extends StatefulWidget {
  const _FamilyEditor();
  @override
  State<_FamilyEditor> createState() => _FamilyEditorState();
}

class _FamilyEditorState extends State<_FamilyEditor> {
  String _network = 'moov', _service = 'internetSubscription';
  final _label = TextEditingController();
  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Créer une famille stable'),
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _network,
            items: ussdNetworks.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) => setState(() => _network = v!),
          ),
          DropdownButtonFormField<String>(
            initialValue: _service,
            isExpanded: true,
            items: ussdServices.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) => setState(() => _service = v!),
          ),
          TextField(
            controller: _label,
            maxLength: 100,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Nom de famille'),
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
        onPressed: _label.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, (
                _network,
                _service,
                _label.text.trim(),
              )),
        child: const Text('Créer'),
      ),
    ],
  );
}

class _BindingEditor extends StatefulWidget {
  const _BindingEditor({
    required this.offers,
    required this.families,
    required this.onHistory,
  });
  final List<Map<String, dynamic>> offers, families;
  final ValueChanged<String> onHistory;
  @override
  State<_BindingEditor> createState() => _BindingEditorState();
}

class _BindingEditorState extends State<_BindingEditor> {
  String? _offer;
  String _family = '';
  final _code = TextEditingController(), _quantity = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _code.dispose();
    _quantity.dispose();
    super.dispose();
  }

  void _pick(String? id) {
    setState(() {
      _offer = id;
      final binding =
          widget.offers.firstWhere((o) => o['id'] == id)['binding'] as Map?;
      _family = binding?['family_id'] as String? ?? '';
      _code.text = binding?['offer_code'] as String? ?? '';
      _quantity.text = binding?['quantity']?.toString() ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offers.where((o) => o['id'] == _offer).firstOrNull;
    final families = widget.families.where(
      (f) =>
          f['network'] == offer?['network'] &&
          f['service'] == offer?['service'],
    );
    return AlertDialog(
      title: const Text('Associer une offre du catalogue'),
      content: SizedBox(
        width: 550,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Les associations utilisent les identifiants du catalogue. Désactivez les règles concernées avant toute modification. Le code et la quantité doivent être vérifiés avant réactivation.',
                ),
                TextButton(
                  onPressed: _offer == null
                      ? null
                      : () => widget.onHistory(_offer!),
                  child: const Text('Historique de cette association'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _offer,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Offre réelle'),
                  items: widget.offers
                      .map(
                        (o) => DropdownMenuItem(
                          value: o['id'] as String,
                          child: Text(
                            '${ussdNetworks[o['network']]} · ${o['title']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _pick,
                  validator: (v) => v == null ? 'Sélectionnez une offre' : null,
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey('binding-$_offer-$_family'),
                  initialValue: _family,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Famille facultative',
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Aucune')),
                    ...families.map(
                      (f) => DropdownMenuItem(
                        value: f['id'] as String,
                        child: Text(f['label'] as String),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _family = v!),
                ),
                TextFormField(
                  controller: _code,
                  maxLength: 20,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Code opérateur numérique facultatif',
                  ),
                  validator: (v) =>
                      v!.isNotEmpty && !RegExp(r'^[0-9]{1,20}$').hasMatch(v)
                      ? 'Chiffres uniquement'
                      : null,
                ),
                TextFormField(
                  controller: _quantity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantité autorisée par offre (facultative)',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    final n = int.tryParse(v);
                    return n == null || n < 1 || n > 999999
                        ? 'Quantité invalide'
                        : null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.pop(context, (
                _offer!,
                _family.isEmpty ? null : _family,
                _code.text.isEmpty ? null : _code.text,
                int.tryParse(_quantity.text),
              ));
            }
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
