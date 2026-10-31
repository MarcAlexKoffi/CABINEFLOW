import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/ussd/data/supabase_ussd_repository.dart';
import 'package:cabine_flow/features/ussd/domain/ussd_repository.dart';
import 'package:flutter/material.dart';

class UssdActivityPage extends StatefulWidget {
  const UssdActivityPage({
    super.key,
    required this.user,
    required this.reports,
    this.repository,
  });
  final AppUser user;
  final bool reports;
  final UssdRepository? repository;
  @override
  State<UssdActivityPage> createState() => _UssdActivityPageState();
}

class _UssdActivityPageState extends State<UssdActivityPage> {
  late final UssdRepository _repository =
      widget.repository ?? createUssdRepository();
  late Future<List<Map<String, dynamic>>> _future;
  int _offset = 0;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<List<Map<String, dynamic>>> _fetch() => widget.reports
      ? _repository.reports(offset: _offset)
      : _repository.logs(offset: _offset);
  void _reload() => setState(() => _future = _fetch());
  Future<void> _review(Map<String, dynamic> report) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _ReviewDialog(),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repository.reviewReport(
        report['id'] as String,
        result.$1,
        result.$2,
      );
      if (mounted) _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Mise à jour indisponible. Vérifiez votre périmètre et réessayez.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.reports
            ? 'Signalements USSD · Agent et Cabiniste'
            : 'Journaux d’ouverture du composeur',
      ),
      actions: [
        IconButton(
          onPressed: _busy ? null : _reload,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.reports
                ? 'Ce volet complète le centre de signalements existant. Les Managers consultent uniquement leur territoire.'
                : 'Un composeur ouvert ne prouve jamais la réalisation de l’opération télécom.',
          ),
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: OutlinedButton(
                      onPressed: _reload,
                      child: const Text('Réessayer le chargement'),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snapshot.data!;
                return Column(
                  children: [
                    Expanded(
                      child: rows.isEmpty
                          ? const Center(
                              child: Text('Aucun événement sur cette page.'),
                            )
                          : ListView.builder(
                              itemCount: rows.length,
                              itemBuilder: (context, index) {
                                final r = rows[index];
                                return Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Commande ${r['order_id']} · ${r['network']} · ${r['actor_type']}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleSmall,
                                        ),
                                        Text(
                                          'Règle ${r['rule_id'] ?? 'non disponible'} · V${r['rule_version'] ?? '—'}',
                                        ),
                                        Text(
                                          'Acteur : ${r['actor_uid']} · ${r['created_at'] ?? r['generated_at']}',
                                        ),
                                        if (widget.reports) ...[
                                          Text(
                                            'Motif : ${r['reason']} · Statut : ${r['status']}',
                                          ),
                                          if ((r['note'] as String? ?? '')
                                              .isNotEmpty)
                                            Text(r['note'] as String),
                                          if ((r['review_note'] as String? ??
                                                  '')
                                              .isNotEmpty)
                                            Text(
                                              'Supervision : ${r['review_note']}',
                                            ),
                                          for (final e
                                              in (r['events'] as List? ?? []))
                                            Text(
                                              '${e['occurred_at']} · ${e['status']} · ${e['note']}',
                                            ),
                                          TextButton(
                                            onPressed: _busy
                                                ? null
                                                : () => _review(r),
                                            child: const Text(
                                              'Prendre en charge / transmettre à l’Administrateur',
                                            ),
                                          ),
                                        ] else ...[
                                          Text(
                                            'Ouverture : ${r['launch_status']} · ${r['error_code'] ?? 'aucune erreur déclarée'}',
                                          ),
                                          Text(
                                            'Version association offre : ${r['binding_version'] ?? '—'}',
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _offset == 0
                              ? null
                              : () {
                                  _offset -= 50;
                                  _reload();
                                },
                          child: const Text('Page précédente'),
                        ),
                        Text('Page ${_offset ~/ 50 + 1}'),
                        TextButton(
                          onPressed: rows.length < 50
                              ? null
                              : () {
                                  _offset += 50;
                                  _reload();
                                },
                          child: const Text('Page suivante'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog();
  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  String _status = 'in_progress';
  final _note = TextEditingController();
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Suivi du signalement'),
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _status,
            isExpanded: true,
            items: const [
              DropdownMenuItem(
                value: 'in_progress',
                child: Text('Pris en charge'),
              ),
              DropdownMenuItem(
                value: 'escalated',
                child: Text('Transmis à l’Administrateur'),
              ),
              DropdownMenuItem(value: 'resolved', child: Text('Résolu')),
            ],
            onChanged: (v) => setState(() => _status = v!),
          ),
          TextField(
            controller: _note,
            maxLength: 500,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Note sans numéro ni code complet',
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
        onPressed: () => Navigator.pop(context, (_status, _note.text.trim())),
        child: const Text('Enregistrer'),
      ),
    ],
  );
}
