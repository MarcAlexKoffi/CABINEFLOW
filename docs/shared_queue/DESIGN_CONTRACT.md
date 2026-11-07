# IzyTel — contrat de design AURA R1

Amendement du 6 novembre après retour utilisateur : harmonisation explicitement demandée avec les écrans existants, en supprimant le doublon d'en-tête Agent. Le prototype historique reste figé ; les corrections, captures et limites de validation humaine sont consignées dans [CORRECTIF_20261106.md](CORRECTIF_20261106.md).

Statut : DESIGN_VALIDATED, puis IMPLEMENTATION. Date : 6 novembre 2026.

Preuve de validation : l'utilisateur a répondu « oui je valide la maquette, tu peux commencer » à la présentation de R1. Cette approbation autorise l'implémentation locale ; elle n'autorise aucune migration distante, activation, création de job ou publication.

Référence figée : `aura-r1/index.html`, `aura-r1/prototype.css`, `aura-r1/prototype.js`, copiés sans modification depuis la maquette présentée. SHA-256 :

- index.html : `A6DECB12BB1732EB9FAD555B42049B4DFFC812F343362363A173DBD6567DC0EE`
- prototype.css : `31C5D6AFA4F542F70317E0B91FF8B6AE7B8CDEB1609020AC988AB4128E06D288`
- prototype.js : `FA220D3B1557410789FC90BE15D4493E44EA5D5A369BF615E9B4F0A7FBF32BA4`

## Écrans et correspondance

| Référence | Application | Contrat |
|---|---|---|
| Agent / À prendre | Commandes Agent, rubrique territoriale | Offre, opérateur, montant, bénéficiaire masqué, ancienneté et disponibilité ; bouton Accepter et traiter |
| Agent / acceptation | Commandes Agent / RPC | Bouton désactivé pendant la demande ; conflit explicite ; succès puis détail immédiatement |
| Agent / traitement | Route détail Agent existante | Numéro autorisé après acceptation, raccourci USSD explicite, transitions métier existantes ; aucune exécution télécom automatique |
| Agent / Mes commandes | Vue personnelle existante | Affectations manuelles à accepter et commandes prises séparées de la file commune ; historique préservé |
| Manager / suivi | Page de supervision territoriale | Filtres Toutes, Acceptées, En cours, En retard, Intervention ; durée serveur, ouverture du détail existant |
| Manager / alertes | Même page de supervision | Alertes persistantes ; actives, résolues, obsolètes ; simple consultation ne résout pas l'alerte |

## Tokens et composants

Manrope ; Material Symbols Rounded existants. Fond `#F6F8FB`, surface blanche, primaire `#2E63EB`, primaire fort `#1D4ED8`, fond bleu `#E8F0FF`, texte `#101828`, secondaire `#667085`, bordure `#E4E7EC`. États avec texte, jamais seulement une couleur. Vert lisible `#147D3C`, avertissement `#8F5100`, erreur `#BC2525` pour petits textes sur fonds doux.

Échelle existante : titres 28/22/18, carte 16, texte 15, légende 13, micro 12. Espacements 8/12/16/20/24/32. Cartes rayon 14, boutons 8 ; cibles tactiles au moins 44 ; état sélectionné bleu doux, boutons principaux pleins. La présentation Flutter utilise les tokens existants et la police existante sans ajouter de dépendance.

## Interactions, états et responsive

Rubriques À prendre et Mes commandes dans Commandes ; barre principale Accueil, Commandes, Historique, Profil conservée. Routes réelles pour les détails ; Retour Android revient à la rubrique source sans accepter, finaliser ni changer implicitement d'onglet.

États : normal, chargement, vide, erreur avec réessai, hors connexion avec acceptation impossible, Agent indisponible avec motif, conflit d'acceptation, succès. Un retry après résultat perdu reconsulte le serveur et ne crée pas une seconde acceptation. Les données figées de R1 sont remplacées par les données réelles autorisées, pas par des données d'exemple dans le produit.

Petite largeur : cartes empilées ; actions pleine largeur ; texte adaptable sans débordement. Manager large : tableau ; mobile : cartes ou tableau à défilement contenu, mêmes informations et mêmes actions. Tailles de QA visées : 320, 390, 768 et 1440 px. Labels accessibles, focus visible, ordre logique, annonce des résultats sans rafale ; police agrandie à tester.

## Intouchables, écarts et QA

Paiements, historique, finances, commissions, crédit, Cabinistes, raccourcis USSD et autorisations existantes. Aucun nouveau pouvoir Manager, contact Agent–Client ou remboursement parallèle.

Aucun écart visuel volontaire approuvé. La colonne de scénarios et les commandes de simulation de R1 sont des outils de revue, exclus de l'application. Les contrôles de cycle/serveur restent dans le diagnostic et ne deviennent pas des actions utilisateur.

La vérification automatisée du prototype dans Chrome a été arrêtée par Computer Use faute d'identification fiable de l'URL ; la validation humaine de R1 est explicite. La QA locale de la candidate est maintenant consignée dans [LIVRAISON_20261106.md](LIVRAISON_20261106.md), avec les captures de widgets réels à 320/390/768/1440 px, les corrections de texte agrandi et les tests Android. La comparaison porte sur ce contrat et les sources R1 figées ; aucun comparatif navigateur pixel par pixel n'est revendiqué.
