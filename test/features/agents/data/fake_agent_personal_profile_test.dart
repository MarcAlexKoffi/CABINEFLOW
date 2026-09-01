import 'dart:typed_data';

import 'package:cabine_flow/features/agents/data/repositories/fake_agent_repository.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'un agent peut enregistrer son profil personnel sans modifier son profil opérationnel',
    () async {
      final FakeAgentRepository repository = FakeAgentRepository();
      final AgentProfile? operationalBefore = await repository
          .watchAgentProfile('AGENT-001')
          .first;

      await repository.saveOwnPersonalProfile(
        agentId: 'AGENT-001',
        draft: AgentPersonalProfileDraft(
          firstName: 'Koffi',
          lastName: 'Kouassi',
          dateOfBirth: DateTime(1998, 4, 12),
          address: 'Cocody Angré',
          city: 'Abidjan',
          contact1: '+2250700000001',
          contact2: '',
          emergencyContactName: 'Awa Kouassi',
          emergencyContactPhone: '+2250500000001',
          identityDocumentType: AgentIdentityDocumentType.nationalId,
          identityDocumentNumber: 'CI-TEST-001',
        ),
        avatar: AgentProfileFileUpload(
          fileName: 'avatar.jpg',
          mimeType: 'image/jpeg',
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
        ),
        identityDocument: AgentProfileFileUpload(
          fileName: 'cni.pdf',
          mimeType: 'application/pdf',
          bytes: Uint8List.fromList(<int>[4, 5, 6]),
        ),
      );

      final AgentPersonalProfile? personal = await repository
          .watchPersonalProfile('AGENT-001')
          .first;
      final AgentProfile? operationalAfter = await repository
          .watchAgentProfile('AGENT-001')
          .first;

      expect(personal, isNotNull);
      expect(personal!.displayName, 'Koffi Kouassi');
      expect(personal.hasAvatar, isTrue);
      expect(personal.hasIdentityDocument, isTrue);
      expect(personal.isComplete, isTrue);
      expect(
        personal.verificationStatus,
        AgentProfileVerificationStatus.pendingReview,
      );

      expect(
        operationalAfter?.orangeCapacity,
        operationalBefore?.orangeCapacity,
      );
      expect(operationalAfter?.mtnCapacity, operationalBefore?.mtnCapacity);
      expect(operationalAfter?.availability, operationalBefore?.availability);
    },
  );
}
