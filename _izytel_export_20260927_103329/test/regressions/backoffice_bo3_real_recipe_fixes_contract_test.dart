import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BO-3 recette réelle - correctifs profils et zones', () {
    test('le profil Admin revient au back-office après enregistrement', () {
      final String source = File(
        'lib/backoffice/presentation/pages/profile/backoffice_my_profile_page.dart',
      ).readAsStringSync();
      expect(source, contains("IzyTelFeedback.success(context, 'Profil Staff enregistré.');"));
      expect(source, contains('Navigator.of(context).pop(saved);'));
    });

    test('les libellés du formulaire Zone restent visibles au-dessus de la carte', () {
      final String source = File(
        'lib/backoffice/presentation/pages/team/backoffice_zones_page.dart',
      ).readAsStringSync();
      expect(source, contains('padding: const EdgeInsets.only(top: 10)'));
      for (final String label in <String>[
        'Nom de la zone',
        'Ville',
        'Région / District',
        'Manager responsable',
        'Latitude',
        'Longitude',
      ]) {
        expect(
          source,
          contains("labelText: '$label', floatingLabelBehavior: FloatingLabelBehavior.always"),
        );
      }
    });

    test('la migration protège et récupère les avatars Staff', () {
      final String source = File(
        'supabase/migrations/20260915011451_bo3_real_recipe_avatar_persistence_and_backfill.sql',
      ).readAsStringSync();
      expect(source, contains("storage.objects"));
      expect(source, contains("'/avatar/profile.jpg'"));
      expect(source, contains('trg_preserve_staff_avatar_path'));
      expect(source, contains('new.avatar_path := old.avatar_path'));
    });
  });
}
