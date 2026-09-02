import 'package:cabine_flow/features/agents/data/repositories/firestore_agent_personal_media_repository.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_personal_media.dart';
import 'package:cabine_flow/features/agents/presentation/pages/agent_activity_v2_dashboard_page.dart';
import 'package:cabine_flow/features/commissions/presentation/pages/commission_v2_dashboard_page.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class AdminAgentProfileActivityPage extends StatefulWidget {
  const AdminAgentProfileActivityPage({
    super.key,
    required this.agentId,
    required this.agentName,
  });

  final String agentId;
  final String agentName;

  @override
  State<AdminAgentProfileActivityPage> createState() =>
      _AdminAgentProfileActivityPageState();
}

class _AdminAgentProfileActivityPageState
    extends State<AdminAgentProfileActivityPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final FirestoreAgentPersonalMediaRepository _mediaRepository;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _mediaRepository = FirestoreAgentPersonalMediaRepository(
      firestore: _firestore,
    );
  }

  Future<void> _setVerification(
    String status, {
    String? note,
  }) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      if (status == 'verified') {
        final AgentPersonalMedia? identity = await _mediaRepository.fetch(
          agentId: widget.agentId,
          kind: AgentPersonalMediaKind.identity,
        );
        if (identity == null) {
          throw StateError(
            'Impossible de vérifier ce profil sans pièce d’identité enregistrée.',
          );
        }
      }
      await _firestore
          .collection('agentPersonalProfiles')
          .doc(widget.agentId)
          .update(<String, dynamic>{
            'verificationStatus': status,
            'verificationNote': note,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      if (!mounted) return;
      IzyTelFeedback.success(context, _verificationLabel(status));
    } on FirebaseException catch (error) {
      if (!mounted) return;
      IzyTelFeedback.error(context, error.message ?? error.code);
    } catch (error) {
      if (!mounted) return;
      IzyTelFeedback.error(
        context,
        error.toString().replaceFirst('Bad state: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _requestCorrection() async {
    final controller = TextEditingController();
    final String? note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Demander une correction'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 500,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Indique ce que l’Agent doit corriger.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note != null && mounted) {
      await _setVerification('needsCorrection', note: note);
    }
  }

  Future<void> _saveIdentityLocally(AgentPersonalMedia media) async {
    try {
      await FilePicker.saveFile(
        dialogTitle: 'Enregistrer la pièce d’identité',
        fileName: media.fileName,
        mimeType: media.mimeType,
        bytes: media.bytes,
      );
    } catch (error) {
      if (!mounted) return;
      IzyTelFeedback.error(context, 'Export impossible : $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileStream = _firestore
        .collection('agentPersonalProfiles')
        .doc(widget.agentId)
        .snapshots();
    return Scaffold(
      appBar: AppBar(title: const Text('Profil & activité Agent')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: profileStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final Map<String, dynamic>? profile = snapshot.data!.data();
          if (profile == null) {
            return _NoProfile(
              agentName: widget.agentName,
              onActivity: () => _openActivity(context),
              onCommissions: () => _openAgentCommissions(context),
              onGlobalCommissions: () => _openGlobalCommissions(context),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: <Widget>[
              _ProfileSummary(
                agentId: widget.agentId,
                agentName: widget.agentName,
                profile: profile,
                mediaRepository: _mediaRepository,
              ),
              const SizedBox(height: 14),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'Vérification',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _verificationLabel(_text(profile['verificationStatus'])),
                      ),
                      if (_nullableText(profile['verificationNote']) != null) ...<Widget>[
                        const SizedBox(height: 6),
                        Text('Note : ${_nullableText(profile['verificationNote'])}'),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          FilledButton.icon(
                            onPressed: _isUpdating
                                ? null
                                : () => _setVerification(
                                    'verified',
                                    note: null,
                                  ),
                            icon: const Icon(Icons.verified_outlined),
                            label: const Text('Marquer vérifié'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _isUpdating ? null : _requestCorrection,
                            icon: const Icon(Icons.edit_note_outlined),
                            label: const Text('Demander correction'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              StreamBuilder<AgentPersonalMedia?>(
                stream: _mediaRepository.watch(
                  agentId: widget.agentId,
                  kind: AgentPersonalMediaKind.identity,
                ),
                builder: (context, identitySnapshot) {
                  final AgentPersonalMedia? identity = identitySnapshot.data;
                  return _IdentityAdminCard(
                    media: identity,
                    onSave: identity == null
                        ? null
                        : () => _saveIdentityLocally(identity),
                  );
                },
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => _openActivity(context),
                icon: const Icon(Icons.insights_outlined),
                label: const Text('Ouvrir l’activité complète'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _openAgentCommissions(context),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Commissions de cet agent'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _openGlobalCommissions(context),
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('Vue globale des commissions'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openActivity(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AgentActivityV2DashboardPage(
          agentId: widget.agentId,
          agentName: widget.agentName,
          adminMode: true,
        ),
      ),
    );
  }

  void _openAgentCommissions(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminAgentCommissionsV2Page(
          agentId: widget.agentId,
          agentName: widget.agentName,
        ),
      ),
    );
  }

  void _openGlobalCommissions(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AdminCommissionsV2Page()),
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({
    required this.agentId,
    required this.agentName,
    required this.profile,
    required this.mediaRepository,
  });

  final String agentId;
  final String agentName;
  final Map<String, dynamic> profile;
  final FirestoreAgentPersonalMediaRepository mediaRepository;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                StreamBuilder<AgentPersonalMedia?>(
                  stream: mediaRepository.watch(
                    agentId: agentId,
                    kind: AgentPersonalMediaKind.avatar,
                  ),
                  builder: (context, snapshot) {
                    final bytes = snapshot.data?.bytes;
                    return CircleAvatar(
                      radius: 36,
                      foregroundImage: bytes == null ? null : MemoryImage(bytes),
                      child: bytes == null
                          ? const Icon(Icons.person_outline, size: 32)
                          : null,
                    );
                  },
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _fullName(profile, fallback: agentName),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(_text(profile['contact1'])),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            _Line(label: 'Naissance', value: _dateLabel(profile['dateOfBirth'])),
            _Line(label: 'Adresse', value: _text(profile['address'])),
            _Line(label: 'Ville / commune', value: _text(profile['city'])),
            _Line(label: 'Contact 2', value: _emptyDash(profile['contact2'])),
            _Line(
              label: 'Urgence',
              value: '${_emptyDash(profile['emergencyContactName'])} • '
                  '${_emptyDash(profile['emergencyContactPhone'])}',
            ),
            _Line(
              label: 'Pièce',
              value: _identityLabel(_text(profile['identityDocumentType'])),
            ),
            _Line(
              label: 'N° pièce',
              value: _emptyDash(profile['identityDocumentNumber']),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentityAdminCard extends StatelessWidget {
  const _IdentityAdminCard({required this.media, required this.onSave});

  final AgentPersonalMedia? media;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Document d’identité',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (media == null)
              const Text('Aucun document Blob enregistré.')
            else ...<Widget>[
              if (media!.mimeType == 'image/jpeg')
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    media!.bytes,
                    height: 280,
                    fit: BoxFit.contain,
                  ),
                )
              else
                const SizedBox(
                  height: 120,
                  child: Center(
                    child: Icon(Icons.picture_as_pdf_outlined, size: 54),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                '${media!.fileName} • ${(media!.sizeBytes / 1024).round()} Ko',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save_alt_outlined),
                label: const Text('Enregistrer une copie locale'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 112,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value.isEmpty ? '—' : value)),
        ],
      ),
    );
  }
}

class _NoProfile extends StatelessWidget {
  const _NoProfile({
    required this.agentName,
    required this.onActivity,
    required this.onCommissions,
    required this.onGlobalCommissions,
  });

  final String agentName;
  final VoidCallback onActivity;
  final VoidCallback onCommissions;
  final VoidCallback onGlobalCommissions;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.person_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text('$agentName n’a pas encore complété son profil personnel.'),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onActivity,
              icon: const Icon(Icons.insights_outlined),
              label: const Text('Voir quand même l’activité'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onCommissions,
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Commissions de cet agent'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onGlobalCommissions,
              child: const Text('Vue globale des commissions'),
            ),
          ],
        ),
      ),
    );
  }
}

String _verificationLabel(String value) => switch (value) {
  'verified' => 'Profil vérifié',
  'pendingReview' => 'En attente de vérification',
  'needsCorrection' => 'Corrections demandées',
  _ => 'Profil incomplet',
};

String _identityLabel(String value) => switch (value) {
  'nationalId' => 'CNI',
  'passport' => 'Passeport',
  'drivingLicense' => 'Permis de conduire',
  'residencePermit' => 'Titre de séjour',
  _ => value.isEmpty ? '—' : value,
};

String _fullName(Map<String, dynamic> profile, {required String fallback}) {
  final text = '${_text(profile['firstName'])} ${_text(profile['lastName'])}'.trim();
  return text.isEmpty ? fallback : text;
}

String _dateLabel(Object? value) {
  DateTime? date;
  if (value is Timestamp) date = value.toDate();
  if (value is DateTime) date = value;
  if (date == null) return '—';
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}

String _emptyDash(Object? value) {
  final text = _text(value);
  return text.isEmpty ? '—' : text;
}
String _text(Object? value) => value is String ? value.trim() : '';
String? _nullableText(Object? value) {
  final text = _text(value);
  return text.isEmpty ? null : text;
}
