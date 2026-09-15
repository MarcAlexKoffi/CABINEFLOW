import 'dart:typed_data';

import 'package:cabine_flow/core/supabase/supabase_bootstrap.dart';
import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/features/auth/data/repositories/supabase_staff_profile_repository.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Avatar commun Agent / Manager / Administrateur.
///
/// Toute la logique photo Staff passe par SupabaseStaffProfileRepository et le
/// même chemin privé `<uid>/avatar/profile.jpg` dans Supabase Storage.
class StaffProfileAvatar extends StatefulWidget {
  const StaffProfileAvatar({
    super.key,
    required this.firebaseUid,
    required this.displayName,
    this.size = 48,
    this.editable = false,
    this.onTap,
    this.knownAvatarPath,
    this.repository,
  });

  final String firebaseUid;
  final String displayName;
  final double size;
  final bool editable;
  final VoidCallback? onTap;
  final String? knownAvatarPath;
  final SupabaseStaffProfileRepository? repository;

  @override
  State<StaffProfileAvatar> createState() => _StaffProfileAvatarState();
}

class _StaffProfileAvatarState extends State<StaffProfileAvatar> {
  static final ValueNotifier<int> _revision = ValueNotifier<int>(0);

  SupabaseStaffProfileRepository? _repository;
  final ImagePicker _picker = ImagePicker();
  String? _avatarUrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository;
    if (_repository == null && SupabaseBootstrap.isInitialized) {
      _repository = SupabaseStaffProfileRepository();
    }
    _revision.addListener(_reloadAfterExternalChange);
    _load();
  }

  @override
  void didUpdateWidget(covariant StaffProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.firebaseUid != widget.firebaseUid ||
        oldWidget.knownAvatarPath != widget.knownAvatarPath) {
      _avatarUrl = null;
      _load();
    }
  }

  @override
  void dispose() {
    _revision.removeListener(_reloadAfterExternalChange);
    super.dispose();
  }

  void _reloadAfterExternalChange() => _load();

  Future<void> _load() async {
    final SupabaseStaffProfileRepository? repository = _repository;
    if (repository == null || widget.firebaseUid.trim().isEmpty) return;
    try {
      final String? url = await repository.fetchAvatarUrl(
        widget.firebaseUid,
        knownPath: widget.knownAvatarPath,
      );
      if (!mounted) return;
      setState(() => _avatarUrl = url);
    } catch (_) {
      if (!mounted) return;
      setState(() => _avatarUrl = null);
    }
  }

  Future<void> _handleTap() async {
    if (!widget.editable) {
      widget.onTap?.call();
      return;
    }
    if (_busy) return;
    final SupabaseStaffProfileRepository? repository = _repository;
    if (repository == null) {
      IzyTelFeedback.error(
        context,
        'La photo de profil nécessite la connexion Supabase.',
      );
      return;
    }

    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 94,
      );
      if (picked == null || !mounted) return;
      setState(() => _busy = true);
      final Uint8List bytes = await picked.readAsBytes();
      final String url = await repository.uploadOwnAvatar(
        firebaseUid: widget.firebaseUid,
        source: bytes,
        fallbackDisplayName: widget.displayName,
      );
      if (!mounted) return;
      setState(() => _avatarUrl = url);
      _revision.value += 1;
      IzyTelFeedback.success(context, 'Photo de profil mise à jour.');
    } catch (error) {
      if (!mounted) return;
      final String message = error
          .toString()
          .replaceFirst('Bad state: ', '')
          .replaceFirst('StateError: ', '');
      IzyTelFeedback.error(
        context,
        message.isEmpty ? 'Impossible de mettre à jour la photo.' : message,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool tappable = widget.editable || widget.onTap != null;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        IzyTelAvatar(
          name: widget.displayName,
          size: widget.size,
          imageUrl: _avatarUrl,
          onTap: tappable ? _handleTap : null,
        ),
        if (_busy)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(75),
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        if (widget.editable && !_busy)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 19,
              height: 19,
              decoration: BoxDecoration(
                color: IzyTelColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: IzyTelColors.outline),
              ),
              child: const Icon(
                Icons.photo_camera_outlined,
                size: 12,
                color: IzyTelColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}
