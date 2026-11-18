# Syntaxes des forfaits spéciaux

Les groupes Folie (Moov) et C’Chic (MTN) peuvent désormais être reconnus automatiquement à partir de la famille ou du nom de l’offre dans le catalogue. Une seule règle couvre les offres actuelles et futures du groupe, en Appels, Internet, Mixte et Social. Aucun rattachement individuel n’est nécessaire dans ce mode.

Pour Folie Moov :

1. Cliquer sur « Créer une règle », réseau Moov.
2. Dans « Reconnaissance des offres », sélectionner « Toutes les offres Folie ». Le périmètre couvre automatiquement tous les services. Exemple de syntaxe issu du PDF : `*412*4*{{msisdn_local}}#`.
3. Cliquer sur « Créer et activer » : la règle est active immédiatement. La validation administrative, son auteur et sa date sont enregistrés, sans déclarer un test SIM fictif.
4. Les commandes liées aux offres Folie du catalogue utiliseront cette syntaxe, sans association manuelle.

Pour C’Chic, choisir le réseau MTN puis « Toutes les offres C’Chic ». Exemple du PDF : `*133*6*8*{{msisdn_local}}#`. Les variations de casse, espaces et apostrophes sont reconnues. Les offres C’Chic classées SOCIAL sont incluses grâce à leur nom.

Le fichier `IZYTEL_CATALOGUE_REVISE_18-11-2026_IMPORT.xlsx` fournit 133 cas de référence : 19 Folie, 20 C’Chic (dont 2 SOCIAL), 94 autres offres. Les 39 offres sont couvertes dès qu’elles sont importées dans le catalogue. À la vérification serveur de ce complément, le catalogue en base ne comportait aucune offre reconnue Folie et une seule C’Chic. Le fichier est utilisé comme référence de test ; son import commercial ne fait pas partie de cette modification USSD.

Le mode « Association manuelle / générique » conserve les familles libres et leurs associations explicites pour les autres besoins. Les variantes Moov Money peuvent être enregistrées dans une autre règle avec une cible ou une priorité adaptée. Deux règles concurrentes de même niveau et priorité sont refusées. L’ordre de sélection est : offre précise, famille manuelle, groupe automatique, règle générique.

La création est atomique : une syntaxe invalide, expirée, ambiguë ou dont les variables d’offre sont incomplètes n’est pas enregistrée. Pour modifier une association déjà utilisée, désactiver les règles concernées ; l’ajout d’une nouvelle offre à une famille active reste possible si ses variables nécessaires sont renseignées. Modifier une syntaxe existante conserve le parcours de réactivation séparée.

Les pièces jointes servent de références. Aucun code Maxit ou Passe nuit n’est inventé ; le PDF décrit notamment Maxit comme un parcours dans l’application opérateur.

## Intégration et vérification

Les migrations `20261117235555_ussd_shared_families_and_direct_creation.sql` puis `20261118012824_ussd_automatic_commercial_offer_groups.sql` précèdent la publication du back-office. Elles conservent les règles existantes et leur statut, les droits RPC et les historiques. Les anciennes applications peuvent toujours lire les règles ; la sélection opérationnelle est effectuée côté serveur. Le nom d’une commande sans identité d’offre fiable ne permet pas de sélectionner une règle automatique.

Contrôles locaux :

Résultats du complément : 129 tests Flutter réussis, 137 contrôles SQL réussis, analyse des cinq fichiers Dart sans anomalie. Les contrôles incluent les 133 offres du fichier, la résolution des 39 commandes Folie/C’Chic sans associations, l’ajout d’une offre future, l’invalidation après renommage, les conflits et les droits. Une SIM réelle n’est pas utilisée par ces tests.

```powershell
node test/ussd_sql/run.mjs
flutter test --no-pub test/app/domain/ussd/ussd_engine_test.dart test/app/data/ussd/ussd_repository_http_test.dart test/app/modules/ussd/ussd_backoffice_widget_test.dart --reporter expanded
flutter analyze --no-pub lib/app/domain/policies/ussd/ussd_engine.dart lib/app/modules/ussd/views/backoffice_ussd_page.dart lib/app/modules/ussd/widgets/ussd_rule_dialogs.dart test/app/domain/ussd/ussd_engine_test.dart test/app/modules/ussd/ussd_backoffice_widget_test.dart
```

Recette réelle après import du catalogue : créer une règle automatique Folie et une C’Chic, vérifier leur statut Actif, puis ouvrir les raccourcis de commandes des offres Appels, Internet, Mixte et Social correspondantes. Le bénéficiaire remplace la variable. Ajouter une nouvelle offre correctement nommée ou classée : la même règle doit être sélectionnée sans association. Vérifier aussi une offre normale : elle conserve sa propre règle. Aucune opération télécom n’est nécessaire pour contrôler ces aperçus.

Retour arrière : republier le précédent back-office et désactiver les règles automatiques ainsi que les nouvelles règles communes avant de restaurer les fonctions privées modifiées. Un ancien résolveur ignore le critère de groupe : il ne doit jamais être restauré avec une règle automatique active. Conserver les colonnes et historiques ajoutés ; ne pas rejouer les anciennes migrations complètes. La configuration et les définitions SQL ont été sauvegardées avant application distante.

## Publication du 18 novembre 2026

- Migration Supabase appliquée : `ussd_shared_families_and_direct_creation`, version distante `20261118001404`.
- Les empreintes des règles existantes, familles et associations sont identiques avant/après ; les historiques conservent leurs 10 versions de règles et aucune version d’association.
- Le serveur réel a validé, dans une transaction annulée, une création directement active, une famille commune, l’association d’offres Appels et Internet et la génération d’un code fictif. Aucun enregistrement de recette n’est conservé. Le helper de validation reste inaccessible directement aux rôles clients.
- Compilation du back-office réussie ; publication limitée à `hosting:backoffice` sur le projet `cabineflow-4bca7`.
- Site : https://izytel-backoffice-4bca7.web.app ; version Hosting `a75774dee83c3387`.
- Contrôle HTTP à 00:29 UTC : `version.json`, `main.dart.js`, `index.html` et `flutter_bootstrap.js` identiques au build local, 4 contrôles réussis.
- SHA-256 de `main.dart.js` : `03de9173e25db3211707a4a3c786891b8b3b5a3057e7d5334ab52ad0eaa02a59`.
- Marqueur : `change: ussd-shared-families-direct-creation`, source `a3bdfe7e9cac5e11bec4a990802f21d2178216cf` avec modifications locales (`sourceDirty: true`).

Le connecteur Firebase a annoncé un succès sans actualiser le site ; la publication effective et les contrôles ci-dessus ont ensuite réussi avec la CLI. Le parcours complet dans la session authentifiée de l’utilisateur reste à essayer après `Ctrl + F5`.

Preuves locales dans `scratch/` : `ussd_shared_remote_backup_20261118.json`, `ussd_shared_remote_verification_20261118.json`, `ussd_shared_previous_hosting_version.json`, `ussd_shared_web_build.log`, `ussd_shared_hosting_deploy.json` et `ussd_shared_hosting_results.json`. Aucun APK n’a été publié.

## Complément automatique publié à 01:42 UTC

- Migration distante `20261118013622`, `ussd_automatic_commercial_offer_groups` ; fichier local `20261118012824_ussd_automatic_commercial_offer_groups.sql`.
- Les 133 lignes du fichier Excel ont aussi été classées par le serveur réel : 133 résultats corrects, 19 Folie et 20 C’Chic.
- Création des deux types de règles vérifiée dans une transaction annulée. Les empreintes des règles, familles, associations et du catalogue sont identiques avant/après. Les offres commerciales du fichier n’ont pas été importées par ces vérifications.
- Version Hosting `56953a31e88f732f`, publication CLI limitée au back-office, 4 fichiers HTTP identiques au build.
- SHA-256 `main.dart.js` : `8b510bba40d901bbffd1bbae70c4860d6e9138e7ceb6630d7a094976e17a9686`.
- Marqueur `change: ussd-automatic-folie-cchic`, source locale non commitée (`sourceDirty: true`).
- Preuves dans `scratch/` : `ussd_automatic_remote_backup_20261118.json`, `ussd_automatic_remote_verification_20261118.json`, `ussd_automatic_web_build.log`, `ussd_automatic_hosting_deploy.json`, `ussd_automatic_hosting_results.json`, `ussd_automatic_flutter.log`, `ussd_automatic_sql_final.log`, `ussd_automatic_analyze.log`.

Après `Ctrl + F5`, utiliser le nouveau champ « Reconnaissance des offres » pour créer les règles automatiques. Les anciennes règles manuelles conservent leur périmètre ; aucune conversion silencieuse n’est effectuée.
