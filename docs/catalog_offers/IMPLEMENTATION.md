# Catalogue et import — candidate intégrée

15 novembre 2026 · CAT-IMPORT-01 · **code intégré et vérifié localement ; backend déployé avec accord utilisateur**.

La dernière consigne utilisateur demande l’implémentation directe avec le style déjà en place, illustré par la vidéo du 15 novembre à 13:02. Cette référence remplace le prototype HTML R1 comme référence de présentation. Le [contrat de non-régression](STYLE_NON_REGRESSION.md) précise les composants conservés et leurs preuves.

## Fonctionnement intégré

La page existante conserve son introduction, ses cartes blanches, ses badges, ses boutons et sa navigation. Elle ajoute recherche par code, familles, statuts brouillon/actif/inactif, tri, cartes sur deux colonnes lorsque la largeur le permet, tableau facultatif, sélection multiple et pagination du catalogue.

Correctif de la vidéo utilisateur du 15 novembre à 14:27 : le `Wrap` des six actions Admin recevait une largeur non bornée dans le `Row` de l’introduction desktop. À une largeur intermédiaire, il comprimait le texte et produisait un grand espace vide avec une bande de débordement. La largeur des actions est désormais plafonnée à 440 px ; leurs boutons passent à la ligne dans la surface existante, sans modifier le composant partagé ni le backend. Un nouveau test reproduit l’échec initial à 884 px (débordement de 375 px), puis contrôle l’absence de débordement, la hauteur de l’introduction et la présence de chaque action dans ses limites à 840, 884, 930, 1024 et 1280 px. Les 16 tests UI/repository/style ciblés passent après correction, dont les deux goldens d’origine ; analyse sans anomalie. Journaux : `scratch/catalog_toolbar_{before,after,analyze,build}.log`.

Les actions Admin comprennent l’import XLSX, le téléchargement du modèle fourni, l’export CSV, les règles de publication, les familles configurables, la création/duplication structurée et les historiques. Les offres historiques gardent leur ancien éditeur ; « Code et vérification » permet de les rattacher explicitement à un code permanent en conservant leur ID.

L’assistant appelle un lecteur XLSX **sur le serveur**, présente les résultats paginés et les écarts, puis exige une confirmation et un choix explicite si des lignes sont exclues. Les écritures passent par des RPC Admin, par lots de 50, avec révisions, versions, audit, importId et reprise après une réponse perdue. Le rapport JSON contient les résultats par ligne ; la restauration est compensatoire et refuse les modifications concurrentes.

## Fichiers principaux

| Fichier | Modification |
|---|---|
| `lib/app/modules/backoffice/views/catalog/backoffice_offers_page.dart` | Intégration dans la page actuelle, filtres, vues, sélection, actions et appels aux dialogues |
| `catalog_import_dialog.dart`, `catalog_offer_details_dialog.dart`, `catalog_bulk_dialog.dart` dans le même dossier | Assistant, historiques, formulaire structuré et configuration ; surfaces/tokens du Back-office existant |
| `lib/app/domain/entities/offers/admin_offer.dart` | Métadonnées optionnelles et version observée ; anciens constructeurs compatibles |
| `lib/app/domain/entities/offers/catalog_import.dart`, `lib/app/domain/repositories/catalog_import_repository.dart` | Contrats d’import, résultats, erreurs utiles et export sécurisé |
| `lib/app/data/repositories/supabase_admin_offer_repository.dart` | Appels Edge/RPC et lecture des métadonnées ; protection de l’ancien éditeur par version |
| `supabase/migrations/20261115133000_catalog_offer_imports.sql` | Extension compatible du catalogue, configuration, révisions, validation, idempotence, conflits, restauration et snapshots immuables |
| `supabase/functions/izytel-catalog-import/` | Lecteur borné ZIP/XML, autorisation avant lecture, préparation serveur et dépendances verrouillées |
| `assets/templates/Modele_import_offres_IzyTel.xlsx`, `pubspec.yaml` | Modèle fourni, copié sans modification et téléchargeable dans l’application |

## Intégrité et compatibilité

- Les codes gardent leur casse exacte, après retrait des espaces extérieurs. Un ID technique sert de code provisoire aux offres historiques. Aucun rapprochement automatique par nom/prix/durée. Le rattachement explicite est confirmé une fois, puis le code reste permanent.
- Les lignes absentes sont conservées. DESACTIVER accepte action + code. Toutes les occurrences d’un code répété sont bloquées. Les offres identiques ne génèrent ni écriture ni nouvelle version.
- L’offre conserve son ID et sa date de création. Les prix, quantités et unités restent distincts ; aucune conversion implicite GO/MO.
- Le délai de vérification est initialement **non configuré**, puis réglable par l’Admin entre 1 et 366 jours. Les brouillons restent importables ; ACTIF exige date récente, tiers OUI, canal confirmé et preuve de livraison pour une famille conditionnelle.
- Les offres déjà actives et les lectures client/staff sont conservées. Les nouvelles publications et réactivations passent par la vérification. L’ancien flux de reprise du catalogue Firestore reste un flux legacy Admin distinct.
- Les snapshots des **nouvelles** lignes canoniques sont figés dans `customer_order_recovery_registry` et `phase4_assignment_orders`. Le pont reprend le snapshot initial lorsqu’il existe. Les anciens historiques ne sont pas reconstitués à partir des données actuelles.
- Le schéma distant consulté ne comporte pas de colonnes de frais séparés dans ces deux tables. Le snapshot conserve le montant, le libellé, les quantités catalogue et les champs effectivement présents sur la commande ; il n’invente aucun frais. Les calculs de paiement existants ne sont pas modifiés.
- La suppression existante du Back-office reste l’archivage logique `deleted_at`. Un code archivé n’est pas réutilisé par l’import. Aucune commande ni écriture financière n’est supprimée.

## Contrôles exécutés

| Contrôle | Résultat |
|---|---|
| `flutter analyze --no-pub` | Aucune anomalie |
| Tests Flutter ciblés | **36 réussis**, dont 2 comparaisons pixel des cartes existantes, parcours Admin/non-Admin, assistant, reprise, restauration, HTTP, projection publique, catalogues client/staff et contrats historiques |
| `node test/catalog_import/run.mjs` | **16 scénarios SQL réussis** sur PostgreSQL isolé, sans identifiants de production |
| Tests Deno `xlsx_test.ts` | **5 tests réussis** : vrai modèle, formules, macros, limites, feuille/en-têtes, déclarations d’entités, précision/unité |
| TypeScript Edge | Vérification réussie avec Deno ; versions verrouillées dans `deno.lock` |
| Build Web Back-office | Réussi, `build/catalog_import_backoffice` |
| Consultation avant déploiement | Métadonnées des 4 tables et contrôle Admin existant vérifiés en lecture seule ; [relevé du schéma](remote-schema-review.json) |
| Déploiement autorisé et vérification distante | Sauvegarde privée, migration ciblée, fonction v1 ACTIVE ; 35 offres conservées, aucun champ d’origine modifié ; 5 contrôles HTTP réussis, RPC anonyme refusée, accès direct aux métadonnées refusé |

La compilation JS produit les avertissements de pré-vérification Wasm des plugins existants ; le build Web JS est réussi. Aucun objectif de compilation Wasm n’est ajouté à ce lot.

Preuves : [résultats SQL](sql-results.json), [captures Flutter](implementation-captures/), goldens dans `test/app/modules/backoffice/goldens/catalog_card_existing_*.png`. Journaux locaux : `scratch/catalog_import_{analyze,flutter_tests,build}.log`.

Les captures Flutter utilisent les vrais widgets et des données synthétiques. Elles ne représentent pas une session Admin de production. La suite générale du projet, qui comportait déjà des échecs avant ce lot, n’a pas été relancée ; les contrôles sont ciblés sur cette fonctionnalité et ses consommateurs.

Les commentaires, sources, références d’opérateur et justificatifs de livraison sont conservés dans une projection de métadonnées protégée, accessible par RPC Admin. Le catalogue public ne contient pas ces textes internes ; il expose seulement les données commerciales et un marqueur de vérification. Les signaux Realtime déclenchent une relecture Admin coalescée, sans remplacer les métadonnées complètes par une projection publique.

## Mise en service effectuée

L’utilisateur a répondu « Oui, mettre le backend en service ». Le projet ciblé est **IzyTel, `zrxeztxaxnzxevjuhzcc`**. Le [relevé de déploiement](deployment-results.json) conserve les versions distantes et empreintes des sources.

1. Sauvegarde serveur privée du catalogue et de son audit dans `private.catalog_import_backup_20261115133000` : **35 offres, 0 événement d’audit**, sans export local des données commerciales. RLS activée ; aucun droit accordé aux clients. Migration distante `20261115141724`, source locale `20261115132900_catalog_import_predeployment_backup.sql`.
2. Application de la seule migration fonctionnelle ciblée `20261115133000_catalog_offer_imports.sql`, enregistrée à distance sous **`20261115141733`**. Aucune application globale des migrations locales en attente.
3. Déploiement de **`izytel-catalog-import`, version 1, ACTIVE**, avec son `deno.json`, ses dépendances et son verrou. **`verify_jwt=false` pour cette fonction seulement** : elle transmet le JWT Firebase à la Data API qui le vérifie, puis les RPC contrôlent l’Admin actif avant la lecture XLSX. Aucun accès `service_role` dans la fonction. Voir la [documentation Firebase/Supabase](https://supabase.com/docs/guides/auth/third-party/firebase-auth).
4. Vérifications : les 35 IDs existent toujours et chaque champ d’origine est identique à la sauvegarde. Aucun import créé et aucun événement d’audit ajouté. Les cinq nouvelles tables internes ont RLS et aucun droit SELECT direct pour `anon`/`authenticated`. La RPC de configuration refuse l’anonyme avec `ADMIN_REQUIRED`. Les deux triggers de snapshot sont activés.
5. Vérifications HTTP : POST sans authentification **401**, token invalide **403**, prévol du domaine Firebase autorisé **200** avec l’origine attendue, origine inconnue **403**, GET non pris en charge **405**. Aucune offre du modèle n’a été importée.

## Étapes opérationnelles restantes

- Publier le frontend compatible lorsque la mise en ligne de l’hébergement est demandée, puis exécuter la recette authentifiée Admin/non-Admin. Le build est disponible dans `build/catalog_import_backoffice`. La transition des actions d’administration doit être coordonnée : les nouveaux contrôles de publication peuvent refuser les anciens formulaires non vérifiés.
- Vérifier `IZYTEL_ADMIN_ALLOWED_ORIGINS` si un domaine Admin personnalisé est utilisé ; les domaines Firebase connus et localhost:8080 sont prévus. Le prévol Firebase a été vérifié. Les variables Supabase de la fonction sont fournies automatiquement par l’environnement.
- Régler le délai de vérification dans « Règles et familles » ; il reste volontairement non configuré. Rattacher les codes historiques explicitement avant d’importer leurs mises à jour. Lors de la recette authentifiée, importer quelques brouillons puis vérifier le rapport et une reprise.

**Aucun déploiement d’hébergement frontend ni aucune issue GitHub distante n’ont été effectués par ce lot.** Les modifications ont ensuite été organisées en commits locaux sur `refactor/architecture-catalogue-20261115` ; leurs références sont dans le [dossier GitHub](../GITHUB_ISSUES.md). La recette de production avec un compte Admin réel n’a pas été exécutée ; les contrôles distants sont ceux décrits ci-dessus.

## Retour arrière

Pour un lot appliqué, utiliser la restauration contrôlée depuis son compte rendu. En présence de conflit, conserver les données et résoudre la révision avant une nouvelle restauration ; aucune sélection arbitraire de valeurs.

Pour une livraison, revenir au frontend antérieur et désactiver l’accès au nouvel import pendant le diagnostic. Conserver les tables d’audit, les révisions et les snapshots ; ne pas supprimer les nouvelles colonnes pour « nettoyer ». Si une ancienne interface doit retrouver ses anciennes règles de publication, retirer uniquement les gardes de publication nouvelles sous intervention contrôlée, en gardant le compteur de version et les données. Un retour de schéma demande une migration corrective examinée, pas un script destructeur automatique.
