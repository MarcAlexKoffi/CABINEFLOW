import 'package:cabine_flow/app/domain/entities/offers/admin_offer.dart';
import 'package:cabine_flow/app/domain/entities/offers/catalog_import.dart';
import 'package:cabine_flow/app/domain/repositories/catalog_import_repository.dart';
import 'package:cabine_flow/app/modules/backoffice/views/catalog/catalog_import_dialog.dart';
import 'package:flutter/material.dart';

const _labels = <String, String>{
  'code_offre': 'Code permanent',
  'operateur': 'Opérateur',
  'famille': 'Famille',
  'type_forfait': 'Type de forfait',
  'nom_affiche': 'Nom affiché',
  'prix_fcfa': 'Prix opérateur (FCFA)',
  'volume_data': 'Volume de données',
  'unite_data': 'Unité d’origine',
  'minutes_appels': 'Minutes d’appels',
  'nombre_sms': 'Nombre de SMS',
  'duree_valeur': 'Durée',
  'duree_unite': 'Unité de durée',
  'statut': 'Statut',
  'mis_en_avant': 'Mis en avant',
  'ordre_affichage': 'Ordre d’affichage',
  'activable_pour_tiers': 'Activable pour un tiers',
  'canal_activation': 'Canal d’activation confirmé',
  'reference_operateur': 'Référence opérateur',
  'verifie_le': 'Vérifié le (AAAA-MM-JJ)',
  'source_url': 'Source (texte)',
  'commentaire': 'Commentaire',
};
const _choices = <String, List<String>>{
  'operateur': ['ORANGE', 'MTN', 'MOOV'],
  'type_forfait': ['INTERNET', 'MIXTE', 'APPELS', 'SOCIAL'],
  'unite_data': ['', 'MO', 'GO'],
  'duree_unite': ['JOUR', 'HEURE', 'MOIS'],
  'statut': ['BROUILLON', 'ACTIF', 'INACTIF'],
  'mis_en_avant': ['NON', 'OUI'],
  'activable_pour_tiers': ['A_VERIFIER', 'OUI', 'NON'],
  'canal_activation': ['A_VERIFIER', 'MANUEL', 'USSD', 'API', 'APP_OPERATEUR'],
};

class CatalogOfferDetailsDialog extends StatefulWidget {
  const CatalogOfferDetailsDialog({
    super.key,
    required this.repository,
    required this.configuration,
    this.offer,
    this.duplicate = false,
  });
  final CatalogImportRepository repository;
  final CatalogImportConfiguration configuration;
  final AdminOffer? offer;
  final bool duplicate;
  @override
  State<CatalogOfferDetailsDialog> createState() =>
      _CatalogOfferDetailsDialogState();
}

class _CatalogOfferDetailsDialogState extends State<CatalogOfferDetailsDialog> {
  final _form = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  late final TextEditingController _proof;
  bool _busy = false, _mappingConfirmed = false;
  String? _error;
  bool get _editing => widget.offer != null && !widget.duplicate;
  @override
  void initState() {
    super.initState();
    final offer = widget.offer;
    final seed = <String, dynamic>{
      'action': 'UPSERT',
      'code_offre': offer?.stableCode ?? '',
      'operateur': offer?.network.name.toUpperCase() ?? 'ORANGE',
      'famille': offer?.familyCode ?? '',
      'type_forfait': offer?.operationType.name == 'mixedBundle'
          ? 'MIXTE'
          : offer?.service == OfferService.calls
          ? 'APPELS'
          : 'INTERNET',
      'nom_affiche': offer?.title ?? '',
      'prix_fcfa': offer?.sellingPrice.toString() ?? '',
      'duree_valeur': '',
      'duree_unite': 'JOUR',
      'statut':
          offer?.catalogStatus ??
          (offer?.isActive == true ? 'ACTIF' : 'BROUILLON'),
      'mis_en_avant': offer?.badgeLabel == null ? 'NON' : 'OUI',
      'ordre_affichage': offer?.displayOrder.toString() ?? '1',
      'activable_pour_tiers': 'A_VERIFIER',
      'canal_activation': 'A_VERIFIER',
      ...?offer?.importData,
    };
    if (widget.duplicate) {
      seed['code_offre'] = '';
      seed['statut'] = 'BROUILLON';
      seed['verifie_le'] = '';
      seed['activable_pour_tiers'] = 'A_VERIFIER';
      seed['canal_activation'] = 'A_VERIFIER';
    }
    for (final key in catalogImportHeaders.where((key) => key != 'action')) {
      _controllers[key] = TextEditingController(
        text: seed[key]?.toString() ?? '',
      );
    }
    _proof = TextEditingController(
      text: widget.duplicate ? '' : offer?.deliveryProof ?? '',
    );
    if (_controllers['famille']!.text.isEmpty) {
      _controllers['famille']!.text =
          widget.configuration
              .familiesFor(_controllers['operateur']!.text)
              .firstOrNull ??
          '';
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _proof.dispose();
    super.dispose();
  }

  Widget _field(String key) {
    final choices = key == 'famille'
        ? widget.configuration.familiesFor(_controllers['operateur']!.text)
        : _choices[key];
    if (choices != null) {
      return DropdownButtonFormField<String>(
        key: ValueKey('$key-${_controllers[key]!.text}'),
        initialValue: choices.contains(_controllers[key]!.text)
            ? _controllers[key]!.text
            : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: _labels[key]),
        items: choices
            .map(
              (v) => DropdownMenuItem(
                value: v,
                child: Text(v.isEmpty ? 'Aucune' : v),
              ),
            )
            .toList(),
        onChanged: _busy || key == 'operateur' && _editing
            ? null
            : (value) => setState(() {
                _controllers[key]!.text = value ?? '';
                if (key == 'operateur') {
                  _controllers['famille']!.text =
                      widget.configuration.familiesFor(value).firstOrNull ?? '';
                }
              }),
        validator: (value) => value == null ? 'Choisissez une valeur.' : null,
      );
    }
    return TextFormField(
      controller: _controllers[key],
      readOnly: key == 'code_offre' && _editing && widget.offer!.codeConfirmed,
      enabled: !_busy,
      decoration: InputDecoration(labelText: _labels[key]),
      maxLines: key == 'commentaire' ? 3 : 1,
      keyboardType:
          [
            'prix_fcfa',
            'volume_data',
            'minutes_appels',
            'nombre_sms',
            'duree_valeur',
            'ordre_affichage',
          ].contains(key)
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      validator:
          [
            'code_offre',
            'nom_affiche',
            'prix_fcfa',
            'duree_valeur',
            'ordre_affichage',
          ].contains(key)
          ? (value) => value == null || value.trim().isEmpty
                ? 'Champ obligatoire.'
                : null
          : null,
    );
  }

  @override
  Widget build(BuildContext context) => CatalogPanelDialog(
    title: widget.duplicate
        ? 'Dupliquer l’offre'
        : _editing
        ? 'Code et vérification de l’offre'
        : 'Nouvelle offre',
    subtitle:
        'Prix opérateur hors frais IzyTel. Les commandes existantes restent inchangées.',
    busy: _busy,
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context, false),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed:
            _busy ||
                (_editing && !widget.offer!.codeConfirmed && !_mappingConfirmed)
            ? null
            : _save,
        child: const Text('Enregistrer'),
      ),
    ],
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) catalogNotice(_error!, error: true),
          if (_editing && widget.offer!.importData == null)
            catalogNotice(
              'Rattachement explicite à l’offre ${widget.offer!.id}. Le code provisoire est son identifiant technique. Vérifiez les quantités et la durée : elles ne sont pas reconstituées à partir du nom ou du prix.',
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 640
                  ? (constraints.maxWidth - 14) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 14,
                runSpacing: 16,
                children: [
                  for (final key in _controllers.keys)
                    SizedBox(width: width, child: _field(key)),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _proof,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'Preuve de livraison pour un tiers',
              hintText:
                  'Référence du contrôle effectué ; obligatoire si famille conditionnelle',
            ),
            minLines: 2,
            maxLines: 3,
          ),
          catalogNotice(
            widget.configuration.verificationDays == null
                ? 'Publication ACTIF bloquée jusqu’à la configuration du délai de vérification. Les brouillons restent enregistrables.'
                : 'Publication : vérification de moins de ${widget.configuration.verificationDays} jours, activation pour un tiers OUI, canal confirmé et preuve de livraison si nécessaire. Toutes les règles sont vérifiées côté serveur.',
          ),
          if (_editing && !widget.offer!.codeConfirmed)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _mappingConfirmed,
              onChanged: _busy
                  ? null
                  : (value) =>
                        setState(() => _mappingConfirmed = value ?? false),
              title: const Text(
                'Je confirme ce code comme identifiant permanent de cette offre.',
              ),
            ),
        ],
      ),
    ),
  );
  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.saveStructuredOffer(
        id: _editing ? widget.offer!.id : null,
        version: _editing ? widget.offer!.catalogVersion : null,
        data: {
          'action': 'UPSERT',
          for (final entry in _controllers.entries)
            entry.key: entry.value.text.trim(),
        },
        deliveryProof: _proof.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = catalogImportError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class CatalogConfigurationDialog extends StatefulWidget {
  const CatalogConfigurationDialog({
    super.key,
    required this.repository,
    required this.configuration,
  });
  final CatalogImportRepository repository;
  final CatalogImportConfiguration configuration;
  @override
  State<CatalogConfigurationDialog> createState() =>
      _CatalogConfigurationDialogState();
}

class _CatalogConfigurationDialogState
    extends State<CatalogConfigurationDialog> {
  late final TextEditingController _days;
  final _code = TextEditingController();
  String _network = 'ORANGE';
  late final List<Map<String, dynamic>> _families;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _days = TextEditingController(
      text: widget.configuration.verificationDays?.toString() ?? '',
    );
    _families = widget.configuration.families
        .map((f) => Map<String, dynamic>.from(f))
        .toList();
  }

  @override
  void dispose() {
    _days.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CatalogPanelDialog(
    title: 'Règles de publication et familles',
    busy: _busy,
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context, false),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: _busy ? null : _save,
        child: const Text('Enregistrer'),
      ),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) catalogNotice(_error!, error: true),
        TextField(
          controller: _days,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Vérification récente : nombre maximum de jours',
            helperText:
                '1 à 366 jours. Vide : publication bloquée, brouillons autorisés.',
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Familles chargées depuis le serveur, sans redéploiement du front.',
        ),
        for (final family in _families)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${family['network']} · ${family['code']}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Wrap(
                  spacing: 16,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: family['enabled'] == true,
                          onChanged: _busy
                              ? null
                              : (value) =>
                                    setState(() => family['enabled'] = value),
                        ),
                        const Text('Disponible'),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: family['conditional'] == true,
                          onChanged: _busy
                              ? null
                              : (value) => setState(
                                  () => family['conditional'] = value,
                                ),
                        ),
                        const Text('Preuve de livraison requise'),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        DropdownButtonFormField<String>(
          initialValue: _network,
          decoration: const InputDecoration(
            labelText: 'Opérateur pour la nouvelle famille',
          ),
          items: [
            'ORANGE',
            'MTN',
            'MOOV',
          ].map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
          onChanged: _busy ? null : (value) => _network = value!,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _code,
          enabled: !_busy,
          decoration: const InputDecoration(
            labelText: 'Code de nouvelle famille (ex. INTERNET)',
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _busy
                ? null
                : () {
                    final code = _code.text.trim().toUpperCase();
                    if (!RegExp(r'^[A-Z][A-Z0-9_]{0,39}$').hasMatch(code) ||
                        _families.any(
                          (f) => f['network'] == _network && f['code'] == code,
                        )) {
                      setState(
                        () =>
                            _error = 'Code invalide ou famille déjà présente.',
                      );
                      return;
                    }
                    setState(() {
                      _families.add({
                        'network': _network,
                        'code': code,
                        'enabled': true,
                        'conditional': true,
                      });
                      _code.clear();
                      _error = null;
                    });
                  },
            child: const Text('Ajouter la famille'),
          ),
        ),
      ],
    ),
  );
  Future<void> _save() async {
    final value = _days.text.trim(), days = int.tryParse(value);
    if (value.isNotEmpty && (days == null || days < 1 || days > 366)) {
      setState(() => _error = 'Saisissez un délai entre 1 et 366 jours.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.saveImportConfiguration(
        widget.configuration,
        days,
        _families,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = catalogImportError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
