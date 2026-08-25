# CabineFlow — Phase 9C : détail et traitement d'une commande Agent

Cette livraison part de la version Phase 9B fournie et validée.

## Périmètre implémenté

La Phase 9C reste volontairement simple pour l'agent :

- un seul détail de commande dynamique, intégré dans l'onglet **Commandes** existant ;
- une commande affectée peut être **acceptée et démarrée en une seule action** ;
- compatibilité avec les anciennes commandes 9B déjà acceptées : bouton **Démarrer le traitement** si nécessaire ;
- pendant le traitement : ajout/remplacement d'une **capture de preuve**, **Marquer comme réussi**, **Signaler échec**, **En attente** ;
- **Réussite** : preuve obligatoire ;
- **Échec** : cause obligatoire, observation facultative ;
- **En attente** : motif obligatoire, la commande reste dans **En cours** et le même agent peut appuyer sur **Reprendre le traitement** ;
- après réussite ou échec, la commande passe dans l'onglet Agent **Terminées** ;
- l'agent reste limité à ses propres commandes.

Aucun écran supplémentaire hors maquette n'a été ajouté. Les saisies courtes (refus, échec, attente) utilisent des bottom sheets sombres dans le même parcours.

## Choix pour la preuve

Pour garder cette première version simple et éviter une configuration Firebase Storage supplémentaire, la capture est :

1. choisie depuis la galerie du téléphone ;
2. redimensionnée/compressée automatiquement en JPEG ;
3. limitée à 750 000 octets ;
4. enregistrée dans `orderProofs/{orderId}` dans Firestore.

Le document de preuve est séparé de `orders`, afin de ne pas alourdir le document principal de commande.

## Fichiers ajoutés/modifiés

### Ajoutés

- `lib/features/orders/domain/models/order_proof.dart`
- `lib/features/orders/presentation/pages/agent_order_detail_view.dart`
- `test/features/orders/data/repositories/fake_orders_agent_processing_test.dart`

### Modifiés

- `lib/features/orders/domain/models/queue_order.dart`
- `lib/features/orders/domain/repositories/orders_repository.dart`
- `lib/features/orders/data/mappers/firestore_order_mapper.dart`
- `lib/features/orders/data/repositories/firestore_orders_repository.dart`
- `lib/features/orders/data/repositories/fake_orders_repository.dart`
- `lib/features/orders/presentation/view_models/agent_orders_view_model.dart`
- `lib/features/orders/presentation/pages/agent_orders_page.dart`
- `test/features/orders/presentation/view_models/agent_orders_view_model_test.dart`
- `test/features/orders/presentation/pages/agent_orders_page_test.dart`
- `pubspec.yaml`
- `firestore.rules`

## Installation — ordre exact

### 1. Sauvegarder la Phase 9B validée

Fermer l'application puis arrêter Flutter avec :

```powershell
Ctrl + C
```

Faire une copie complète du projet avant tout remplacement.

### 2. Décompresser le ZIP Phase 9C dans un dossier séparé

Le ZIP ne contient que les fichiers ajoutés ou modifiés. Copier ensuite son contenu à la racine du projet CabineFlow en conservant l'arborescence et en acceptant le remplacement des fichiers existants.

**Ne pas supprimer entièrement les dossiers `lib` ou `test`.**

### 3. Installer les deux dépendances de preuve

À la racine du projet :

```powershell
flutter pub get
```

Le `pubspec.yaml` fourni ajoute :

```yaml
image_picker: ^1.2.3
image: ^4.9.2
```

### 4. Formater

```powershell
dart format lib test
```

### 5. Analyse statique

```powershell
flutter analyze
```

Résultat attendu :

```text
No issues found!
```

S'il existe une erreur, ne pas publier les règles et ne pas continuer le test fonctionnel avant correction.

### 6. Tests automatisés

D'abord les tests 9C ciblés :

```powershell
flutter test test/features/orders/data/repositories/fake_orders_agent_processing_test.dart
flutter test test/features/orders/presentation/view_models/agent_orders_view_model_test.dart
flutter test test/features/orders/presentation/pages/agent_orders_page_test.dart
```

Puis toute la suite :

```powershell
flutter test
```

Résultat attendu :

```text
All tests passed!
```

## Publication des règles Firestore

Le fichier `firestore.rules` fourni est une version complète basée sur les règles Phase 9B jointes, avec uniquement les extensions nécessaires à 9C.

### 7. Remplacer le fichier local

Remplacer le contenu du `firestore.rules` du projet par celui fourni dans cette livraison.

### 8. Vérification avant publication

Dans **Firebase Console > Firestore Database > Règles** :

1. copier l'intégralité du nouveau fichier ;
2. vérifier que l'éditeur Firebase ne signale aucune erreur de syntaxe ;
3. vérifier notamment la présence de :
   - `isValidAgentProcessingStart`
   - `isValidAgentProcessingHold`
   - `isValidAgentProcessingSuccess`
   - `isValidAgentProcessingFailure`
   - `match /orderProofs/{orderId}`
4. ne cliquer sur **Publier** que si l'éditeur n'affiche aucune erreur.

Les accès au champ `service` restent écrits sous forme sûre `data['service']`, sans notation ambiguë `.service`.

### 9. Publier

Cliquer sur **Publier**, attendre quelques secondes, fermer complètement l'application puis relancer :

```powershell
flutter run
```

## Test fonctionnel 1 — Acceptation et démarrage automatique

1. Depuis l'administration, affecter une commande `paidReady / confirmed` à Agenttest.
2. Se connecter avec Agenttest.
3. Aller dans **Commandes > À accepter**.
4. Appuyer sur **Accepter**.

Résultat attendu :

- le détail s'ouvre automatiquement ;
- la commande quitte **À accepter** ;
- elle est dans **En cours** ;
- la zone **Traitement** et **Preuve de transfert** apparaît.

Dans `orders/{orderId}` :

```text
assignmentStatus = accepted
assignedAgentId = UID de l'agent
status = inProgress
paymentStatus = confirmed
takenByUserId = UID de l'agent
takenAt = Timestamp
```

## Test fonctionnel 2 — Preuve

1. Dans une commande `inProgress`, toucher la zone **Preuve de transfert**.
2. Choisir une capture d'écran dans la galerie.
3. Attendre le message de confirmation.

Résultat attendu : un document `orderProofs/{orderId}` est créé avec notamment :

```text
schemaVersion = 1
orderId = ID de la commande
orderReference = référence
agentId = UID de l'agent
mimeType = image/jpeg
proofBytes = bytes
sizeBytes <= 750000
createdAt = Timestamp
updatedAt = Timestamp
```

Toucher de nouveau la preuve permet de la remplacer avant clôture.

## Test fonctionnel 3 — Réussite

1. Ajouter une preuve.
2. Appuyer sur **Marquer comme réussi**.
3. Confirmer.

Résultat attendu :

```text
orders.status = awaitingCustomerConfirmation
orders.completedAt = Timestamp
orders.customerConfirmationStatus = pending
orderAssignments.completedAt = Timestamp
```

Pour l'agent, son travail est terminé : la commande apparaît dans **Terminées**. Le futur retour/confirmation client peut rester à traiter séparément par le flux prévu de l'application.

Tester aussi le bouton sans preuve : la réussite doit être refusée avec un message demandant d'ajouter d'abord une capture.

## Test fonctionnel 4 — Mise en attente et reprise

Avec une autre commande :

1. accepter la commande ;
2. appuyer sur **En attente** ;
3. saisir ou choisir un motif court ;
4. confirmer.

Résultat attendu :

```text
status = onHold
lastHoldReason = motif
lastHeldAt = Timestamp
```

La commande reste dans **En cours** et reste affectée au même agent.

Appuyer sur **Reprendre le traitement**.

Résultat attendu :

```text
status = inProgress
lastResumedAt = Timestamp
```

## Test fonctionnel 5 — Échec

Avec une autre commande `inProgress` :

1. appuyer sur **Signaler échec** ;
2. choisir la cause principale ;
3. ajouter éventuellement une observation ;
4. confirmer.

La preuve n'est pas obligatoire pour un échec.

Résultat attendu :

```text
status = failed
failureReason = cause choisie
observation = texte ou null
completedAt = Timestamp
orderAssignments.completedAt = Timestamp
```

La commande apparaît dans **Terminées**.

## Test fonctionnel 6 — Compatibilité avec une commande acceptée en Phase 9B

Si une ancienne commande possède :

```text
assignmentStatus = accepted
status = paidReady
```

le détail affiche **Démarrer le traitement**. Appuyer dessus doit la passer à `inProgress` sans nouvelle acceptation.

## Test de sécurité indispensable

Avec deux agents A et B :

- affecter la commande à A ;
- A peut la voir et la traiter ;
- B ne doit pas la voir dans ses listes ;
- B ne doit pas pouvoir lire/modifier sa preuve ;
- un refus avant acceptation doit toujours remettre la commande dans le circuit de réaffectation, comme en 9B.

## Important

Aucun nouvel index composite n'est intentionnellement requis par 9C. Si Firestore affiche explicitement une erreur `failed-precondition` demandant un index, utiliser uniquement le lien d'index fourni par Firebase et conserver le message exact pour vérification.

Cette livraison a fait l'objet d'un contrôle structurel des fichiers Dart et des règles (imports locaux, parenthèses/accolades, fonctions/règles ajoutées et absence de `.service`). L'environnement de génération ne contient pas le SDK Flutter du projet ; les commandes `flutter analyze` et `flutter test` ci-dessus restent donc les validations locales obligatoires avant publication définitive.
