import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test(
    'Agent detaille reste accessible au Manager avec capacités seules modifiables',
    () {
      final String detail = source(
        'lib/features/agents/presentation/pages/agent_detail_page.dart',
      );

      expect(
        detail,
        contains("label: const Text('Identité et activité détaillée')"),
      );
      expect(detail, contains('widget.viewer.isManager'));
      expect(detail, contains('adjustManagedAgentCapacity'));
      expect(
        detail,
        contains("label: const Text('Enregistrer les capacités Agent')"),
      );
      expect(detail, contains('readOnly: !_canEditCapacities'));
      expect(detail, contains('readOnly: widget.readOnly'));
    },
  );

  test(
    'Cabiniste detaille expose identité finance et capacités toujours en lecture seule',
    () {
      final String detail = source(
        'lib/features/team/presentation/pages/team_member_detail_page.dart',
      );

      // La fiche Cabiniste est bien prise en charge.
      expect(detail, contains("detail.actorType == 'cabiniste'"));

      // Les trois capacités réseau sont affichées dans la nouvelle
      // architecture sous forme de métriques.
      expect(detail, contains("title: 'Capacités'"));
      expect(detail, contains("_MetricData('Orange'"));
      expect(detail, contains("_MetricData('MTN'"));
      expect(detail, contains("_MetricData('Moov'"));

      // Les capacités du Cabiniste doivent rester strictement en lecture seule.
      expect(
        detail,
        contains(
          'Lecture seule : ces capacités correspondent au fonds de roulement propre du Cabiniste.',
        ),
      );

      // Admin / Manager peut toujours gérer les zones du Cabiniste.
      expect(detail, contains('updateCabinisteZones'));
      expect(detail, contains('widget.viewer.permissions.canManageAgents'));

      // Aucun mécanisme de modification des capacités Cabiniste
      // ne doit être introduit.
      expect(detail, isNot(contains('adjustCabinisteCapacity')));
    },
  );

  test('Annuaire Agent Manager masque les profils hors périmètre Supabase', () {
    final String page = source(
      'lib/features/agents/presentation/pages/agent_management_page.dart',
    );

    expect(page, contains('widget.user.isManager'));
    expect(page, contains('agent.profile != null'));
    expect(page, contains("'Agents de ma zone'"));
  });
}
