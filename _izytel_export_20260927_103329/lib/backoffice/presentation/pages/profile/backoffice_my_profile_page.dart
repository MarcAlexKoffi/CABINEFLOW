import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/features/auth/data/repositories/supabase_staff_profile_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/models/staff_profile.dart';
import 'package:cabine_flow/features/auth/presentation/widgets/staff_profile_avatar.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class BackofficeMyProfilePage extends StatefulWidget {
  const BackofficeMyProfilePage({
    super.key,
    required this.user,
    this.repository,
  });

  final AppUser user;
  final SupabaseStaffProfileRepository? repository;

  @override
  State<BackofficeMyProfilePage> createState() => _BackofficeMyProfilePageState();
}

class _BackofficeMyProfilePageState extends State<BackofficeMyProfilePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final SupabaseStaffProfileRepository _repository;
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _secondaryPhone = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _city = TextEditingController();
  final TextEditingController _emergencyName = TextEditingController();
  final TextEditingController _emergencyPhone = TextEditingController();

  StaffProfile? _profile;
  DateTime? _dateOfBirth;
  bool _loading = true;
  bool _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupabaseStaffProfileRepository();
    _hydrateFallback();
    _load();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _secondaryPhone.dispose();
    _address.dispose();
    _city.dispose();
    _emergencyName.dispose();
    _emergencyPhone.dispose();
    super.dispose();
  }

  void _hydrateFallback() {
    final List<String> parts = widget.user.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
    if (parts.isNotEmpty) {
      _firstName.text = parts.first;
      _lastName.text = parts.length > 1 ? parts.skip(1).join(' ') : '';
    }
    _phone.text = widget.user.phoneNumber.trim();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final StaffProfile? profile = await _repository.fetchProfile(widget.user.id);
      if (!mounted) return;
      if (profile != null) {
        _profile = profile;
        _firstName.text = profile.firstName;
        _lastName.text = profile.lastName;
        _email.text = profile.email;
        _phone.text = profile.phoneNumber;
        _secondaryPhone.text = profile.secondaryPhone;
        _dateOfBirth = profile.dateOfBirth;
        _address.text = profile.address;
        _city.text = profile.city;
        _emergencyName.text = profile.emergencyContactName;
        _emergencyPhone.text = profile.emergencyContactPhone;
      }
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final StaffProfile? current = _profile;
      final StaffProfile saved = await _repository.saveOwnProfile(
        StaffProfileDraft(
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          email: _email.text.trim(),
          phoneNumber: _phone.text.trim(),
          secondaryPhone: _secondaryPhone.text.trim(),
          dateOfBirth: _dateOfBirth,
          address: _address.text.trim(),
          city: _city.text.trim(),
          emergencyContactName: _emergencyName.text.trim(),
          emergencyContactPhone: _emergencyPhone.text.trim(),
          avatarPath: current?.avatarPath,
          identityDocumentType: current?.identityDocumentType,
          identityDocumentNumber: current?.identityDocumentNumber ?? '',
          identityDocumentPath: current?.identityDocumentPath,
          identityDocumentFileName: current?.identityDocumentFileName,
          identityDocumentMimeType: current?.identityDocumentMimeType,
        ),
      );
      if (!mounted) return;
      setState(() => _profile = saved);
      IzyTelFeedback.success(context, 'Profil Staff enregistré.');
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      IzyTelFeedback.error(context, error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 16, now.month, now.day),
    );
    if (selected != null && mounted) setState(() => _dateOfBirth = selected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BackofficePalette.canvas,
      appBar: AppBar(
        backgroundColor: BackofficePalette.surface,
        foregroundColor: BackofficePalette.ink,
        surfaceTintColor: Colors.transparent,
        title: const Text('Mon profil'),
        shape: const Border(bottom: BorderSide(color: BackofficePalette.line)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1080),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _header(),
                            const SizedBox(height: 18),
                            LayoutBuilder(
                              builder: (BuildContext context, BoxConstraints constraints) {
                                final bool desktop = constraints.maxWidth >= 820;
                                final Widget identity = _panel(
                                  title: 'Identité',
                                  icon: Symbols.badge_rounded,
                                  children: <Widget>[
                                    _field(_firstName, 'Prénom(s)', required: true),
                                    const SizedBox(height: 12),
                                    _field(_lastName, 'Nom'),
                                    const SizedBox(height: 12),
                                    InkWell(
                                      onTap: _pickDate,
                                      borderRadius: BorderRadius.circular(12),
                                      child: InputDecorator(
                                        decoration: const InputDecoration(
                                          labelText: 'Date de naissance',
                                          prefixIcon: Icon(Symbols.calendar_month_rounded),
                                        ),
                                        child: Text(
                                          _dateOfBirth == null
                                              ? 'Non renseignée'
                                              : _formatDateOnly(_dateOfBirth!),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                                final Widget contact = _panel(
                                  title: 'Coordonnées',
                                  icon: Symbols.contact_phone_rounded,
                                  children: <Widget>[
                                    _field(
                                      _email,
                                      'E-mail',
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                    const SizedBox(height: 12),
                                    _field(
                                      _phone,
                                      'Téléphone principal',
                                      keyboardType: TextInputType.phone,
                                    ),
                                    const SizedBox(height: 12),
                                    _field(
                                      _secondaryPhone,
                                      'Téléphone secondaire',
                                      keyboardType: TextInputType.phone,
                                    ),
                                  ],
                                );
                                if (!desktop) {
                                  return Column(
                                    children: <Widget>[
                                      identity,
                                      const SizedBox(height: 14),
                                      contact,
                                    ],
                                  );
                                }
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Expanded(child: identity),
                                    const SizedBox(width: 14),
                                    Expanded(child: contact),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                            _panel(
                              title: 'Adresse & urgence',
                              icon: Symbols.home_pin_rounded,
                              children: <Widget>[
                                _adaptive(<Widget>[
                                  _field(_city, 'Ville'),
                                  _field(_address, 'Adresse'),
                                ]),
                                const SizedBox(height: 12),
                                _adaptive(<Widget>[
                                  _field(_emergencyName, 'Contact d’urgence'),
                                  _field(
                                    _emergencyPhone,
                                    'Téléphone urgence',
                                    keyboardType: TextInputType.phone,
                                  ),
                                ]),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _verificationPanel(),
                            const SizedBox(height: 18),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: _saving ? null : _save,
                                icon: _saving
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Symbols.save_rounded),
                                label: Text(
                                  _saving ? 'Enregistrement…' : 'Enregistrer',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _header() {
    final StaffProfile? profile = _profile;
    final String displayName = profile?.displayName ?? widget.user.name;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: backofficePanelDecoration(elevated: true),
      child: Row(
        children: <Widget>[
          StaffProfileAvatar(
            firebaseUid: widget.user.id,
            displayName: displayName,
            knownAvatarPath: profile?.avatarPath,
            size: 72,
            editable: true,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: BackofficePalette.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  profile?.roleLabel ?? widget.user.roleLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: BackofficePalette.muted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'La photo et les informations personnelles sont communes aux espaces IzyTel.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: BackofficePalette.faint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: backofficePanelDecoration(elevated: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BackofficePalette.primarySoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 20, color: BackofficePalette.primary),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _verificationPanel() {
    final StaffProfile? profile = _profile;
    final StaffProfileVerificationStatus status =
        profile?.verificationStatus ?? StaffProfileVerificationStatus.incomplete;
    final Color color = switch (status) {
      StaffProfileVerificationStatus.verified => BackofficePalette.success,
      StaffProfileVerificationStatus.pendingReview => BackofficePalette.warning,
      StaffProfileVerificationStatus.needsCorrection => BackofficePalette.danger,
      StaffProfileVerificationStatus.incomplete => BackofficePalette.muted,
    };
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: backofficePanelDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Symbols.verified_user_rounded, color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Vérification du profil',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(status.label),
                if ((profile?.verificationNote ?? '').isNotEmpty) ...<Widget>[
                  const SizedBox(height: 5),
                  Text(
                    profile!.verificationNote!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (String? value) => (value ?? '').trim().isEmpty
                ? 'Champ obligatoire'
                : null
          : null,
    );
  }

  Widget _adaptive(List<Widget> fields) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            children: <Widget>[
              for (int index = 0; index < fields.length; index++) ...<Widget>[
                fields[index],
                if (index < fields.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }
        return Row(
          children: <Widget>[
            for (int index = 0; index < fields.length; index++) ...<Widget>[
              Expanded(child: fields[index]),
              if (index < fields.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }

  Widget _errorState() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(24),
        decoration: backofficePanelDecoration(elevated: true),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Symbols.cloud_off_rounded,
              size: 48,
              color: BackofficePalette.danger,
            ),
            const SizedBox(height: 12),
            const Text('Impossible de charger le profil Staff.'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Symbols.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateOnly(DateTime value) {
    String two(int input) => input.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year}';
  }
}
