import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/presentation/widgets/staff_profile_avatar.dart';
import 'package:flutter/material.dart';

/// Compatibilité UI : l'avatar Manager utilise désormais la couche photo Staff
/// commune aux Agents, Managers et Administrateurs.
/// La sélection historique `ImageSource.gallery` est désormais gérée par
/// StaffProfileAvatar afin de ne pas dupliquer la logique photo.
class ManagerProfileAvatar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return StaffProfileAvatar(
      firebaseUid: user.id,
      displayName: user.name,
      size: size,
      editable: editable,
      onTap: onTap,
    );
  }
}
