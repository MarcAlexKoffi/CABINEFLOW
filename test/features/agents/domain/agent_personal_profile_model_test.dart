import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'le profil personnel expose une progression et un statut de complétude',
    () {
      final AgentPersonalProfile profile = AgentPersonalProfile(
        userId: 'AGENT-001',
        firstName: 'Marc',
        lastName: 'Koffi',
        dateOfBirth: DateTime(1997, 5, 10),
        address: 'Cocody Angré',
        city: 'Abidjan',
        contact1: '+2250700000000',
        contact2: '',
        emergencyContactName: '',
        emergencyContactPhone: '',
        identityDocumentType: AgentIdentityDocumentType.nationalId,
        identityDocumentNumber: 'CI-001',
        avatarStoragePath: 'agent_profiles/AGENT-001/avatar/profile',
        identityDocumentStoragePath:
            'agent_profiles/AGENT-001/identity/document',
        verificationStatus: AgentProfileVerificationStatus.pendingReview,
      );

      expect(profile.displayName, 'Marc Koffi');
      expect(profile.completionPercent, 100);
      expect(profile.isComplete, isTrue);
    },
  );
}
