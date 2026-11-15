# Politique de non-régression du style

Référence autorisée le 15 novembre 2026 : **Back-office existant**, code actuel et vidéo « Enregistrement de l’écran 2026-11-15 130243.mp4 » fournie par l’utilisateur. La demande d’implémentation directe remplace l’attente de validation du prototype R1.

- Réutiliser `BackofficeTheme`, `BackofficePalette`, `backofficePanelDecoration`, Manrope, Material Symbols, les badges et les boutons actuels.
- Garder l’introduction, les cartes blanches arrondies, les espaces, les contours, les ombres, la sidebar et la navigation existants.
- Ajouter les contrôles d’import/configuration dans des dialogues qui reprennent le formulaire actuel : rayon 22, icône bleue 46×46, marges 22/20 et actions en pied.
- Les changements visibles autorisés sont le contenu métier et les contrôles nécessaires : code, famille, brouillon, filtres, seconde colonne si la largeur le permet, sélection et progression.
- Aucun remplacement de thème ou de shell. Le prototype HTML reste une archive de conception ; ses dimensions et sa navigation ne remplacent pas l’existant.

## Vérification avant/après

Les références `catalog_card_existing_390.png` et `catalog_card_existing_930.png` ont été enregistrées **avant** l’intégration des contrôles, sur les cartes existantes et avec la police du projet. Elles ont ensuite été comparées sans les régénérer : les deux comparaisons passent.

```powershell
flutter test --no-pub test/app/modules/backoffice/catalog_style_regression_test.dart
```

Ne pas utiliser `--update-goldens` pour faire disparaître une régression. Une modification volontaire de la référence visuelle doit être expliquée et approuvée.

Les nouveaux dialogues et la page Admin sont testés à 320, 390, 768 et 1440 px. Les [captures du rendu Flutter](implementation-captures/) ont été examinées. Les tests couvrent aussi confirmation, messages d’erreur, reprise et fermeture au clavier. Recette avec lecteur d’écran et session de production non exécutée.

Les cinq polices de référence sont versionnées dans `test/support/fonts/manrope`, avec leur licence OFL. La recette de style n’exige donc aucun ancien cache `scratch` ni téléchargement de police.
