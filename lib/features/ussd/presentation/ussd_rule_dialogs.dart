part of 'backoffice_ussd_page.dart';

const _ussdVariables = {
  'msisdn_local': 'Bénéficiaire',
  'amount': 'Montant',
  'offer_code': 'Code offre',
  'quantity': 'Quantité',
  'secret_code': 'Code secret',
};

class _UssdFieldGrid extends StatelessWidget {
  const _UssdFieldGrid({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) {
      final columns = constraints.maxWidth >= 600 ? 2 : 1;
      final width =
          (constraints.maxWidth - (columns - 1) * IzyTelSpacing.md) / columns;
      return Wrap(
        spacing: IzyTelSpacing.md,
        runSpacing: IzyTelSpacing.md,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class _UssdCodeBlock extends StatelessWidget {
  const _UssdCodeBlock({required this.label, required this.code});
  final String label, code;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(IzyTelSpacing.md),
    decoration: BoxDecoration(
      color: BackofficePalette.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: BackofficePalette.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: BackofficePalette.muted),
        ),
        const SizedBox(height: 8),
        SelectableText(
          code,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 16,
            color: BackofficePalette.primaryStrong,
            height: 1.6,
          ),
        ),
      ],
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
  final _templateFocus = FocusNode();
  String? _associationError;
  late String _network = widget.rule?.network ?? 'moov',
      _service = widget.rule?.service.isNotEmpty == true
          ? widget.rule!.service
          : 'internetSubscription',
      _purpose = widget.rule?.purpose ?? 'order',
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
  void initState() {
    super.initState();
    _template.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _template.removeListener(_changed);
    _templateFocus.dispose();
    for (final c in [_template, _priority, _from, _until, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  void _insert(String variable) {
    final selection = _template.selection;
    final start = selection.isValid ? selection.start : _template.text.length;
    final end = selection.isValid ? selection.end : start;
    final token = '{{$variable}}';
    _template.value = TextEditingValue(
      text: _template.text.replaceRange(start, end, token),
      selection: TextSelection.collapsed(offset: start + token.length),
    );
    _templateFocus.requestFocus();
  }

  void _save() {
    final invalid = _form.currentState!.validateGranularly();
    if (invalid.isNotEmpty) {
      unawaited(
        Scrollable.ensureVisible(
          invalid.first.context,
          duration: const Duration(milliseconds: 200),
          alignment: .15,
        ),
      );
      return;
    }
    if (_purpose == 'order' &&
        ((_offer.isNotEmpty &&
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
                )))) {
      setState(
        () => _associationError =
            'L’association n’est plus disponible. Choisissez une autre offre/famille ou une règle générique.',
      );
      return;
    }
    final from = DateTime.parse(_from.text),
        until = DateTime.tryParse(_until.text);
    Navigator.pop(context, <String, dynamic>{
      'network': _network,
      'service': _purpose == 'balance' ? null : _service,
      'purpose': _purpose,
      'actor_scope': _scope,
      'family_id': _purpose == 'balance' || _family.isEmpty ? null : _family,
      'offer_id': _purpose == 'balance' || _offer.isEmpty ? null : _offer,
      'ussd_template': UssdEngine.normalizeTemplate(_template.text),
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

  Widget _instantPreview() {
    if (_template.text.trim().isEmpty) {
      return const Text(
        'Saisissez une syntaxe ou insérez une variable pour afficher un aperçu fictif.',
      );
    }
    try {
      final canonical = UssdEngine.normalizeTemplate(_template.text);
      UssdEngine.validateTemplate(canonical);
      final result = UssdEngine.generate(
        canonical,
        const UssdValues(
          beneficiary: '0101010101',
          amount: 1000,
          offerCode: '123',
          quantity: 1,
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _UssdCodeBlock(label: 'Syntaxe enregistrée', code: canonical),
          const SizedBox(height: 12),
          _UssdCodeBlock(
            label: 'Aperçu fictif · aucune opération lancée',
            code: result,
          ),
          const SizedBox(height: 8),
          const Text(
            'Exemple : bénéficiaire 0101010101 · montant 1000 · code offre 123 · quantité 1. Le secret utilisé ici est fictif.',
          ),
        ],
      );
    } on UssdValidationException catch (e) {
      return Text(
        UssdEngine.message(e.code),
        style: const TextStyle(color: BackofficePalette.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final families = widget.families
        .where((f) => f['network'] == _network && f['service'] == _service)
        .toList();
    final offers = widget.offers
        .where(
          (o) =>
              o['network'] == _network &&
              o['service'] == _service &&
              (_family.isEmpty ||
                  (o['binding'] as Map?)?['family_id'] == _family),
        )
        .toList();
    return BackofficeModalShell(
      title: widget.rule == null ? 'Créer un brouillon' : 'Modifier la règle',
      subtitle: compact
          ? 'Enregistrement en brouillon.'
          : 'Définissez le périmètre et la syntaxe, puis vérifiez un exemple avant enregistrement.',
      icon: Icons.dialpad_rounded,
      maxWidth: 900,
      bodyPadding: EdgeInsets.all(
        MediaQuery.sizeOf(context).width < 640 ? 16 : 24,
      ),
      chips: [
        if (!compact)
          const BackofficeStatusBadge(
            label: 'Brouillon',
            color: BackofficePalette.warning,
          ),
      ],
      body: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.rule?.status == 'active') ...[
              const Text(
                'Enregistrer désactive la version active et crée un brouillon. Une nouvelle validation SIM sera requise.',
                style: TextStyle(color: BackofficePalette.warning),
              ),
              const SizedBox(height: 16),
            ],
            if (_associationError != null) ...[
              Text(
                _associationError!,
                style: const TextStyle(color: BackofficePalette.danger),
              ),
              const SizedBox(height: 16),
            ],
            BackofficeModalSection(
              title: '1. Périmètre',
              subtitle:
                  'À quelles opérations et à quels utilisateurs s’applique cette règle ?',
              icon: Icons.tune_rounded,
              child: _UssdFieldGrid(
                children: [
                  _select('Réseau', _network, ussdNetworks, (v) {
                    _network = v;
                    _family = '';
                    _offer = '';
                  }),
                  _select(
                    'Usage',
                    _purpose,
                    const {
                      'order': 'Traitement d’une commande',
                      'balance': 'Consultation du solde',
                    },
                    (v) {
                      _purpose = v;
                      _family = '';
                      _offer = '';
                    },
                  ),
                  if (_purpose == 'order') ...[
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
                      for (final o in offers)
                        o['id'] as String: o['title'] as String,
                    }, (v) => _offer = v),
                  ],
                  _select('Cible', _scope, ussdScopes, (v) => _scope = v),
                ],
              ),
            ),
            const SizedBox(height: IzyTelSpacing.xl),
            BackofficeModalSection(
              title: '2. Syntaxe USSD',
              subtitle:
                  'Les variables seront remplacées au moment du traitement.',
              icon: Icons.code_rounded,
              backgroundColor: BackofficePalette.primarySoft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _template,
                    focusNode: _templateFocus,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 512,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      height: 1.6,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Template USSD',
                      alignLabelWithHint: true,
                      hintText: '*412*2*{{msisdn_local}}#',
                      contentPadding: EdgeInsets.all(16),
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
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in _ussdVariables.entries)
                        Tooltip(
                          message: '{{${entry.key}}}',
                          child: ActionChip(
                            label: Text(entry.value),
                            avatar: const Icon(Icons.add_rounded, size: 16),
                            onPressed: () => _insert(entry.key),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Vous pouvez aussi écrire numéro, montant, code_offre, quantité ou code secret. Les noms sont normalisés avant enregistrement.',
                  ),
                  const SizedBox(height: 16),
                  _instantPreview(),
                ],
              ),
            ),
            const SizedBox(height: IzyTelSpacing.xl),
            BackofficeModalSection(
              title: '3. Publication',
              subtitle:
                  'L’enregistrement reste un brouillon. L’activation nécessite une validation SIM séparée.',
              icon: Icons.schedule_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _UssdFieldGrid(
                    children: [
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
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _note,
                    maxLength: 1000,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Note interne (sans données personnelles)',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
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
        OutlinedButton.icon(
          onPressed: () => showBackofficeModal<void>(
            context: context,
            builder: (_) => _PreviewDialog(template: _template.text),
          ),
          icon: const Icon(Icons.science_outlined),
          label: const Text('Prévisualiser'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Enregistrer en brouillon'),
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
      _quantity = TextEditingController(),
      _secret = TextEditingController(text: UssdEngine.defaultSecretCode);
  String? _result, _error;
  @override
  void dispose() {
    for (final c in [_phone, _amount, _offer, _quantity, _secret]) {
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
          secretCode: _secret.text,
        ),
      );
      setState(() {
        _result = code;
        _error = null;
      });
    } on UssdValidationException catch (e) {
      setState(() {
        _result = null;
        _error = UssdEngine.message(e.code);
      });
    }
  }

  void _invalidate(String _) {
    if (_result != null || _error != null) {
      setState(() {
        _result = null;
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) => BackofficeModalShell(
    title: 'Prévisualisation fictive',
    subtitle: MediaQuery.sizeOf(context).width < 640
        ? 'Exemple fictif, aucun lancement.'
        : 'Générez un exemple sans ouvrir le composeur ni modifier une commande.',
    icon: Icons.science_outlined,
    maxWidth: 760,
    bodyPadding: EdgeInsets.all(
      MediaQuery.sizeOf(context).width < 640 ? 16 : 24,
    ),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _UssdCodeBlock(label: 'Syntaxe à tester', code: widget.template),
        const SizedBox(height: 24),
        BackofficeModalSection(
          title: 'Données fictives',
          subtitle: 'N’utilisez ni numéro client ni secret réel pour ce test.',
          icon: Icons.edit_note_rounded,
          child: _UssdFieldGrid(
            children: [
              for (final entry in [
                ('Bénéficiaire fictif', _phone),
                ('Montant fictif', _amount),
                ('Code offre fictif', _offer),
                ('Quantité fictive', _quantity),
                ('Code secret fictif', _secret),
              ])
                TextField(
                  controller: entry.$2,
                  onChanged: _invalidate,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: entry.$1),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        BackofficeModalSection(
          title: 'Résultat généré',
          icon: Icons.code_rounded,
          backgroundColor: BackofficePalette.primarySoft,
          child: _result == null
              ? Text(
                  _error ??
                      'Renseignez les variables nécessaires puis générez l’exemple.',
                  style: TextStyle(
                    color: _error == null
                        ? BackofficePalette.muted
                        : BackofficePalette.danger,
                  ),
                )
              : _UssdCodeBlock(
                  label: 'Code USSD fictif · aucun lancement',
                  code: _result!,
                ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Fermer'),
      ),
      FilledButton.icon(
        onPressed: _test,
        icon: const Icon(Icons.science_outlined),
        label: const Text('Générer sans lancer'),
      ),
    ],
  );
}
