import 'dart:async';
import 'dart:math';
import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/features/ussd/data/supabase_ussd_repository.dart';
import 'package:cabine_flow/features/ussd/domain/ussd_engine.dart';
import 'package:cabine_flow/features/ussd/domain/ussd_repository.dart';
import 'package:cabine_flow/features/ussd/platform/ussd_dialer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class UssdQuickProcessingCard extends StatefulWidget {
  const UssdQuickProcessingCard({
    super.key,
    required this.orderId,
    required this.network,
    required this.offerLabel,
    required this.beneficiary,
    required this.amount,
    required this.processable,
    this.initiallyExpanded = true,
    this.repository,
    this.dialer,
  });
  final String orderId, network, offerLabel, beneficiary;
  final int amount;
  final bool processable;
  final bool initiallyExpanded;
  final UssdRepository? repository;
  final UssdDialer? dialer;
  @override
  State<UssdQuickProcessingCard> createState() =>
      _UssdQuickProcessingCardState();
}

class _UssdQuickProcessingCardState extends State<UssdQuickProcessingCard>
    with WidgetsBindingObserver {
  late UssdRepository _repository;
  late UssdDialer _dialer;
  UssdResolution? _resolution;
  UssdResolution? _lastResolution;
  String? _message;
  bool _loading = true, _busy = false;
  bool _confirming = false;
  late bool _expanded;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? createUssdRepository();
    _dialer = widget.dialer ?? const AndroidUssdDialer();
    _expanded = widget.initiallyExpanded;
    WidgetsBinding.instance.addObserver(this);
    if (_expanded) {
      unawaited(_load());
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant UssdQuickProcessingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId ||
        oldWidget.processable != widget.processable ||
        oldWidget.network != widget.network ||
        oldWidget.beneficiary != widget.beneficiary ||
        oldWidget.amount != widget.amount ||
        oldWidget.repository != widget.repository) {
      _generation++;
      _resolution = null;
      _lastResolution = null;
      _repository = widget.repository ?? createUssdRepository();
      if (_expanded) {
        unawaited(_load());
      } else {
        _loading = false;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy && _expanded) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _resolution = null;
      _message = null;
    });
    if (!widget.processable) {
      setState(() {
        _loading = false;
        _message = _unavailable('order_not_processable');
      });
      return;
    }
    try {
      final result = await _repository.resolve(widget.orderId);
      if (!mounted || generation != _generation) return;
      setState(() {
        _resolution = result;
        if (result.available) _lastResolution = result;
        _loading = false;
        _message = result.available ? null : _unavailable(result.reason);
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _message = UssdEngine.manualMessage;
      });
    }
  }

  Future<bool> _confirm(UssdResolution result, {required bool copy}) async {
    final contextData = result.context;
    setState(() => _confirming = true);
    try {
      return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(copy ? 'Vérifier le code' : 'Vérifier l’opération'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Réseau / SIM requis : ${_network(contextData['network'] as String? ?? widget.network)}',
                    ),
                    Text(
                      'Offre : ${contextData['offer_label'] ?? widget.offerLabel}',
                    ),
                    Text(
                      'Bénéficiaire : ${contextData['beneficiary'] ?? widget.beneficiary}',
                    ),
                    Text(
                      'Montant de commande : ${contextData['amount'] ?? widget.amount} FCFA',
                    ),
                    const SizedBox(height: 12),
                    Text(result.code!),
                    if (result.mismatch) ...[
                      const SizedBox(height: 12),
                      const Text(
                        UssdEngine.mismatchMessage,
                        style: TextStyle(color: IzyTelColors.warning),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      copy
                          ? 'Le code copié ne confirme aucune opération télécom.'
                          : 'Choisissez la SIM appropriée et confirmez vous-même dans le composeur. Déclarez ensuite le résultat réel dans IzyTel.',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    copy ? 'Confirmer et copier' : 'Confirmer et ouvrir',
                  ),
                ),
              ],
            ),
          ) ??
          false;
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<void> _execute({required bool copy}) async {
    if (_busy || !widget.processable) return;
    final generation = _generation;
    final orderId = widget.orderId;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      // Always fetch again before confirmation, even when the preview is fresh.
      final fresh = await _repository.resolve(orderId);
      if (!mounted || generation != _generation) return;
      setState(() {
        _resolution = fresh;
        if (fresh.available) _lastResolution = fresh;
      });
      if (!fresh.available) throw UssdValidationException(fresh.reason);
      UssdEngine.validateCode(fresh.code!);
      if (!await _confirm(fresh, copy: copy)) return;
      if (!mounted || generation != _generation || !widget.processable) return;
      if (copy) {
        // A rule may be revoked while the confirmation dialog is open.
        final checked = await _repository.resolve(orderId);
        if (!mounted || generation != _generation) return;
        if (!checked.available || !_same(checked, fresh)) {
          throw const UssdValidationException('rule_changed');
        }
        await Clipboard.setData(ClipboardData(text: checked.code!));
        if (mounted) {
          setState(
            () => _message =
                'Code copié. Vérifiez le réseau/SIM avant utilisation.',
          );
        }
        return;
      }
      final requestId =
          '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
      final preparationClock = Stopwatch()..start();
      final prepared = await _repository.prepare(orderId, fresh, requestId);
      if (!mounted || generation != _generation) return;
      if (!prepared.available ||
          !_same(prepared, fresh) ||
          prepared.attemptId == null) {
        throw const UssdValidationException('rule_changed');
      }
      // Consume a short server lease including request/response time. This is
      // conservative and independent of the phone's wall-clock/timezone.
      if (prepared.validForMs == null ||
          preparationClock.elapsedMilliseconds >= prepared.validForMs!) {
        try {
          await _repository.recordResult(
            prepared.attemptId!,
            'failed',
            'interrupted',
          );
        } catch (_) {}
        throw const UssdValidationException('rule_changed');
      }
      UssdEngine.validateCode(prepared.code!);
      String status = 'dialer_opened';
      String? errorCode;
      try {
        await _dialer.open(prepared.code!);
      } catch (_) {
        status = 'failed';
        errorCode = 'dialer_unavailable';
      }
      // Audit failures cannot be reported as a successful telecom operation.
      bool auditSaved = true;
      try {
        await _repository.recordResult(prepared.attemptId!, status, errorCode);
      } catch (_) {
        auditSaved = false;
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        _resolution = null;
        _message = status == 'failed'
            ? '${UssdEngine.message(errorCode!)} ${UssdEngine.manualMessage}'
            : 'Composeur ouvert. Déclarez le résultat réel avec les actions habituelles.';
        if (!auditSaved) {
          _message =
              '${_message!} Le résultat d’ouverture n’a pas pu être journalisé.';
        }
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _resolution = null;
        _message = error is UssdValidationException
            ? _unavailable(error.code)
            : UssdEngine.manualMessage;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _same(UssdResolution a, UssdResolution b) =>
      a.rule?.id == b.rule?.id &&
      a.rule?.version == b.rule?.version &&
      a.code == b.code &&
      mapEquals(a.context, b.context);

  String _unavailable(String reason) {
    final message = UssdEngine.message(reason);
    return message == UssdEngine.manualMessage
        ? message
        : '$message ${UssdEngine.manualMessage}';
  }

  Future<void> _report() async {
    if (_busy) return;
    final orderId = widget.orderId;
    final generation = _generation;
    final report = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _ReportDialog(),
    );
    if (report == null || !mounted || generation != _generation) return;
    setState(() => _busy = true);
    try {
      await _repository.report(orderId, _lastResolution, report.$1, report.$2);
      if (mounted && generation == _generation) {
        setState(
          () => _message =
              'Signalement transmis au centre de supervision. Le traitement manuel reste disponible.',
        );
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _message =
              'Signalement indisponible. Réessayez ou contactez votre Manager.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final available =
        _resolution?.available == true &&
        !_loading &&
        !_busy &&
        widget.processable;
    return Card(
      child: ExpansionTile(
        initiallyExpanded: widget.initiallyExpanded,
        title: Text(
          'Traitement rapide',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text('Réseau / SIM requis : ${_network(widget.network)}'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        onExpansionChanged: (expanded) {
          _expanded = expanded;
          if (expanded && !_busy) unawaited(_load());
        },
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Réseau / SIM requis : ${_network(_resolution?.context['network'] as String? ?? widget.network)}',
              ),
              Text(
                _resolution?.context['offer_label'] as String? ??
                    widget.offerLabel,
              ),
              Text(
                'Bénéficiaire : ${_resolution?.context['beneficiary'] ?? widget.beneficiary}',
              ),
              Text(
                'Montant de commande : ${_resolution?.context['amount'] ?? widget.amount} FCFA',
              ),
              if (_loading || (_busy && !_confirming))
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: LinearProgressIndicator(),
                ),
              if (_resolution?.available == true) ...[
                const SizedBox(height: 10),
                Text(_resolution!.code!),
                Text('Version ${_resolution!.rule!.version}'),
                if (_resolution!.mismatch)
                  const Text(
                    UssdEngine.mismatchMessage,
                    style: TextStyle(color: IzyTelColors.warning),
                  ),
              ],
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(_message!, key: const ValueKey('ussd-message')),
                ),
              if (!_dialer.supported)
                const Text(
                  'L’ouverture du composeur est disponible sur Android.',
                ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: available && _dialer.supported
                    ? () => _execute(copy: false)
                    : null,
                icon: const Icon(Icons.dialpad),
                label: const Text('Lancer l’opération'),
              ),
              OutlinedButton.icon(
                onPressed: available ? () => _execute(copy: true) : null,
                icon: const Icon(Icons.copy),
                label: const Text('Copier le code'),
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: _busy || _loading ? null : _load,
                    child: const Text('Actualiser le raccourci'),
                  ),
                  TextButton(
                    onPressed: _busy || !widget.processable ? null : _report,
                    child: const Text('Signaler un problème'),
                  ),
                ],
              ),
              const Text(
                'Les actions habituelles de traitement et de preuve restent disponibles.',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _network(String value) => switch (value) {
    'orange' => 'Orange',
    'mtn' => 'MTN',
    'moov' => 'Moov Africa',
    _ => value,
  };
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog();
  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String _reason = 'incorrect_code';
  final _note = TextEditingController();
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Signaler un raccourci'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _reason,
            isExpanded: true,
            items: const [
              DropdownMenuItem(
                value: 'incorrect_code',
                child: Text('Code incorrect'),
              ),
              DropdownMenuItem(
                value: 'expired_code',
                child: Text('Code expiré'),
              ),
              DropdownMenuItem(
                value: 'wrong_offer',
                child: Text('Mauvaise offre'),
              ),
              DropdownMenuItem(
                value: 'operator_menu_changed',
                child: Text('Menu opérateur modifié'),
              ),
              DropdownMenuItem(value: 'other', child: Text('Autre')),
            ],
            onChanged: (v) => setState(() => _reason = v!),
          ),
          TextField(
            controller: _note,
            maxLength: 500,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Précisions facultatives',
              helperText: 'N’indiquez aucun numéro ni code USSD complet.',
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
        onPressed: () => Navigator.pop(context, (_reason, _note.text.trim())),
        child: const Text('Transmettre'),
      ),
    ],
  );
}
