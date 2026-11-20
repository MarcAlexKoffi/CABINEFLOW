# Max it — réouverture sur la même commande (1.0.10, build 11)

Le premier lancement était enregistré comme une exécution incertaine. Le garde serveur refusait ensuite toute nouvelle préparation sur cette commande, y compris l’ouverture de la seule activité d’accueil Max it. Fermer Max it ne modifiait pas cet état. Un retour rapide dans IzyTel pendant l’enregistrement du journal pouvait également laisser le bouton désactivé.

Le correctif autorise la réouverture de Max it dans la même exécution. Il exige une résolution serveur actuelle `APP:MAXIT`, la même attribution, le même Agent/appareil/session et des journaux de cette exécution exclusivement Max it. Un ancien lancement USSD reste bloqué, même si sa configuration est ensuite remplacée par Max it. Le contexte confirmé, la version, la limite de fréquence, le délai initial et le bail court restent vérifiés. Chaque ouverture est journalisée ; aucun droit de traitement supplémentaire, recharge ou clôture de commande n’est créé.

Le bouton reste disponible après une ouverture réussie, même si Android revient dans IzyTel avant la fin de l’audit. Chaque clic refait les contrôles serveur. Les refus de préparation affichent désormais leur véritable motif.

Migration appliquée au projet IzyTel : `supabase/migrations/20261119193515_ussd_maxit_safe_reopen.sql`. Comparaison des 66 fonctions concernées : seule `private.ussd_prepare(text,uuid,integer,jsonb,text)` change, aucun droit ni propriétaire modifié. Les 8 commandes, 8 autorisations d’exécution, 13 règles et 5 journaux présents au contrôle ont conservé leurs empreintes. Aucune donnée de production ni opération financière n’a été modifiée pour ce correctif.

Sauvegarde ciblée : `.izytel_backups/maxit_reopen_schema_before.json`. Retour arrière : `supabase/operations/maxit_reopen_rollback.sql`, qui restaure seulement l’ancien garde sans supprimer de données. Ce script n’a pas été appliqué.

Vérifications :
- 154 tests SQL isolés réussis, dont reproduction du blocage initial, réouvertures successives, session/appareil/territoire/délai, contexte périmé, USSD, anciennes attributions, désactivation et limite de fréquence.
- 44 tests Flutter ciblés réussis, dont clics successifs, retour Android pendant l’audit et refus hors connexion.
- `flutter analyze --no-pub` : aucune erreur ni avertissement.
- Compilation release réussie ; APK signé vérifié : `dist/android/1.0.10-build11/izytel-1.0.10-build11.apk` (74 259 652 octets). SHA-256 : `9ddc75b7150f5cab752c914c818823ee5f61b9c6469cc79c796c6cee0e83dac5`. Certificat identique à la version release précédente.
- Téléphone non connecté lors de la livraison : la vérification réelle du nouvel APK reste à faire sur appareil. Aucun traitement de commande réelle n’a été lancé par les tests.

Essai : installer la version 1.0.10, ouvrir Max it sur une commande autorisée encore en cours, revenir dans IzyTel, puis appuyer à nouveau sur « Ouvrir Max it ». Max it doit s’ouvrir à chaque fois et la commande rester en cours jusqu’à la déclaration réelle de son résultat.

Fichiers du correctif :
- `lib/app/modules/ussd/widgets/ussd_quick_processing_card.dart`
- `test/app/modules/ussd/ussd_mobile_widget_test.dart`
- `test/ussd_sql/maxit_reopen_cases.mjs`
- `test/ussd_sql/run.mjs`
- `supabase/migrations/20261119193515_ussd_maxit_safe_reopen.sql`
- `supabase/operations/maxit_reopen_rollback.sql`
- `supabase/operations/maxit_reopen_release.md`
- `pubspec.yaml`

Journaux : `scratch/maxit_reopen_sql_tests.log`, `scratch/maxit_reopen_flutter_tests.log`, `scratch/maxit_reopen_analyze.log`, `scratch/maxit_reopen_android_build.log`.
