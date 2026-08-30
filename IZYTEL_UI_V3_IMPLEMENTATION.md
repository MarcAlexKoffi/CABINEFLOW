# IzyTel — UI V3 / alignement maquette maîtresse

## Référence verrouillée

Cette passe reprend les règles de la maquette IzyTel validée et ne doit plus être interprétée écran par écran.

### Palette
- Primaire : `#2E63EB`
- Secondaire : `#38BDF8`
- Succès : `#16A34A`
- Attention : `#F59E0B`
- Erreur : `#EF4444`
- Neutre : `#F1F5F9`
- Fond : `#F6F8FB`
- Texte principal : `#101828`

### Typographie
Manrope :
- Titre 1 : 28 / 700
- Titre 2 : 22 / 700
- Titre 3 : 18 / 600
- Titre de carte : 16 / 600
- Texte : 15 / 500
- Label : 13 / 500
- Micro : 12 / 400

Les numéros bénéficiaires et les montants utilisent la même grille, avec un poids 700 pour rester immédiatement lisibles pendant une opération de cabine.

### Iconographie
Les cinq écrans maîtres et les navigations utilisent `material_symbols_icons` en variante Rounded. Les marques continuent d'utiliser les vrais assets Orange, MTN, Moov Africa, IzyTel et Google.

### Espacements
Grille : 8 / 12 / 16 / 20 / 24 / 32.

## Correctifs de cette passe

1. Connexion : suppression des hauteurs fixes autour des `TextFormField`; le cadre ne se contracte plus lorsqu'une erreur apparaît. La validation automatique est déclenchée à la perte de focus, pas à chaque caractère saisi.
2. Connexion : repositionnement du hero de marque et utilisation des vrais assets `izyTel_logo.png` et `google_logo.png`.
3. Typographie : création d'une échelle unique dans `izytel_design_tokens.dart` et migration des cinq écrans maîtres.
4. Commandes Admin : numéro bénéficiaire et montant remontés dans la hiérarchie; référence conservée en information secondaire.
5. File Agent : numéro, offre, montant et action `Accepter` ont une hiérarchie métier stable; les informations secondaires ne rivalisent plus avec la transaction.
6. Détail commande : résumé transactionnel renforcé, timeline et lignes de menu remises sur la même grille typographique et iconographique.
7. Accueil Admin : titres, KPI, actions, réseaux et activité récente remis sur la hiérarchie Manrope officielle.
8. Navigation : icônes 24 px / labels 12 px; stacks Navigator indépendantes par onglet Admin et Agent. Le bouton Retour tente d'abord de dépiler l'onglet courant, puis revient à l'Accueil, puis quitte seulement depuis la racine.
9. Avatar : les bottom sheets de compte existants sont conservés et harmonisés avec le design system.

## Fichiers métier préservés

Cette passe UI ne modifie pas les repositories Firestore, les règles Firestore ni le sélecteur d'auto-affectation 9E.

## Validation à lancer sur le poste Flutter

La dépendance Material Symbols a été ajoutée au `pubspec.yaml`, donc commencer par :

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run
```

Résultats attendus :

```text
No issues found!
All tests passed!
```

Valider ensuite les cinq écrans maîtres sur le téléphone réel :
- Connexion
- Accueil Admin
- Commandes Admin
- File Agent
- Détail commande Agent
