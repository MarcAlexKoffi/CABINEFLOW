import 'dart:typed_data';

import 'package:cabine_flow/core/supabase/supabase_bootstrap.dart';
import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/features/auth/data/repositories/manager_avatar_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/permissions/user_permissions.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Avatar réutilisable du Manager.
///
/// Le visuel est chargé depuis Supabase Storage. Lorsqu'il est éditable, un
/// toucher ouvre la galerie puis remplace l'image. Les autres instances de ce
/// widget se rafraîchissent automatiquement après une modification.
class ManagerProfileAvatar extends StatefulWidget {
  const ManagerProfileAvatar({
    super.key,
    required this.user,
    this.size = 48,
    this.editable = false,
    this.onTap,
  });

  final AppUser user;
  final double size;
  final bool editable;
  final VoidCallback? onTap;

  @override
  State<ManagerProfileAvatar> createState() => _ManagerProfileAvatarState();
}

class _ManagerProfileAvatarState extends State<ManagerProfileAvatar> {
  static final ValueNotifier<int> _revision = ValueNotifier<int>(0);

  final ManagerAvatarRepository _repository = ManagerAvatarRepository();
  final ImagePicker _picker = ImagePicker();
  String? _avatarUrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _revision.addListener(_reloadAfterExternalChange);
    _load();
  }

  @override
  void didUpdateWidget(covariant ManagerProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) {
      _avatarUrl = null;
      _load();
    }
  }

  @override
  void dispose() {
    _revision.removeListener(_reloadAfterExternalChange);
    super.dispose();
  }

  void _reloadAfterExternalChange() {
    _load();
  }

  Future<void> _load() async {
    if (!widget.user.isManager || !SupabaseBootstrap.isInitialized) return;
    final String? url = await _repository.fetchAvatarUrl(widget.user.id);
    if (!mounted) return;
    setState(() => _avatarUrl = url);
  }

  Future<void> _handleTap() async {
    if (!widget.editable) {
      widget.onTap?.call();
      return;
    }
    if (_busy) return;
    if (!SupabaseBootstrap.isInitialized) {
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
        imageQuality: 92,
      );
      if (picked == null || !mounted) return;

      setState(() => _busy = true);
      final Uint8List bytes = await picked.readAsBytes();
      final String url = await _repository.uploadAvatar(
        uid: widget.user.id,
        source: bytes,
      );
      if (!mounted) return;
      setState(() => _avatarUrl = url);
      _revision.value++;
      IzyTelFeedback.show(
        context,
        'Photo de profil mise à jour.',
        tone: IzyTelFeedbackTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      final String raw = error.toString().replaceFirst('Bad state: ', '');
      IzyTelFeedback.error(
        context,
        raw.isEmpty ? 'Impossible de mettre à jour la photo.' : raw,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canEdit = widget.editable && widget.user.isManager;

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        IzyTelAvatar(
          name: widget.user.name,
          size: widget.size,
          imageUrl: _avatarUrl,
          onTap: canEdit || widget.onTap != null ? _handleTap : null,
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
        if (canEdit && !_busy)
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
