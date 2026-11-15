# Recette du prototype R1

Exécutée le 15 novembre 2026. **9 tests de modèle réussis, 10 scénarios navigateur réussis, aucune erreur JavaScript de page.** Le navigateur et l’horodatage exact sont enregistrés dans [evidence/results.json](evidence/results.json).

- `model.test.mjs` : modèle local, absence d’écriture pendant l’aperçu, création en brouillon, comparaison et rejeu, identité et snapshot, désactivation, doublons/collisions, publication et unités, 520 lignes, concurrence, restauration sans suppression.
- `browser.cjs` : vrais clics et saisies sous Edge via Playwright, fichier XLSX fourni, rejets de fichiers modifiés uniquement en mémoire, responsive et clavier. Les dépendances proviennent d’une installation existante ; aucun package ajouté au projet.

Les captures sont produites par le navigateur, pas générées par IA. Les rendus du catalogue desktop et de l’assistant mobile ont été examinés visuellement après les derniers ajustements de lisibilité. Les contrôles de débordement, focus et interactions sont automatisés aux quatre largeurs indiquées.

| Capture | État |
|---|---|
| [catalogue-1440.png](evidence/catalogue-1440.png) | Cartes deux colonnes, familles variées et statuts fictifs |
| [catalogue-768.png](evidence/catalogue-768.png) | Vue intermédiaire |
| [catalogue-390.png](evidence/catalogue-390.png) | Une colonne mobile |
| [import-390.png](evidence/import-390.png) | Sélection de fichier sur mobile |
| [apercu-modele-1440.png](evidence/apercu-modele-1440.png) | Lecture des 40 lignes du modèle, écarts et compteurs |
| [erreurs-import-1440.png](evidence/erreurs-import-1440.png) | Doublons, erreurs et sélection explicite du périmètre partiel |
| [rapport-520-lignes.png](evidence/rapport-520-lignes.png) | Résultat après reprise du même importId |
| [snapshot-commande.png](evidence/snapshot-commande.png) | Prix historique conservé après modification du catalogue |

Les commandes sont dans le [guide d’ouverture](../../README.md). Les résultats ne concernent pas l’application Flutter ni un serveur Supabase. Non exécutés : rôles/RLS réels, authentification, persistance réseau, déploiement, migration, lecteur d’écran et zoom texte spécifique. La validation visuelle de la R1 par l’utilisateur reste attendue.
