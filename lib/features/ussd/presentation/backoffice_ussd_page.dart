import 'dart:async';
import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/backoffice/presentation/widgets/backoffice_modal.dart';
import 'package:cabine_flow/backoffice/presentation/widgets/backoffice_order_widgets.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart'
    show MobileNetwork;
import 'package:cabine_flow/features/ussd/data/supabase_ussd_repository.dart';
import 'package:cabine_flow/features/ussd/domain/ussd_engine.dart';
import 'package:cabine_flow/features/ussd/domain/ussd_repository.dart';
import 'package:cabine_flow/features/ussd/presentation/ussd_activity_page.dart';
import 'package:flutter/material.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';

part 'ussd_rule_dialogs.dart';
part 'ussd_deletion_dialogs.dart';

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
  final _tableScroll = ScrollController();
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
    _tableScroll.dispose();
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

  Future<bool> _run(Future<void> Function() action) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) _reload();
      return true;
    } catch (e) {
      if (mounted) _notice(_error(e));
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notice(String text) => IzyTelFeedback.error(context, text);
  String _configurationError(Object? error) {
    if (error is UssdValidationException &&
        error.code == 'authentication_required') {
      return 'Votre session n’est plus disponible. Déconnectez-vous puis reconnectez-vous avant de réessayer.';
    }
    return 'Vérifiez votre connexion et vos droits d’accès, puis réessayez.';
  }

  String _error(Object error) {
    if (error is TimeoutException) {
      return 'Réponse non reçue. Actualisez avant de réessayer pour éviter un doublon.';
    }
    final text = error.toString();
    if (text.contains('PGRST202') || text.contains('42883')) {
      return 'Cette action nécessite une mise à jour du service USSD. Aucune suppression n’a été confirmée.';
    }
    if (text.contains('rule_deleted')) {
      return 'Cette règle a déjà été supprimée. Actualisez la liste.';
    }
    if (text.contains('family_in_use')) {
      return 'Cette famille est encore utilisée. Retirez-la des règles et des associations d’offres avant de la supprimer.';
    }
    if (text.contains('family_changed') || text.contains('binding_changed')) {
      return 'Cet élément a changé. Actualisez la liste avant de réessayer.';
    }
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
    final payload = await showBackofficeModal<Map<String, dynamic>>(
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
      sim = await showBackofficeModal<String>(
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

  Future<void> _deleteRule(UssdRule rule) async {
    if (!_admin || _busy) return;
    final agreed = await _confirmDeletion(
      title: 'Supprimer cette règle ?',
      description: rule.status == 'active'
          ? 'Cette règle active sera supprimée de la configuration et les nouveaux lancements seront refusés. Le traitement manuel restera disponible. L’historique sera conservé.'
          : 'Cette règle sera supprimée de la configuration. L’historique sera conservé.',
      detail: '${ussdNetworks[rule.network]} · ${ussdStatuses[rule.status]}',
      template: rule.template,
    );
    if (agreed && mounted) await _run(() => _repository.deleteRule(rule));
  }

  Future<bool> _confirmDeletion({
    required String title,
    required String description,
    required String detail,
    String? template,
  }) async =>
      await showBackofficeModal<bool>(
        context: context,
        builder: (_) => _UssdDeleteConfirmation(
          title: title,
          description: description,
          detail: detail,
          template: template,
        ),
      ) ==
      true;

  Future<void> _manageFamilies(Map<String, dynamic> data) async {
    if (!_admin || _busy) return;
    final family = await showBackofficeModal<Map<String, dynamic>>(
      context: context,
      builder: (_) => _UssdFamilyManager(families: _rows(data['families'])),
    );
    if (family == null || !mounted) return;
    final agreed = await _confirmDeletion(
      title: 'Supprimer cette famille ?',
      description:
          'La famille sera retirée de la configuration. Si une règle ou une association d’offre l’utilise encore, la suppression sera refusée.',
      detail:
          '${family['label']} · ${ussdNetworks[family['network']]} · ${ussdServices[family['service']]}',
    );
    if (!agreed || !mounted) return;
    if (await _run(() => _repository.deleteFamily(family['id'] as String))) {
      if (mounted && _family == family['id']) setState(() => _family = '');
    }
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
    final value = await showDialog<Object>(
      context: context,
      builder: (_) => _BindingEditor(
        offers: _rows(data['offers']),
        families: _rows(data['families']),
        onHistory: _bindingHistory,
      ),
    );
    if (value != null && mounted) {
      if (value is _UssdBindingDeletion) {
        final agreed = await _confirmDeletion(
          title: 'Supprimer cette association ?',
          description:
              'La famille, le code opérateur et la quantité configurés pour cette offre seront retirés. L’offre du catalogue et l’historique seront conservés. Désactivez d’abord les règles actives qui en dépendent.',
          detail: value.title,
        );
        if (agreed && mounted) {
          await _run(
            () => _repository.deleteBinding(value.offerId, value.version),
          );
        }
      } else if (value is (String, String?, String?, int?)) {
        await _run(
          () => _repository.saveBinding(value.$1, value.$2, value.$3, value.$4),
        );
      }
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
              Text(_configurationError(snapshot.error)),
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
                (_service.isEmpty ||
                    (r.purpose == 'balance' ? 'balance' : r.service) ==
                        _service) &&
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
      // The backoffice frame already scrolls vertically. This page must also
      // accept unbounded height there, while remaining scrollable on its own.
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: IzyTelSpacing.xl),
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
                    onPressed: _busy ? null : () => _manageFamilies(data),
                    child: const Text('Gérer les familles'),
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
            const SizedBox(height: IzyTelSpacing.xl),
            BackofficeModalSection(
              title: 'Filtrer les règles',
              icon: Icons.filter_list_rounded,
              backgroundColor: BackofficePalette.surface,
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _filter(
                    'Réseau',
                    _network,
                    ussdNetworks,
                    (v) => setState(() => _network = v),
                  ),
                  _filter('Service', _service, {
                    ...ussdServices,
                    'balance': 'Consultation du solde',
                  }, (v) => setState(() => _service = v)),
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
            ),
            const SizedBox(height: IzyTelSpacing.xl),
            Text(
              '${rules.length} règle(s) dans cette sélection',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 12),
            if (rules.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 40,
                ),
                decoration: backofficePanelDecoration(),
                child: const Column(
                  children: [
                    Icon(
                      Icons.dialpad_rounded,
                      size: 32,
                      color: BackofficePalette.muted,
                    ),
                    SizedBox(height: 12),
                    Text('Aucune règle dans cette sélection.'),
                    SizedBox(height: 8),
                    Text(
                      'Créez un brouillon ou ajustez vos filtres pour commencer.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              _rulesTable(rules, data, familyLabel, offerLabel),
          ],
        ),
      );
    },
  );
  // Keep the status and controls next to the operator, before scrollable details.
  List<T> _priorityColumns<T>(List<T> cells) => [
    cells[0],
    cells[6],
    cells[8],
    cells[1],
    cells[2],
    cells[3],
    cells[4],
    cells[5],
    cells[7],
  ];

  Widget _rulesTable(
    List<UssdRule> rules,
    Map<String, dynamic> data,
    String Function(String?) familyLabel,
    String Function(String?) offerLabel,
  ) {
    const specs = [
      ('Opérateur', 3),
      ('Service', 4),
      ('Famille / offre', 5),
      ('Cible', 3),
      ('Syntaxe USSD', 6),
      ('Priorité / version', 3),
      ('Statut', 3),
      ('Mise à jour', 4),
      ('Actions', 7),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => Scrollbar(
        controller: _tableScroll,
        thumbVisibility: true,
        notificationPredicate: (notification) =>
            notification.metrics.axis == Axis.horizontal,
        child: SingleChildScrollView(
          controller: _tableScroll,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            width: constraints.maxWidth < 1680 ? 1680 : constraints.maxWidth,
            child: BackofficeDesktopTable(
              columns: _priorityColumns([
                for (final spec in specs)
                  BackofficeTableColumnSpec(label: spec.$1, flex: spec.$2),
              ]),
              rows: [
                for (final r in rules)
                  BackofficeDesktopTableRow(
                    cells: _priorityColumns([
                      BackofficeTableCellSpec(
                        flex: 3,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: BackofficeNetworkBadge(
                            network: MobileNetwork.values.firstWhere(
                              (n) => n.name == r.network,
                            ),
                            compact: true,
                          ),
                        ),
                      ),
                      BackofficeTableCellSpec(
                        flex: 4,
                        child: Text(
                          r.purpose == 'balance'
                              ? 'Consultation du solde'
                              : ussdServices[r.service] ?? r.service,
                          maxLines: 2,
                        ),
                      ),
                      BackofficeTableCellSpec(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              offerLabel(r.offerId),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Famille : ${familyLabel(r.familyId)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      BackofficeTableCellSpec(
                        flex: 3,
                        child: Text(
                          ussdScopes[r.scope] ?? r.scope,
                          maxLines: 2,
                        ),
                      ),
                      BackofficeTableCellSpec(
                        flex: 6,
                        child: Tooltip(
                          message: r.template,
                          child: Text(
                            r.template,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              color: BackofficePalette.primaryStrong,
                            ),
                          ),
                        ),
                      ),
                      BackofficeTableCellSpec(
                        flex: 3,
                        child: Text('${r.priority} · V${r.version}'),
                      ),
                      BackofficeTableCellSpec(
                        flex: 3,
                        child: BackofficeStatusBadge(
                          label: ussdStatuses[r.status] ?? r.status,
                          color: r.status == 'active'
                              ? BackofficePalette.success
                              : r.status == 'draft'
                              ? BackofficePalette.warning
                              : BackofficePalette.muted,
                        ),
                      ),
                      BackofficeTableCellSpec(
                        flex: 4,
                        child: Tooltip(
                          message: r.updatedBy,
                          child: Text(
                            r.updatedAt
                                    ?.toLocal()
                                    .toString()
                                    .split('.')
                                    .first ??
                                '—',
                            maxLines: 2,
                          ),
                        ),
                      ),
                      BackofficeTableCellSpec(
                        flex: 7,
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            Tooltip(
                              message: 'Tester avec des valeurs fictives',
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                                onPressed: () => showBackofficeModal<void>(
                                  context: context,
                                  builder: (_) =>
                                      _PreviewDialog(template: r.template),
                                ),
                                icon: const Icon(
                                  Icons.science_outlined,
                                  size: 18,
                                ),
                                label: const Text('Tester'),
                              ),
                            ),
                            if (_admin)
                              PopupMenuButton<String>(
                                tooltip: 'Actions sur la règle',
                                enabled: !_busy,
                                onSelected: (action) {
                                  switch (action) {
                                    case 'edit':
                                      _edit(data, r);
                                    case 'history':
                                      _history(r);
                                    case 'status':
                                      _statusChange(r);
                                    case 'delete':
                                      _deleteRule(r);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text(
                                      'Modifier (remet en brouillon)',
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'history',
                                    child: Text('Historique'),
                                  ),
                                  PopupMenuItem(
                                    value: 'status',
                                    child: Text(
                                      r.status == 'active'
                                          ? 'Désactiver'
                                          : 'Activer après validation SIM',
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Supprimer'),
                                  ),
                                ],
                                child: const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('Actions'),
                                      Icon(Icons.expand_more_rounded, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ]),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
  Widget build(BuildContext context) => BackofficeModalShell(
    title: 'Validation humaine sur SIM',
    icon: Icons.verified_user_outlined,
    maxWidth: 560,
    body: SizedBox(
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
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              value: _checked,
              onChanged: (v) => setState(() => _checked = v!),
              title: const Text(
                'Je confirme avoir vérifié cette configuration sur une SIM appropriée.',
              ),
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
                if (offer?['binding'] is Map)
                  TextButton.icon(
                    onPressed: () {
                      final binding = offer!['binding'] as Map;
                      Navigator.pop(
                        context,
                        _UssdBindingDeletion(
                          offerId: _offer!,
                          version: (binding['version'] as num).toInt(),
                          title: offer['title'] as String,
                        ),
                      );
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Supprimer cette association'),
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
