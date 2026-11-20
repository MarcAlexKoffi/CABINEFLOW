# Réouverture USSD confirmée — IzyTel 1.0.11, build 12

Le garde serveur assimilait la simple ouverture du composeur à une exécution définitive et refusait une deuxième ouverture. La reprise du composeur est maintenant permise après confirmation explicite qu’aucune opération n’a été exécutée. Cette confirmation est décochée à chaque dialogue, y compris lors de la copie du code. Si le résultat d’un code envoyé reste inconnu, le dialogue demande une vérification Manager.

L’autorisation d’exécution reste incertaine. Chaque tentative conserve la vérification de session/appareil/Agent, le délai initial, la résolution courante, le contexte/version, l’idempotence, le bail court et la limite de fréquence. Une syntaxe ou association changée depuis la première tentative reste bloquée. Le composeur utilise toujours ACTION_DIAL : aucun code n’est envoyé automatiquement. Max it reste réouvrable sans la confirmation USSD.

Migration appliquée : `supabase/migrations/20261119235203_ussd_confirmed_dialer_reopen.sql`. Seule `private.ussd_prepare(text,uuid,integer,jsonb,text)` a changé parmi les 66 fonctions vérifiées ; droits et propriétaires inchangés. Les 109 commandes, 4 autorisations, 16 règles et 4 journaux présents au contrôle ont conservé leurs empreintes.

Sauvegarde ciblée : `.izytel_backups/ussd_reopen_schema_before.json`. Retour arrière : `supabase/operations/ussd_reopen_rollback.sql`, non exécuté. Aucun ordre, autorisation ou résultat financier n’a été remis à zéro.

Validation : 47 tests Flutter ciblés et 163 tests SQL isolés réussis ; analyse Flutter sans problème. Les tests couvrent la reproduction initiale, le refus sans confirmation ou avec une valeur incorrecte, les ouvertures répétées, le retour Android pendant l’audit, les sessions, contextes périmés, doubles clics, limites de fréquence, versions changées et la réouverture Max it. Journaux : `scratch/ussd_reopen_flutter_tests.log`, `scratch/ussd_reopen_sql_tests.log`, `scratch/ussd_reopen_analyze.log`, `scratch/ussd_reopen_android_build.log`.

Essai réel : ouvrir une syntaxe sur une commande en cours, quitter le composeur sans envoyer le code, revenir dans IzyTel, confirmer qu’aucune opération n’a été exécutée et rouvrir. La commande doit rester en cours. Aucune transaction réelle n’a été exécutée pendant la validation automatique ; la vérification du nouvel APK sur appareil reste à faire.

Fichiers du correctif : les deux dépôts USSD (contrat et implémentation), `ussd_quick_processing_card.dart`, le double de test partagé, les tests widget/HTTP, `test/ussd_sql/confirmed_dialer_reopen_cases.mjs`, son lanceur, la migration, son retour arrière et `pubspec.yaml`.

APK release signé et vérifié : `dist/android/latest/izytel-1.0.11-build12.apk` (74 259 656 octets). SHA-256 : `3ede39c288e49f87afbea852cb815fa709f75eb871f5fccc7b455c25d2c496a3`. Signature identique aux versions release précédentes.
