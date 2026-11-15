# Relais d’implémentation — CAT-IMPORT-01

**Relais initial historique.** La fonctionnalité a depuis été implémentée directement sur consigne utilisateur, avec le style du Back-office existant. Le bilan courant est [IMPLEMENTATION.md](IMPLEMENTATION.md). Les mentions « futur / à faire » ci-dessous décrivent l’état avant cette intégration et ne sont pas son statut actuel.

Référence visuelle proposée : **R1, DESIGN_REVIEW**, non encore validée. Ce document décrit du travail futur, sans migration ni endpoint nouvellement créés.

## Socle actuel observé

| Source dans le dépôt | Constat local et implication |
|---|---|
| `lib/app/modules/backoffice/views/catalog/backoffice_offers_page.dart` | Page existante ; contrôle d’édition par `UserRole.administrator`, filtres et gestion courante ; intégrer les futurs contrôles dans cette route |
| `lib/app/data/repositories/supabase_admin_offer_repository.dart` | `catalog_offers` canonique, lecture temps réel et RPC `izytel_create_catalog_offer`, `izytel_update_catalog_offer`, `izytel_set_catalog_offer_active` ; une RPC de suppression existe aussi et ne convient pas au parcours de désactivation/restauration demandé |
| `lib/app/domain/entities/offers/admin_offer.dart` | ID technique, opérateur/service/type d’opération, libellés, prix entier, catégorie, booléen actif, priorité, volume/durée textuels ; absence de modèle complet du fichier d’import |
| `supabase/migrations/20260915013543_bo4_catalog_supabase_cutover.sql` | `catalog_offers`, `catalog_offer_audit_events` et état de migration ; RLS et validations métier existantes ; utiliser ce socle avant toute extension |
| `lib/app/domain/entities/orders/queue_order.dart` | `offerId`, `offerLabel` et `amount` déjà portés par une commande ; cela ne prouve pas à lui seul la présence d’un snapshot complet et immuable volume/frais pour tous les parcours |
| `lib/app/theme/backoffice_theme.dart`, `izytel_colors.dart`, `izytel_design_tokens.dart` | Charte claire blanche/bleue à conserver dans Flutter |

Ces constats proviennent des fichiers locaux, pas d’une inspection de la base distante. Auditer l’ensemble des migrations postérieures, RPC, parcours client/staff et tests existants avant de finaliser un schéma.

## Écarts à traiter

| Besoin | Travail à spécifier et valider |
|---|---|
| Code permanent | Ajouter ou établir un mapping canonique unique de `code_offre` vers l’ID existant ; contrôler collisions et normalisation ; aucune identification par prix/libellé |
| Familles et types | Configuration serveur par opérateur ; mapping explicite INTERNET/MIXTE/APPELS/SOCIAL vers service/type d’opération existants ; éviter une conversion arbitraire de SOCIAL vers INTERNET |
| Statuts | Distinguer brouillon/actif/inactif tout en maintenant la compatibilité des lectures client `is_active` ; décider du sens de suspension/archive |
| Données de publication | Volume précis + unité, durée structurée, éligibilité tiers, canal confirmé, date/source et preuves conditionnelles ; politique de fraîcheur à définir |
| Versions | Version de concurrence atomique, audit ancien/nouveau, auteur, date et importId ; ne pas se contenter d’un horodatage fourni par le navigateur |
| Lots et rapports | Persistance durable du fichier validé ou de son contenu canonique, du périmètre confirmé, de l’avancement, des résultats par ligne et des erreurs ; reprise par le même importId |
| Snapshots | Examiner les créations de commandes et les synchronisations existantes ; figer prix/volume/unité/frais/libellé côté serveur au moment canonique de création ; ne pas réécrire les anciennes commandes depuis le catalogue courant |

## Contrat serveur à concevoir

Conserver la chaîne d’identité réellement utilisée par le projet, notamment les JWT Firebase reconnus par Supabase. Le rôle Admin doit être résolu par le mécanisme serveur existant, sans faire confiance à un rôle envoyé dans le fichier ou le payload client. Ne pas donner des clés privilégiées au front.

Les opérations ci-dessous sont des **responsabilités proposées**, pas des noms d’API déjà disponibles :

1. **Préparer un import :** vérifier l’Admin, plafonner le fichier, inspecter l’archive, lire OFFRES, normaliser/valider côté serveur, calculer un aperçu et les versions attendues. La simulation navigateur est seulement une aide de lecture. Produire un identifiant/jeton d’aperçu lié au contenu et à l’acteur ; ne modifier aucune offre.
2. **Confirmer :** vérifier à nouveau l’Admin, le contenu, les versions et le choix explicite d’exclure des erreurs. Créer la révision et un importId persistant. Une contrainte unique et des transitions serveur doivent rendre les retries idempotents.
3. **Appliquer :** comparer les versions au moment d’écrire, sauvegarder ancien/nouveau et appliquer uniquement les champs réellement modifiés. Traiter des lots bornés, conserver les résultats validés, isoler les conflits et publier un statut partiel fidèle. Ne pas utiliser des boucles de RPC client comme garantie d’idempotence.
4. **Lire/reprendre :** retrouver la révision après une réponse perdue ou une reconnexion, sans redéclencher les écritures déjà confirmées. Les droits doivent être contrôlés également sur les rapports et sauvegardes.
5. **Restaurer :** contrôler les versions depuis l’import, tracer une nouvelle révision compensatoire, conserver les créations sous forme inactive et les IDs historiques. Ne modifier ni les commandes ni les mouvements financiers. Définir la politique de restauration en présence de conflits avant de permettre une restauration partielle.

Protéger aussi les RPC de création/modification unitaire : sinon les conditions de publication et les permissions pourraient être contournées en dehors de l’assistant.

## Sécurité du parseur et limites

La R1 contient un lecteur XLSX local borné, sans dépendance de lecture Excel : ZIP, XML, `DecompressionStream`. Il refuse macros, chiffrement, formules dans OFFRES, en-têtes manquants/répétés et dépassements ; les feuilles d’aide ne sont pas importées. Les URLs ne sont pas ouvertes ; tous les textes affichés sont échappés. L’export CSV neutralise les préfixes de formule.

Ce lecteur ne doit pas être promu tel quel en parseur serveur de confiance. Choisir une bibliothèque serveur maintenue, vérifier ses limites de décompression/complexité, rejouer toutes les validations et tester les archives malformées. Le prototype ne prend pas en charge tous les dialectes XLSX (par exemple, calendrier Excel 1904 refusé). Aucun calcul de formule n’est nécessaire.

## Intégration dans la nouvelle architecture

| Couche | Responsabilité future |
|---|---|
| `app/domain/entities/offers` et `app/domain/repositories` | Offres typées, résultats d’aperçu, révisions, progression et contrats métier |
| `app/data/repositories` | Accès aux opérations serveur, lecture de configuration et reprise durable |
| `app/modules/backoffice/views/catalog` | Page, cartes, tableau, formulaires et étapes d’import selon la référence validée |
| `app/shared` / `app/theme` | Réutiliser tokens, statuts, focus, composants et règles responsive existants |
| `supabase` | Migration compatible, RPC/fonction sécurisée, validation/merge/audit/version/idempotence, tests SQL et intégrés |

La navigation, les points d’entrée, les paiements, la commande en cours et les autres modules restent les références fonctionnelles. La R1 n’introduit aucune conversion GetX.

## Critères de recette après implémentation

Reprendre les douze scénarios du brief, avec preuves Flutter + serveur : quatre créations en brouillon ; relecture inchangée ; modification conservant ID/historique ; désactivation sans perte ; import partiel conservateur ; doublons sans vainqueur ; offre promotionnelle non éligible non publiée ; non-Admin refusé côté serveur ; réponse perdue/retry sans double écriture ; snapshot de commande immuable ; 500+ lignes avec erreurs partielles ; responsive/recherche/filtres/focus.

Ajouter des vérifications concurrentes import/édition, rejeu d’import terminé/restauré, fichiers limites/malveillants, contrôle d’accès aux rapports et sauvegardes, et restauration avec offre modifiée depuis. La simulation R1 apporte des scénarios à réutiliser, sans remplacer ces preuves serveur.
