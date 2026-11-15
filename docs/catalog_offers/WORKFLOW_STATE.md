# État de CAT-IMPORT-01

2026-11-15 · Catalogue et imports d’offres · **candidate intégrée, contrôles locaux terminés ; backend mis en service avec accord utilisateur**.

La dernière consigne utilisateur autorise l’implémentation directe avec le style existant. Elle remplace le gate de validation R1 décrit historiquement ci-dessous. Le prototype HTML R1 n’est pas déclaré validé et ne sert pas de contrat de style : la référence est désormais le code existant et la vidéo fournie, selon [STYLE_NON_REGRESSION.md](STYLE_NON_REGRESSION.md).

Flutter + Edge + migration implémentés. Analyse propre, 36 tests Flutter, 16 scénarios SQL et 5 tests du parseur réussis ; build Web réussi. Le backend a été déployé après autorisation explicite : sauvegarde privée, migration ciblée, fonction active et cinq contrôles HTTP réussis. Les 35 offres conservent tous leurs champs d’origine ; aucun import n’a été créé. [Relevé de déploiement](deployment-results.json). L’hébergement frontend et la recette authentifiée en production restent à effectuer. État courant détaillé dans [IMPLEMENTATION.md](IMPLEMENTATION.md).

## Historique du cadrage initial

| Étape | État |
|---|---|
| AURA_READY | Brief reçu, modèle lu en consultation ; 40 propositions BROUILLON identifiées |
| Décision de persistance | Utilisateur : conserver Supabase et sécuriser les imports côté serveur |
| DESIGN_REVIEW | Prototype interactif R1 et dossier de conception livrés ; contrôles locaux dans `aura-r1/qa` |
| DESIGN_VALIDATED | En attente d’une validation explicite de la R1 ; aucun contrat visuel figé |
| IMPLEMENTATION | Non commencée pour cette fonctionnalité ; backlog et relais préparés |
| VISUAL_QA application | Non exécutée ; seules les captures et interactions du prototype ont été contrôlées |
| TECHNICAL_AUDIT production | Non exécuté ; aucun accès ou changement distant |
| DONE | Non atteint pour l’intégration fonctionnelle |

Le blocage volontaire de publication ACTIF dans la simulation évite de présenter une règle de fraîcheur ou de livraison non définie comme validée. Il reste à préciser la fraîcheur, les justificatifs conditionnels, l’archive et le mapping des codes historiques avant d’implémenter ces comportements.

Prochaine étape : revue utilisateur de la R1. Après accord, figer `DESIGN_CONTRACT.md`, résoudre les critères métier ouverts et intégrer selon les [issues proposées](issues/README.md). Les contrôles serveur et les validations Flutter seront réalisés pendant cette intégration.
