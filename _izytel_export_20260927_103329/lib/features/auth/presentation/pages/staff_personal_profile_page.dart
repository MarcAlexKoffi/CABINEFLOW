import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/features/auth/data/repositories/supabase_staff_profile_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/models/staff_profile.dart';
import 'package:cabine_flow/features/auth/presentation/widgets/staff_profile_avatar.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class StaffPersonalProfilePage extends StatefulWidget {
  const StaffPersonalProfilePage({
    super.key,
    required this.user,
    this.repository,
  });

  final AppUser user;
  final SupabaseStaffProfileRepository? repository;

  @override
  State<StaffPersonalProfilePage> createState() =>
      _StaffPersonalProfilePageState();
}

class _StaffPersonalProfilePageState extends State<StaffPersonalProfilePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<FormFieldState<String>> _firstNameKey =
      GlobalKey<FormFieldState<String>>();
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
  bool _showValidationErrors = false;
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
    _scrollController.dispose();
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
      final StaffProfile? profile = await _repository.fetchProfile(
        widget.user.id,
      );
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
    if (_saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final bool valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      if (mounted) setState(() => _showValidationErrors = true);
      await _focusFirstInvalidField();
      if (mounted) {
        IzyTelFeedback.show(
          context,
          'Complète les champs obligatoires (*) indiqués en rouge.',
          tone: IzyTelFeedbackTone.warning,
        );
      }
      return;
    }
    setState(() {
      _saving = true;
      _showValidationErrors = false;
    });
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
      IzyTelFeedback.success(context, 'Profil personnel enregistré.');
    } catch (error) {
      if (!mounted) return;
      IzyTelFeedback.error(
        context,
        error.toString().replaceFirst('PostgrestException(message: ', ''),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _focusFirstInvalidField() async {
    await Future<void>.delayed(Duration.zero);
    final BuildContext? target = _firstNameKey.currentState?.hasError == true
        ? _firstNameKey.currentContext
        : null;
    if (target == null || !target.mounted) return;
    await Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: .18,
    );
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 16, now.month, now.day),
    );
    if (selected != null && mounted) {
      setState(() => _dateOfBirth = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      appBar: AppBar(
        backgroundColor: IzyTelColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Mon profil'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _errorState()
          : SafeArea(
              top: false,
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
                  children: <Widget>[
                    _identityHeader(),
                    const SizedBox(height: 10),
                    Text(
                      'Les champs marqués * sont obligatoires.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: IzyTelColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: IzyTelSpacing.lg),
                    _section(
                      title: 'Identité',
                      icon: Symbols.badge_rounded,
                      children: <Widget>[
                        _adaptive(<Widget>[
                          _field(
                            controller: _firstName,
                            label: 'Prénom(s)',
                            fieldKey: _firstNameKey,
                            required: true,
                          ),
                          _field(controller: _lastName, label: 'Nom'),
                        ]),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(14),
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
                    ),
                    const SizedBox(height: IzyTelSpacing.md),
                    _section(
                      title: 'Coordonnées',
                      icon: Symbols.contact_phone_rounded,
                      children: <Widget>[
                        _field(
                          controller: _email,
                          label: 'E-mail',
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        _adaptive(<Widget>[
                          _field(
                            controller: _phone,
                            label: 'Téléphone principal',
                            keyboardType: TextInputType.phone,
                          ),
                          _field(
                            controller: _secondaryPhone,
                            label: 'Téléphone secondaire',
                            keyboardType: TextInputType.phone,
                          ),
                        ]),
                        const SizedBox(height: 12),
                        _adaptive(<Widget>[
                          _field(controller: _city, label: 'Ville'),
                          _field(controller: _address, label: 'Adresse'),
                        ]),
                      ],
                    ),
                    const SizedBox(height: IzyTelSpacing.md),
                    _section(
                      title: 'Contact d’urgence',
                      icon: Symbols.emergency_rounded,
                      children: <Widget>[
                        _adaptive(<Widget>[
                          _field(
                            controller: _emergencyName,
                            label: 'Nom du contact',
                          ),
                          _field(
                            controller: _emergencyPhone,
                            label: 'Téléphone du contact',
                            keyboardType: TextInputType.phone,
                          ),
                        ]),
                      ],
                    ),
                    const SizedBox(height: IzyTelSpacing.md),
                    _statusCard(),
                    const SizedBox(height: IzyTelSpacing.lg),
                    FilledButton.icon(
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
                        _saving ? 'Enregistrement…' : 'Enregistrer le profil',
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _identityHeader() {
    final StaffProfile? profile = _profile;
    final String displayName = profile?.displayName ?? widget.user.name;
    return IzyTelSurface(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: <Widget>[
          StaffProfileAvatar(
            firebaseUid: widget.user.id,
            displayName: displayName,
            knownAvatarPath: profile?.avatarPath,
            size: 64,
            editable: true,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  profile?.roleLabel ?? widget.user.roleLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: IzyTelColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Touchez la photo pour la modifier',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: IzyTelColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard() {
    final StaffProfile? profile = _profile;
    return IzyTelSurface(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          const Icon(Symbols.verified_user_rounded, color: IzyTelColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Statut du profil',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  profile?.verificationStatus.label ?? 'Incomplet',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if ((profile?.verificationNote ?? '').isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    profile!.verificationNote!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: IzyTelColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return IzyTelSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 20, color: IzyTelColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _adaptive(List<Widget> children) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            children: <Widget>[
              for (int index = 0; index < children.length; index++) ...<Widget>[
                children[index],
                if (index < children.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }
        return Row(
          children: <Widget>[
            for (int index = 0; index < children.length; index++) ...<Widget>[
              Expanded(child: children[index]),
              if (index < children.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    GlobalKey<FormFieldState<String>>? fieldKey,
    TextInputType? keyboardType,
    bool required = false,
  }) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      keyboardType: keyboardType,
      autovalidateMode: _showValidationErrors
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
      ),
      validator: required
          ? (String? value) => (value ?? '').trim().isEmpty
                ? 'Champ obligatoire'
                : null
          : null,
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Symbols.cloud_off_rounded,
              size: 48,
              color: IzyTelColors.error,
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
