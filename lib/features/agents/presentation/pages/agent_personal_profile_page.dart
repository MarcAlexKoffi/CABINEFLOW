import 'dart:typed_data';

import 'package:cabine_flow/features/agents/data/repositories/firestore_agent_personal_media_repository.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_personal_media.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/agents/presentation/pages/agent_activity_v2_dashboard_page.dart';
import 'package:cabine_flow/features/commissions/presentation/pages/commission_v2_dashboard_page.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AgentPersonalProfilePage extends StatefulWidget {
  const AgentPersonalProfilePage({
    super.key,
    required this.user,
    required this.repository,
    this.firestore,
  });

  final AppUser user;
  final AgentRepository repository;
  final FirebaseFirestore? firestore;

  @override
  State<AgentPersonalProfilePage> createState() =>
      _AgentPersonalProfilePageState();
}

class _AgentPersonalProfilePageState extends State<AgentPersonalProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  FirebaseFirestore? _firestore;
  FirestoreAgentPersonalMediaRepository? _mediaRepository;

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _contact1 = TextEditingController();
  final _contact2 = TextEditingController();
  final _emergencyName = TextEditingController();
  final _emergencyPhone = TextEditingController();
  final _identityNumber = TextEditingController();

  DateTime? _dateOfBirth;
  String _identityType = 'nationalId';
  String _verificationStatus = 'incomplete';
  String? _verificationNote;
  Map<String, dynamic>? _existingProfile;
  AgentPersonalMedia? _avatarMedia;
  AgentPersonalMedia? _identityMedia;
  PreparedAgentMedia? _pendingAvatar;
  PreparedAgentMedia? _pendingIdentity;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  String? _mediaWarning;

  bool get _isVerified => _verificationStatus == 'verified';

  @override
  void initState() {
    super.initState();
    final FirebaseFirestore? firestore = widget.firestore ??
        (Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null);
    _firestore = firestore;
    if (firestore != null) {
      _mediaRepository = FirestoreAgentPersonalMediaRepository(
        firestore: firestore,
      );
    }
    _load();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _address.dispose();
    _city.dispose();
    _contact1.dispose();
    _contact2.dispose();
    _emergencyName.dispose();
    _emergencyPhone.dispose();
    _identityNumber.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
        _mediaWarning = null;
      });
    }

    // Toujours afficher au minimum les informations déjà connues du compte
    // connecté. Un échec Firestore sur un média ne doit jamais vider le
    // formulaire personnel.
    _hydrateFromSignedInUser();

    final FirebaseFirestore? firestore = _firestore;
    final FirestoreAgentPersonalMediaRepository? mediaRepository =
        _mediaRepository;
    if (firestore == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final profileSnapshot = await firestore
          .collection('agentPersonalProfiles')
          .doc(widget.user.id)
          .get();
      final Map<String, dynamic>? data = profileSnapshot.data();
      if (data != null) {
        _existingProfile = Map<String, dynamic>.from(data);
        _firstName.text = _text(data['firstName']);
        _lastName.text = _text(data['lastName']);
        _address.text = _text(data['address']);
        _city.text = _text(data['city']);
        _contact1.text = _text(data['contact1']);
        _contact2.text = _text(data['contact2']);
        _emergencyName.text = _text(data['emergencyContactName']);
        _emergencyPhone.text = _text(data['emergencyContactPhone']);
        _identityNumber.text = _text(data['identityDocumentNumber']);
        _dateOfBirth = _date(data['dateOfBirth']);
        _identityType = _text(data['identityDocumentType']).isEmpty
            ? 'nationalId'
            : _text(data['identityDocumentType']);
        _verificationStatus = _text(data['verificationStatus']).isEmpty
            ? 'incomplete'
            : _text(data['verificationStatus']);
        _verificationNote = _nullableText(data['verificationNote']);
      }
    } on FirebaseException catch (error) {
      _error = error.code == 'permission-denied'
          ? 'Impossible de lire le profil Firestore pour le moment. '
                'Les informations du compte restent affichées. Publie les règles B2+C puis réessaie.'
          : 'Impossible de charger les informations personnelles : '
                '${error.message ?? error.code}';
    } catch (error) {
      _error = 'Impossible de charger les informations personnelles : $error';
    }

    final List<String> unavailableMedia = <String>[];
    if (mediaRepository != null) {
      try {
        _avatarMedia = await mediaRepository.fetch(
          agentId: widget.user.id,
          kind: AgentPersonalMediaKind.avatar,
        );
      } catch (_) {
        _avatarMedia = null;
        unavailableMedia.add('photo de profil');
      }

      try {
        _identityMedia = await mediaRepository.fetch(
          agentId: widget.user.id,
          kind: AgentPersonalMediaKind.identity,
        );
      } catch (_) {
        _identityMedia = null;
        unavailableMedia.add('pièce d’identité');
      }
    }

    _pendingAvatar = null;
    _pendingIdentity = null;
    if (unavailableMedia.isNotEmpty) {
      _mediaWarning =
          'Certains médias du profil sont temporairement indisponibles '
          '(${unavailableMedia.join(', ')}). Le formulaire reste utilisable ; '
          'réessaie après publication des règles B2+C.';
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _hydrateFromSignedInUser() {
    if (_firstName.text.isNotEmpty || _lastName.text.isNotEmpty) return;
    final List<String> parts = widget.user.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isNotEmpty) {
      _firstName.text = parts.first;
      _lastName.text = parts.length > 1 ? parts.skip(1).join(' ') : 'Agent';
    }
    _contact1.text = widget.user.phoneNumber.trim();
  }

  Future<void> _pickAvatar() async {
    final ImageSource? source = await _chooseImageSource(
      title: 'Photo de profil',
    );
    if (source == null) return;
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 95,
      );
      if (file == null) return;
      final Uint8List bytes = await file.readAsBytes();
      final mediaRepository = _mediaRepository;
      if (mediaRepository == null) {
        throw StateError('Firebase doit être initialisé pour enregistrer la photo.');
      }
      final prepared = mediaRepository.prepareAvatar(
        source: bytes,
        fileName: file.name,
      );
      if (!mounted) return;
      setState(() => _pendingAvatar = prepared);
    } catch (error) {
      _showError('$error');
    }
  }

  Future<void> _pickIdentityImage() async {
    if (_isVerified) {
      _showError('La pièce d’identité est verrouillée après vérification.');
      return;
    }
    final ImageSource? source = await _chooseImageSource(
      title: 'Pièce d’identité',
    );
    if (source == null) return;
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 95,
      );
      if (file == null) return;
      final Uint8List bytes = await file.readAsBytes();
      final mediaRepository = _mediaRepository;
      if (mediaRepository == null) {
        throw StateError('Firebase doit être initialisé pour enregistrer la pièce.');
      }
      final prepared = mediaRepository.prepareIdentityImage(
        source: bytes,
        fileName: file.name,
      );
      if (!mounted) return;
      setState(() => _pendingIdentity = prepared);
    } catch (error) {
      _showError('$error');
    }
  }

  Future<void> _pickIdentityPdf() async {
    if (_isVerified) {
      _showError('La pièce d’identité est verrouillée après vérification.');
      return;
    }
    try {
      final PlatformFile? file = await FilePicker.pickFile(
        dialogTitle: 'Sélectionner la pièce d’identité PDF',
        type: FileType.custom,
        allowedExtensions: const <String>['pdf'],
      );
      if (file == null) return;
      final int length = await file.length();
      if (length > FirestoreAgentPersonalMediaRepository.identityMaxBytes) {
        throw StateError('Le PDF doit faire moins de 850 Ko.');
      }
      final Uint8List bytes = await file.readAsBytes();
      final mediaRepository = _mediaRepository;
      if (mediaRepository == null) {
        throw StateError('Firebase doit être initialisé pour enregistrer la pièce.');
      }
      final prepared = mediaRepository.prepareIdentityPdf(
        source: bytes,
        fileName: file.name,
      );
      if (!mounted) return;
      setState(() => _pendingIdentity = prepared);
    } catch (error) {
      _showError('$error');
    }
  }

  Future<ImageSource?> _chooseImageSource({required String title}) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickBirthDate() async {
    final DateTime now = DateTime.now();
    final DateTime firstDate = DateTime(1940);
    final DateTime lastDate = DateTime(now.year - 16, now.month, now.day);
    final DateTime candidate = _dateOfBirth ?? DateTime(now.year - 25, 1, 1);
    final DateTime initial = candidate.isBefore(firstDate)
        ? firstDate
        : candidate.isAfter(lastDate)
        ? lastDate
        : candidate;
    final DateTime? result = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (result != null && mounted) setState(() => _dateOfBirth = result);
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    if (_dateOfBirth == null) {
      _showError('Indique la date de naissance.');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final String firstName = _firstName.text.trim();
      final String lastName = _lastName.text.trim();
      final String displayName = '$firstName $lastName'.trim();
      final bool avatarPresent = _pendingAvatar != null || _avatarMedia != null;
      final bool identityPresent =
          _pendingIdentity != null || _identityMedia != null;
      final String nextVerification = _isVerified
          ? 'verified'
          : avatarPresent && identityPresent
          ? 'pendingReview'
          : 'incomplete';

      final FirebaseFirestore? firestore = _firestore;
      final FirestoreAgentPersonalMediaRepository? mediaRepository =
          _mediaRepository;
      if (firestore == null || mediaRepository == null) {
        _verificationStatus = nextVerification;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mode de test local : aucune écriture Firebase effectuée.'),
            ),
          );
        }
        return;
      }

      final DocumentReference<Map<String, dynamic>> profileRef = firestore
          .collection('agentPersonalProfiles')
          .doc(widget.user.id);
      final DocumentReference<Map<String, dynamic>> userRef = firestore
          .collection('users')
          .doc(widget.user.id);
      final WriteBatch batch = firestore.batch();
      final Object createdAt = _existingProfile?['createdAt'] ??
          FieldValue.serverTimestamp();
      final String? identityFileName = _pendingIdentity?.fileName ??
          _identityMedia?.fileName ??
          _nullableText(_existingProfile?['identityDocumentFileName']);
      final String? identityMimeType = _pendingIdentity?.mimeType ??
          _identityMedia?.mimeType ??
          _nullableText(_existingProfile?['identityDocumentMimeType']);

      final Map<String, dynamic> profileData = <String, dynamic>{
        'schemaVersion': 1,
        'userId': widget.user.id,
        'firstName': firstName,
        'lastName': lastName,
        'dateOfBirth': Timestamp.fromDate(_dateOfBirth!),
        'address': _address.text.trim(),
        'city': _city.text.trim(),
        'contact1': _contact1.text.trim(),
        'contact2': _contact2.text.trim(),
        'emergencyContactName': _emergencyName.text.trim(),
        'emergencyContactPhone': _emergencyPhone.text.trim(),
        'identityDocumentType': _identityType,
        'identityDocumentNumber': _identityNumber.text.trim(),
        // Compatibilité du schéma A+B : ces anciens chemins sont conservés
        // mais B2 ne lit ni n’écrit aucun fichier dans Firebase Storage.
        'avatarStoragePath': _existingProfile?['avatarStoragePath'],
        'identityDocumentStoragePath':
            _existingProfile?['identityDocumentStoragePath'],
        'identityDocumentFileName': identityFileName,
        'identityDocumentMimeType': identityMimeType,
        'verificationStatus': nextVerification,
        'verificationNote': _isVerified ? _verificationNote : null,
        'createdAt': createdAt,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      batch.set(profileRef, profileData);
      batch.update(userRef, <String, dynamic>{
        'name': displayName,
        'phoneNumber': _contact1.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _queueMediaWrite(
        batch: batch,
        pending: _pendingAvatar,
        existing: _avatarMedia,
        mediaRepository: mediaRepository,
      );
      _queueMediaWrite(
        batch: batch,
        pending: _pendingIdentity,
        existing: _identityMedia,
        mediaRepository: mediaRepository,
      );
      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil enregistré.')),
      );
      await _load();
    } on FirebaseException catch (error) {
      _showError(
        error.code == 'permission-denied'
            ? 'Firestore refuse l’enregistrement. Publie d’abord les règles B2+C fournies.'
            : 'Firebase : ${error.message ?? error.code}',
      );
    } catch (error) {
      _showError('$error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _queueMediaWrite({
    required WriteBatch batch,
    required PreparedAgentMedia? pending,
    required AgentPersonalMedia? existing,
    required FirestoreAgentPersonalMediaRepository mediaRepository,
  }) {
    if (pending == null) return;
    final ref = mediaRepository.mediaRef(
      agentId: widget.user.id,
      kind: pending.kind,
    );
    if (existing == null) {
      batch.set(
        ref,
        mediaRepository.createData(agentId: widget.user.id, media: pending),
      );
    } else {
      batch.set(
        ref,
        <String, dynamic>{
          ...mediaRepository.updateData(media: pending),
          'agentId': widget.user.id,
        },
        SetOptions(merge: true),
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Informations personnelles')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: <Widget>[
            _ProfileMediaHeader(
              bytes: _pendingAvatar?.bytes ?? _avatarMedia?.bytes,
              status: _verificationStatus,
              onPick: _pickAvatar,
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              _InfoCard(icon: Icons.error_outline, text: _error!),
            ],
            if (_mediaWarning != null) ...<Widget>[
              const SizedBox(height: 12),
              _InfoCard(
                icon: Icons.image_not_supported_outlined,
                text: _mediaWarning!,
              ),
            ],
            if (_verificationNote != null) ...<Widget>[
              const SizedBox(height: 12),
              _InfoCard(
                icon: Icons.info_outline,
                text: 'Note de vérification : $_verificationNote',
              ),
            ],
            const SizedBox(height: 18),
            _sectionTitle(context, 'Identité'),
            const SizedBox(height: 8),
            _twoFields(
              _field(
                _firstName,
                'Prénom(s)',
                locked: _isVerified,
                minLength: 2,
                maxLength: 80,
              ),
              _field(
                _lastName,
                'Nom',
                locked: _isVerified,
                minLength: 2,
                maxLength: 80,
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _isVerified ? null : _pickBirthDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date de naissance',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_month_outlined),
                ),
                child: Text(_dateLabel(_dateOfBirth)),
              ),
            ),
            const SizedBox(height: 10),
            _field(
              _address,
              'Adresse / quartier',
              minLength: 3,
              maxLength: 200,
            ),
            const SizedBox(height: 10),
            _field(
              _city,
              'Ville / commune',
              minLength: 2,
              maxLength: 100,
            ),
            const SizedBox(height: 18),
            _sectionTitle(context, 'Contacts'),
            const SizedBox(height: 8),
            _field(
              _contact1,
              'Contact principal',
              minLength: 8,
              maxLength: 30,
              keyboard: TextInputType.phone,
            ),
            const SizedBox(height: 10),
            _field(
              _contact2,
              'Contact secondaire (facultatif)',
              required: false,
              maxLength: 30,
              keyboard: TextInputType.phone,
            ),
            const SizedBox(height: 10),
            _twoFields(
              _field(
                _emergencyName,
                'Contact d’urgence — nom',
                required: false,
                maxLength: 100,
              ),
              _field(
                _emergencyPhone,
                'Téléphone urgence',
                required: false,
                maxLength: 30,
                keyboard: TextInputType.phone,
              ),
            ),
            const SizedBox(height: 18),
            _sectionTitle(context, 'Pièce d’identité'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _identityType,
              decoration: const InputDecoration(
                labelText: 'Type de pièce',
                border: OutlineInputBorder(),
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'nationalId', child: Text('CNI')),
                DropdownMenuItem(value: 'passport', child: Text('Passeport')),
                DropdownMenuItem(
                  value: 'drivingLicense',
                  child: Text('Permis de conduire'),
                ),
                DropdownMenuItem(
                  value: 'residencePermit',
                  child: Text('Titre de séjour'),
                ),
                DropdownMenuItem(value: 'other', child: Text('Autre')),
              ],
              onChanged: _isVerified
                  ? null
                  : (value) {
                      if (value != null) setState(() => _identityType = value);
                    },
            ),
            const SizedBox(height: 10),
            _field(
              _identityNumber,
              'Numéro de pièce (facultatif)',
              required: false,
              locked: _isVerified,
              maxLength: 80,
            ),
            const SizedBox(height: 12),
            _IdentityMediaCard(
              media: _pendingIdentity,
              current: _identityMedia,
              locked: _isVerified,
              onPickImage: _pickIdentityImage,
              onPickPdf: _pickIdentityPdf,
            ),
            const SizedBox(height: 8),
            Text(
              'Limite B2 : 850 Ko maximum. Les images sont compressées automatiquement. '
              'Les PDF trop lourds sont refusés. Aucun fichier n’est envoyé dans Firebase Storage.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isSaving ? 'Enregistrement…' : 'Enregistrer'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _firestore == null
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AgentActivityV2DashboardPage(
                            agentId: widget.user.id,
                            agentName:
                                '${_firstName.text} ${_lastName.text}'.trim(),
                          ),
                        ),
                      );
                    },
              icon: const Icon(Icons.insights_outlined),
              label: const Text('Voir mon activité détaillée'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _firestore == null
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AgentCommissionsV2Page(
                            agentId: widget.user.id,
                            agentName:
                                '${_firstName.text} ${_lastName.text}'.trim(),
                          ),
                        ),
                      );
                    },
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Mes commissions V2'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = true,
    bool locked = false,
    int minLength = 2,
    int? maxLength,
    TextInputType? keyboard,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: locked,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: locked,
      ),
      validator: (value) {
        final String text = value?.trim() ?? '';
        if (required && text.length < minLength) {
          return 'Minimum $minLength caractères.';
        }
        if (!required && text.isNotEmpty && text.length < minLength) {
          return 'Minimum $minLength caractères.';
        }
        if (maxLength != null && text.length > maxLength) {
          return 'Maximum $maxLength caractères.';
        }
        return null;
      },
    );
  }

  Widget _twoFields(Widget first, Widget second) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            children: <Widget>[first, const SizedBox(height: 10), second],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: first),
            const SizedBox(width: 10),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

class _ProfileMediaHeader extends StatelessWidget {
  const _ProfileMediaHeader({
    required this.bytes,
    required this.status,
    required this.onPick,
  });

  final Uint8List? bytes;
  final String status;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 38,
              foregroundImage: bytes == null ? null : MemoryImage(bytes!),
              child: bytes == null ? const Icon(Icons.person_outline, size: 34) : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Photo de profil',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(_verificationLabel(status)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: onPick,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Changer la photo'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentityMediaCard extends StatelessWidget {
  const _IdentityMediaCard({
    required this.media,
    required this.current,
    required this.locked,
    required this.onPickImage,
    required this.onPickPdf,
  });

  final PreparedAgentMedia? media;
  final AgentPersonalMedia? current;
  final bool locked;
  final VoidCallback onPickImage;
  final VoidCallback onPickPdf;

  @override
  Widget build(BuildContext context) {
    final Uint8List? bytes = media?.bytes ?? current?.bytes;
    final String? mime = media?.mimeType ?? current?.mimeType;
    final String name = media?.fileName ?? current?.fileName ?? 'Aucun fichier';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (bytes != null && mime == 'image/jpeg')
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(bytes, height: 180, fit: BoxFit.contain),
              )
            else
              const SizedBox(
                height: 90,
                child: Center(child: Icon(Icons.picture_as_pdf_outlined, size: 42)),
              ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: locked ? null : onPickImage,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Image'),
                ),
                OutlinedButton.icon(
                  onPressed: locked ? null : onPickPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('PDF'),
                ),
              ],
            ),
            if (locked) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Pièce verrouillée : profil déjà vérifié.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

Widget _sectionTitle(BuildContext context, String text) {
  return Text(
    text,
    style: Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
    ),
  );
}

String _verificationLabel(String value) => switch (value) {
  'verified' => 'Profil vérifié',
  'pendingReview' => 'En attente de vérification',
  'needsCorrection' => 'Corrections demandées',
  _ => 'Profil incomplet',
};

String _dateLabel(DateTime? date) {
  if (date == null) return 'Sélectionner une date';
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}

String _text(Object? value) => value is String ? value.trim() : '';
String? _nullableText(Object? value) {
  final text = _text(value);
  return text.isEmpty ? null : text;
}
DateTime? _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
