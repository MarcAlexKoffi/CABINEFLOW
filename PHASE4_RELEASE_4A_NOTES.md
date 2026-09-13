# IzyTel - Phase 4 Release - Bloc 4A

## Corrections incluses

- Le manifest Android principal declare explicitement INTERNET pour les builds release.
- POST_NOTIFICATIONS est declare explicitement pour Android 13+.
- La configuration release ne reutilise plus la cle debug.
- Le build release lit `android/key.properties` et echoue clairement si la signature officielle n'est pas configuree.
- Un fichier `android/key.properties.example` est fourni sans secret.
- Un test de contrat Phase 4 verifie versioning, permissions, signature et socle FCM.

## Non modifie volontairement dans ce bloc

- `applicationId` / `namespace` restent `com.cabineflow.cabine_flow` tant que l'identifiant Android definitif IzyTel n'est pas choisi et qu'une nouvelle application Android Firebase n'a pas ete enregistree pour cet identifiant.
- `google-services.json` et `lib/firebase_options.dart` restent donc compatibles avec l'application Firebase actuelle.

## Signature a creer localement

La cle privee doit rester sur le poste de developpement. Ne jamais l'envoyer dans un chat ou la versionner.
