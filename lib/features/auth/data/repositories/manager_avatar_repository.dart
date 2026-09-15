import 'dart:typed_data';

import 'package:cabine_flow/features/auth/data/repositories/supabase_staff_profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Façade de compatibilité. La logique photo réelle est centralisée dans
/// SupabaseStaffProfileRepository pour tous les rôles Staff.
class ManagerAvatarRepository {
  ManagerAvatarRepository({SupabaseClient? client})
    : _staff = SupabaseStaffProfileRepository(client: client);

  static const String bucketName = 'agent-personal';
  // Chemin commun Staff : <uid>/avatar/profile.jpg

  final SupabaseStaffProfileRepository _staff;

  Future<String?> fetchAvatarUrl(String uid) {
    return _staff.fetchAvatarUrl(uid);
  }

  Future<String> uploadAvatar({
    required String uid,
    required Uint8List source,
    String fallbackDisplayName = 'Manager IzyTel',
  }) {
    return _staff.uploadOwnAvatar(
      firebaseUid: uid,
      source: source,
      fallbackDisplayName: fallbackDisplayName,
    );
  }
}
