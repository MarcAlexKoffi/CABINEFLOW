import 'dart:typed_data';

import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

class AgentPersonalProfilePage extends StatefulWidget {
  const AgentPersonalProfilePage({
    super.key,
    required this.user,
    required this.repository,
    this.initialProfile,
    this.initialAvatarUrl,
  });

  final AppUser user;
  final AgentRepository repository;
  final AgentPersonalProfile? initialProfile;
  final String? initialAvatarUrl;

  @override
  State<AgentPersonalProfilePage> createState() =>
      _AgentPersonalProfilePageState();
}

class _AgentPersonalProfilePageState extends State<AgentPersonalProfilePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _contact1Controller;
  late final TextEditingController _contact2Controller;
  late final TextEditingController _emergencyNameController;
  late final TextEditingController _emergencyPhoneController;
  late final TextEditingController _identityNumberController;

  DateTime? _dateOfBirth;
  AgentIdentityDocumentType _identityType =
      AgentIdentityDocumentType.nationalId;
  AgentProfileFileUpload? _avatarUpload;
  AgentProfileFileUpload? _identityUpload;
  bool _saving = false;

  AgentPersonalProfile? get _profile => widget.initialProfile;

  @override
  void initState() {
    super.initState();
    final AgentPersonalProfile? profile = _profile;
    final List<String> userParts = widget.user.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
    final String fallbackFirst = userParts.isEmpty ? '' : userParts.first;
    final String fallbackLast = userParts.length <= 1
        ? ''
        : userParts.skip(1).join(' ');

    _firstNameController = TextEditingController(
      text: profile?.firstName.isNotEmpty == true
          ? profile!.firstName
          : fallbackFirst,
    );
    _lastNameController = TextEditingController(
      text: profile?.lastName.isNotEmpty == true
          ? profile!.lastName
          : fallbackLast,
    );
    _addressController = TextEditingController(text: profile?.address ?? '');
    _cityController = TextEditingController(text: profile?.city ?? '');
    _contact1Controller = TextEditingController(
      text: profile?.contact1.isNotEmpty == true
          ? profile!.contact1
          : widget.user.phoneNumber,
    );
    _contact2Controller = TextEditingController(text: profile?.contact2 ?? '');
    _emergencyNameController = TextEditingController(
      text: profile?.emergencyContactName ?? '',
    );
    _emergencyPhoneController = TextEditingController(
      text: profile?.emergencyContactPhone ?? '',
    );
    _identityNumberController = TextEditingController(
      text: profile?.identityDocumentNumber ?? '',
    );
    _dateOfBirth = profile?.dateOfBirth;
    _identityType =
        profile?.identityDocumentType ?? AgentIdentityDocumentType.nationalId;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _contact1Controller.dispose();
    _contact2Controller.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _identityNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final DateTime now = DateTime.now();
    final DateTime initial = _dateOfBirth ?? DateTime(now.year - 25, 1, 1);
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Date de naissance',
      cancelText: 'Annuler',
      confirmText: 'Valider',
    );
    if (selected == null || !mounted) return;
    setState(() => _dateOfBirth = selected);
  }

  Future<void> _pickAvatar() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => _SourceSheet(
        title: 'Photo d’identité',
        actions: <_SourceAction<ImageSource>>[
          _SourceAction<ImageSource>(
            icon: Symbols.photo_camera_rounded,
            label: 'Prendre une photo',
            value: ImageSource.camera,
          ),
          _SourceAction<ImageSource>(
            icon: Symbols.photo_library_rounded,
            label: 'Choisir dans la galerie',
            value: ImageSource.gallery,
          ),
        ],
      ),
    );
    if (source == null || !mounted) return;

    final XFile? file = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1800,
      maxHeight: 1800,
      imageQuality: 88,
      requestFullMetadata: false,
    );
    if (file == null || !mounted) return;
    final Uint8List bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.length > 5 * 1024 * 1024) {
      IzyTelFeedback.error(context, 'La photo doit faire moins de 5 Mo.');
      return;
    }
    setState(() {
      _avatarUpload = AgentProfileFileUpload(
        fileName: file.name.isEmpty ? 'photo_profil.jpg' : file.name,
        mimeType: file.mimeType ?? 'image/jpeg',
        bytes: bytes,
      );
    });
  }

  Future<void> _pickIdentityDocument() async {
    final String? choice = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => const _SourceSheet<String>(
        title: 'Pièce d’identité',
        actions: <_SourceAction<String>>[
          _SourceAction<String>(
            icon: Symbols.document_scanner_rounded,
            label: 'Photographier la pièce',
            value: 'camera',
          ),
          _SourceAction<String>(
            icon: Symbols.upload_file_rounded,
            label: 'Choisir une image ou un PDF',
            value: 'file',
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;

    AgentProfileFileUpload? upload;
    if (choice == 'camera') {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 90,
        requestFullMetadata: false,
      );
      if (file == null) return;
      final Uint8List bytes = await file.readAsBytes();
      upload = AgentProfileFileUpload(
        fileName: file.name.isEmpty ? 'piece_identite.jpg' : file.name,
        mimeType: file.mimeType ?? 'image/jpeg',
        bytes: bytes,
      );
    } else {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'pdf'],
      );
      if (file == null) return;
      final Uint8List bytes = await file.readAsBytes();
      upload = AgentProfileFileUpload(
        fileName: file.name,
        mimeType: _mimeTypeFor(file.extension),
        bytes: bytes,
      );
    }

    if (!mounted) return;
    if (upload.bytes.length > 10 * 1024 * 1024) {
      IzyTelFeedback.error(
        context,
        'La pièce d’identité doit faire moins de 10 Mo.',
      );
      return;
    }
    setState(() => _identityUpload = upload);
  }

  String _mimeTypeFor(String? extension) {
    switch ((extension ?? '').toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    if (_dateOfBirth == null) {
      IzyTelFeedback.show(
        context,
        'Renseigne ta date de naissance.',
        tone: IzyTelFeedbackTone.warning,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.repository.saveOwnPersonalProfile(
        agentId: widget.user.id,
        draft: AgentPersonalProfileDraft(
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          dateOfBirth: _dateOfBirth,
          address: _addressController.text,
          city: _cityController.text,
          contact1: _contact1Controller.text,
          contact2: _contact2Controller.text,
          emergencyContactName: _emergencyNameController.text,
          emergencyContactPhone: _emergencyPhoneController.text,
          identityDocumentType: _identityType,
          identityDocumentNumber: _identityNumberController.text,
        ),
        avatar: _avatarUpload,
        identityDocument: _identityUpload,
      );
      if (!mounted) return;
      IzyTelFeedback.success(context, 'Profil personnel enregistré.');
      Navigator.of(context).pop(true);
    } on ArgumentError catch (error) {
      if (!mounted) return;
      IzyTelFeedback.error(
        context,
        error.message?.toString() ?? 'Données invalides.',
      );
    } catch (error) {
      if (!mounted) return;
      IzyTelFeedback.error(
        context,
        'Impossible d’enregistrer le profil pour le moment.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AgentPersonalProfile? profile = _profile;
    final AgentProfileVerificationStatus status =
        profile?.verificationStatus ??
        AgentProfileVerificationStatus.incomplete;

    return Scaffold(
      backgroundColor: IzyTelColors.background,
      appBar: AppBar(title: const Text('Informations personnelles')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            IzyTelSpacing.lg,
            IzyTelSpacing.md,
            IzyTelSpacing.lg,
            120,
          ),
          children: <Widget>[
            _ProfilePhotoCard(
              name: _displayName,
              avatarUrl: widget.initialAvatarUrl,
              pendingUpload: _avatarUpload,
              status: status,
              completionPercent: profile?.completionPercent ?? 0,
              onChangePhoto: _pickAvatar,
            ),
            const SizedBox(height: IzyTelSpacing.xl),
            const _SectionTitle(
              title: 'Identité',
              subtitle:
                  'Ces informations permettent d’identifier le titulaire du compte Agent.',
            ),
            const SizedBox(height: 8),
            IzyTelSurface(
              child: Column(
                children: <Widget>[
                  _textField(
                    controller: _firstNameController,
                    label: 'Prénom(s)',
                    icon: Symbols.person_rounded,
                    validator: _requiredName,
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _lastNameController,
                    label: 'Nom',
                    icon: Symbols.badge_rounded,
                    validator: _requiredName,
                  ),
                  const SizedBox(height: 12),
                  _DateField(date: _dateOfBirth, onTap: _pickBirthDate),
                ],
              ),
            ),
            const SizedBox(height: IzyTelSpacing.xl),
            const _SectionTitle(
              title: 'Coordonnées',
              subtitle:
                  'Utilisées pour le suivi opérationnel et les contacts importants.',
            ),
            const SizedBox(height: 8),
            IzyTelSurface(
              child: Column(
                children: <Widget>[
                  _textField(
                    controller: _addressController,
                    label: 'Adresse / quartier',
                    icon: Symbols.home_pin_rounded,
                    validator: _requiredText,
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _cityController,
                    label: 'Ville / commune',
                    icon: Symbols.location_city_rounded,
                    validator: _requiredText,
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _contact1Controller,
                    label: 'Contact 1',
                    icon: Symbols.call_rounded,
                    keyboardType: TextInputType.phone,
                    validator: _requiredPhone,
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _contact2Controller,
                    label: 'Contact 2 (facultatif)',
                    icon: Symbols.phone_in_talk_rounded,
                    keyboardType: TextInputType.phone,
                    validator: _optionalPhone,
                  ),
                ],
              ),
            ),
            const SizedBox(height: IzyTelSpacing.xl),
            const _SectionTitle(
              title: 'Contact d’urgence',
              subtitle:
                  'Facultatif, mais recommandé pour un compte professionnel.',
            ),
            const SizedBox(height: 8),
            IzyTelSurface(
              child: Column(
                children: <Widget>[
                  _textField(
                    controller: _emergencyNameController,
                    label: 'Nom du contact',
                    icon: Symbols.emergency_rounded,
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _emergencyPhoneController,
                    label: 'Téléphone du contact',
                    icon: Symbols.contact_phone_rounded,
                    keyboardType: TextInputType.phone,
                    validator: _optionalPhone,
                  ),
                ],
              ),
            ),
            const SizedBox(height: IzyTelSpacing.xl),
            const _SectionTitle(
              title: 'Pièce d’identité',
              subtitle:
                  'Photo ou PDF. Le fichier reste privé et accessible uniquement à toi et aux administrateurs autorisés.',
            ),
            const SizedBox(height: 8),
            IzyTelSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  DropdownButtonFormField<AgentIdentityDocumentType>(
                    initialValue: _identityType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Type de pièce',
                      prefixIcon: Icon(Symbols.id_card_rounded),
                    ),
                    items: AgentIdentityDocumentType.values
                        .map(
                          (AgentIdentityDocumentType type) =>
                              DropdownMenuItem<AgentIdentityDocumentType>(
                                value: type,
                                child: Text(
                                  type.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                        )
                        .toList(growable: false),
                    onChanged: (AgentIdentityDocumentType? value) {
                      if (value != null) setState(() => _identityType = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _identityNumberController,
                    label: 'Numéro de la pièce (facultatif)',
                    icon: Symbols.numbers_rounded,
                  ),
                  const SizedBox(height: 14),
                  _AttachmentTile(
                    fileName:
                        _identityUpload?.fileName ??
                        profile?.identityDocumentFileName,
                    hasExistingFile: profile?.hasIdentityDocument == true,
                    onTap: _pickIdentityDocument,
                  ),
                ],
              ),
            ),
            if (profile?.verificationNote?.trim().isNotEmpty ==
                true) ...<Widget>[
              const SizedBox(height: 12),
              _VerificationNote(note: profile!.verificationNote!),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
          decoration: const BoxDecoration(
            color: IzyTelColors.surface,
            border: Border(top: BorderSide(color: IzyTelColors.outline)),
          ),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Symbols.save_rounded),
            label: Text(_saving ? 'Enregistrement…' : 'Enregistrer le profil'),
          ),
        ),
      ),
    );
  }

  String get _displayName {
    final String value = <String>[
      _firstNameController.text.trim(),
      _lastNameController.text.trim(),
    ].where((String item) => item.isNotEmpty).join(' ');
    return value.isEmpty ? widget.user.name : value;
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      textInputAction: TextInputAction.next,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    );
  }

  String? _requiredName(String? value) {
    return (value ?? '').trim().length < 2 ? 'Champ obligatoire.' : null;
  }

  String? _requiredText(String? value) {
    return (value ?? '').trim().length < 2 ? 'Champ obligatoire.' : null;
  }

  String? _requiredPhone(String? value) {
    return (value ?? '').replaceAll(RegExp(r'\s+'), '').length < 8
        ? 'Numéro invalide.'
        : null;
  }

  String? _optionalPhone(String? value) {
    final String cleaned = (value ?? '').replaceAll(RegExp(r'\s+'), '');
    if (cleaned.isEmpty) return null;
    return cleaned.length < 8 ? 'Numéro invalide.' : null;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: IzyTelColors.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: IzyTelColors.textSecondary,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _ProfilePhotoCard extends StatelessWidget {
  const _ProfilePhotoCard({
    required this.name,
    required this.avatarUrl,
    required this.pendingUpload,
    required this.status,
    required this.completionPercent,
    required this.onChangePhoto,
  });

  final String name;
  final String? avatarUrl;
  final AgentProfileFileUpload? pendingUpload;
  final AgentProfileVerificationStatus status;
  final int completionPercent;
  final VoidCallback onChangePhoto;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = switch (status) {
      AgentProfileVerificationStatus.verified => IzyTelColors.success,
      AgentProfileVerificationStatus.pendingReview => IzyTelColors.warning,
      AgentProfileVerificationStatus.needsCorrection => IzyTelColors.error,
      AgentProfileVerificationStatus.incomplete => IzyTelColors.textSecondary,
    };
    final Widget avatar;
    if (pendingUpload != null) {
      avatar = ClipOval(
        child: Image.memory(
          pendingUpload!.bytes,
          width: 82,
          height: 82,
          fit: BoxFit.cover,
        ),
      );
    } else {
      avatar = IzyTelAvatar(name: name, size: 82, imageUrl: avatarUrl);
    }

    return IzyTelSurface(
      child: Row(
        children: <Widget>[
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              avatar,
              Positioned(
                right: -3,
                bottom: -3,
                child: Material(
                  color: IzyTelColors.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onChangePhoto,
                    child: const Padding(
                      padding: EdgeInsets.all(7),
                      child: Icon(
                        Symbols.photo_camera_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                IzyTelStatusPill(label: status.label, color: statusColor),
                const SizedBox(height: 8),
                Text(
                  'Profil complété à $completionPercent %',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: IzyTelColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onTap});

  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String value = date == null
        ? 'Date de naissance'
        : '${date!.day.toString().padLeft(2, '0')}/${date!.month.toString().padLeft(2, '0')}/${date!.year}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Date de naissance',
          prefixIcon: Icon(Symbols.calendar_month_rounded),
          suffixIcon: Icon(Symbols.chevron_right_rounded),
        ),
        child: Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: date == null
                ? IzyTelColors.textMuted
                : IzyTelColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.fileName,
    required this.hasExistingFile,
    required this.onTap,
  });

  final String? fileName;
  final bool hasExistingFile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool ready = fileName?.trim().isNotEmpty == true || hasExistingFile;
    return Material(
      color: IzyTelColors.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: ready
                      ? IzyTelColors.success.withAlpha(18)
                      : IzyTelColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  ready
                      ? Symbols.verified_rounded
                      : Symbols.upload_file_rounded,
                  color: ready ? IzyTelColors.success : IzyTelColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      ready ? 'Pièce enregistrée' : 'Ajouter la pièce',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fileName?.trim().isNotEmpty == true
                          ? fileName!
                          : 'Photo JPG/PNG ou PDF · 10 Mo maximum',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: IzyTelColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Symbols.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerificationNote extends StatelessWidget {
  const _VerificationNote({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: IzyTelColors.warning.withAlpha(12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IzyTelColors.warning.withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Symbols.info_rounded, color: IzyTelColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              note,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceSheet<T> extends StatelessWidget {
  const _SourceSheet({required this.title, required this.actions});

  final String title;
  final List<_SourceAction<T>> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
      decoration: BoxDecoration(
        color: IzyTelColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: IzyTelColors.outlineStrong,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final _SourceAction<T> action in actions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(action.icon, color: IzyTelColors.primary),
              title: Text(action.label),
              trailing: const Icon(Symbols.chevron_right_rounded),
              onTap: () => Navigator.of(context).pop(action.value),
            ),
        ],
      ),
    );
  }
}

class _SourceAction<T> {
  const _SourceAction({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final T value;
}
