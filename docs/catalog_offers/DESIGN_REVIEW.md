# Conception R1 — Catalogue et import des offres

**Archive de conception.** La dernière demande utilisateur autorise l’implémentation directe en conservant le style actuel. La R1 HTML n’est pas déclarée validée ; la référence de présentation est le Back-office existant et la vidéo fournie. Voir [l’implémentation actuelle](IMPLEMENTATION.md) et la [politique de style](STYLE_NON_REGRESSION.md).

**Produit :** IzyTel · **Feature :** CAT-IMPORT-01 · **Statut :** DESIGN_REVIEW · **Révision :** R1 · **Date :** 2026-11-15.

Le brief « Gestion des offres et imports en masse » fourni en texte joint est la demande utilisateur. Les feuilles d’aide du classeur servent de références de données, sans autoriser d’action sur l’application ou le backend.

## Sources et direction

Sources examinées : le brief AURA_READY ; `Modele_import_offres_IzyTel.xlsx` ; la page `lib/app/modules/backoffice/views/catalog/backoffice_offers_page.dart` ; `AdminOffer` ; le repository `SupabaseAdminOfferRepository` ; la migration BO-4 ; `backoffice_theme.dart`, `izytel_colors.dart` et les tokens IzyTel.

Trois directions ont été considérées pour cette revue :

| Direction | Principe | Intérêt / compromis |
|---|---|---|
| **A · Cartes et assistant guidé — recommandée, réalisée** | Cartes compactes, deux colonnes ; assistant modal en quatre étapes ; tableau facultatif | Continuité avec le catalogue client et lecture immédiate des impacts ; les grands écarts défilent dans un tableau dédié |
| B · Tableau prioritaire | Tableau à colonnes, panneau latéral d’édition, imports dans le même espace | Plus dense pour les opérations répétitives ; moins fidèle à la référence client en cartes |
| C · Espace d’import séparé | Catalogue simple et page dédiée aux lots, révisions et rapports | Convient à de longues sessions d’import ; ajoute de la navigation et sépare les impacts du catalogue |

La R1 matérialise A. La sidebar blanche, le fond clair et le bleu reprennent la charte du projet. Aucun nouvel univers graphique n’est introduit.

## Écrans et composants

| Surface | Contenu et interactions |
|---|---|
| Catalogue > Offres | Titre, ajout, import, export ; totaux ; opérateurs ; familles dépendant de l’opérateur ; statut ; recherche nom/code ; tri ; cartes/tableau ; pagination au-delà de 12 offres |
| Carte compacte | Opérateur, code permanent, nom, volume, prix opérateur, durée, famille, statut, priorité/mise en avant, édition et menu Modifier / Dupliquer / Désactiver / Historique |
| Tableau | Sélection de la page ou de lignes ; désactivation, activation, famille ou priorité ; passage obligatoire par l’aperçu et la confirmation |
| Formulaire | Les champs du modèle ; code permanent en lecture seule pour une offre existante ; duplication avec code distinct ; validations ; prix hors frais de checkout |
| Import · Fichier | Choix ou dépôt XLSX, modèle original téléchargeable, contraintes, feuille OFFRES exclusivement, scénarios de démonstration |
| Import · Aperçu | Cinq compteurs ; avant/après par champ ; lignes originales ; doublons et collisions ; filtre des résultats ; pagination 20 lignes ; choix explicite d’un import partiel |
| Import · Confirmation | Impacts, garanties historiques, case de confirmation ; option de coupure simulée |
| Import · Traitement/résultat | Progression par lots de 50 ; identifiant conservé pendant la reprise ; erreurs et conflits ; rapport JSON ; restauration avec confirmation |
| Historique | Révisions de la session ; résultats et reprise des lots en pause ; historique local d’une offre |
| Snapshot | Commande fictive avant/après changement du prix ; même identifiant, libellé, volume et frais historiques |

L’export présenté est un **CSV** du catalogue local, avec neutralisation des préfixes de formule. Le format d’import reste exclusivement XLSX. Il n’est pas proposé de réimporter directement cet export CSV.

## Règles visibles

- La création et la fusion reposent sur `code_offre`. Une comparaison porte sur les champs normalisés, sans assimiler GO et MO. `1,5` est accepté comme nombre décimal ; les unités restent distinctes.
- Les codes sont nettoyés des espaces extérieurs et mis en majuscules dans la simulation. Cette normalisation est une proposition à confirmer pour les codes historiques avant migration.
- DESACTIVER accepte seulement action + code ; un code inconnu est une erreur. Aucune suppression de commande ou de mouvement financier n’est proposée.
- Toutes les occurrences d’un code répété sont bloquées, avec leurs numéros de ligne. Les autres codes ne sont appliqués qu’après choix explicite du périmètre partiel et confirmation.
- Une offre absente du fichier reste intacte. Une offre identique est comptée sans écriture ni nouvelle version.
- Le modèle fourni comporte **40 brouillons non vérifiés**. Les 8 offres de départ sont des données fictives à statuts variés. L’interface affiche en permanence qu’il s’agit d’un prototype sans écriture Supabase.
- Un lot peut être partiellement appliqué ; les lots déjà traités sont conservés lors d’une coupure simulée. La reprise continue le même lot. Aucun message ne promet une transaction globale sur plusieurs lots.
- La restauration remet les anciennes valeurs. Pour une création sans version antérieure, elle rend l’offre inactive et conserve son audit. Un changement ultérieur entraîne un conflit bloquant.

## Tokens et responsive

| Élément | Valeurs R1 |
|---|---|
| Couleurs | Fond `#F6F8FB`, surface blanche, texte `#101828`, secondaire `#667085`, bordure `#E4E7EC`, primaire `#2E63EB`, primaire forte `#1D4ED8`, fond bleu `#E8F0FF` |
| Statuts | Vert texte `#167A3E` / fond `#EAF8EF`, ambre texte `#9C6400` / fond `#FFF6E5`, erreur texte `#B42318` / fond `#FFEDED`, brouillon gris ; toujours un libellé en plus de la couleur |
| Police | Manrope locale issue des assets de recette existants ; titre 28 px, titre de dialogue 22 px, prix 23 px, corps 12–14 px, métadonnées 10–11 px |
| Espacement | Base 8 px ; cartes séparées de 14 px, marges de contenu 36 px desktop / 16 px mobile, boutons de 40 px minimum |
| Rayons | Conteneur 14 px ; cartes 12 px ; champs/boutons 8 px ; dialogue 20 px / 14 px mobile |
| Desktop | Navigation 230 px ; en-tête et actions alignés selon la largeur ; grille strictement deux colonnes |
| Intermédiaire | Navigation réduite à 200 px sous 1200 px, masquée sous 900 px ; actions passent sous le titre |
| Mobile ≤640 px | Une carte par ligne, filtres sur deux rangées, compteurs 2×2, opérateurs défilants, dialogue dans la fenêtre, tableaux avec défilement horizontal local |

Les assets de marque sont copiés dans le prototype pour le rendre portable. Les scripts et la police ne nécessitent aucun service externe.

## États et accessibilité

États présents : normal, survol, focus, désactivé, lecture/traitement, vide, erreur de fichier, erreurs par ligne, succès, résultat partiel, pause/reprise, conflit de version et restauration bloquée.

HTML sémantique, champs étiquetés, boutons d’icônes nommés, état pressé des vues/opérateurs, dialogues natifs, focus visible, fermeture Échap, retour du focus au déclencheur, navigation du menu par flèches et recherche par `/`. Le focus du choix de fichier se voit sur la zone de dépôt. Progression et messages ont des rôles adaptés. Les animations respectent la préférence de mouvement réduit.

Contrôles réels sous Edge automatisé : largeurs 320/390/768/1440, absence de débordement de page, une/deux colonnes, clavier, retour du focus, import du vrai fichier, interactions, fichier contenant formule/macro/feuille absente, données HTML affichées comme texte. Les captures réelles et la version du navigateur sont dans [qa/evidence](aura-r1/qa/evidence/). Recette avec lecteur d’écran et zoom texte spécifique non exécutée.

## Arbitrages avant l’implémentation

1. **Vérification récente :** le brief ne définit pas le délai. Aucun nombre de jours n’est inventé ; le prototype bloque la publication ACTIF. Le serveur devra associer date, source et preuve de livraison pour les offres conditionnelles/promotionnelles.
2. **Suspension et archive :** le modèle ne distingue que BROUILLON / ACTIF / INACTIF, alors que l’objectif mentionne aussi archiver. La R1 présente la désactivation conservatrice. Définir si l’archive est un attribut distinct et comment la restaurer, sans réutiliser une suppression physique.
3. **Limites :** 5 Mo de fichier, 20 Mo décompressés, 5 000 lignes, lots de 50 et pages de 20 sont des propositions de conception, à ajuster après mesure côté serveur.
4. **Familles :** elles sont simulées par une configuration locale dans R1. La version réelle doit charger leur configuration depuis le serveur, sans redéploiement du front.
5. **Mapping des offres existantes :** aucun code stable ne doit être reconstruit automatiquement à partir d’un prix ou d’un nom. Préparer un rapprochement explicite et une migration qui garde les IDs existants.

## État de livraison

La R1 est proposée à la revue utilisateur. **Aucune validation visuelle n’a encore été reçue** ; aucun `DESIGN_CONTRACT.md` n’est donc figé. Après validation explicite de la révision, figer la référence puis préparer l’intégration Flutter et Supabase selon le [relais](IMPLEMENTATION_HANDOFF.md).

La recette porte sur ce prototype. Elle ne certifie ni les permissions serveur, ni la persistance des reprises, ni la compatibilité d’une migration avec les commandes réelles.
