# Recette locale de la file partagée IzyTel

Les commandes partent de la racine `cabine_flow`, sous Windows x64. Versions utilisées : Flutter 3.44.8, Dart 3.12.2, Node 24.14.0, PostgreSQL embarqué 17.11, Deno 2.9.6. Aucun nouveau package d'exécution n'est ajouté à l'application.

## SQL et notifications

```powershell
Push-Location test/shared_queue
npm ci
npm test
npm run test:integration
npm run test:dispatch
npm run test:edge
Pop-Location
```

Node >= 22.13 est requis pour la simulation TypeScript du dispatch. Les dépendances de test sont verrouillées par `package-lock.json`. `npm ci` et le premier contrôle Deno peuvent télécharger les outils et imports.

- `npm test` : 13 contrôles de concurrence réelle, capacité, RLS, historique, cycle SLA et droits du détecteur. Résultat daté et empreintes dans `docs/shared_queue/SQL_TEST_RESULTS.json`.
- `test:integration` : 12 scénarios sur les définitions existantes des tables, fonctions, policies, droits et triggers concernés. Inclut publication, course entre deux synchronisations, anciens workers, outbox, preuve, finalisation Agent, finance/commissions, échec Manager et finalisation/règlement Cabiniste. Résultat dans `docs/shared_queue/INTEGRATION_TEST_RESULTS.json`.
- `test:dispatch` : exécute le code du dispatch avec HTTP/FCM simulés ; priorité et payload des nouveaux événements, invalidation précise des tokens, reprise multi-appareils sans renvoi aux appareils déjà servis, bail de dispatch, destinataire devenu non autorisé et retry si l'autorisation est indisponible.
- `test:edge` : contrôle TypeScript strict de la fonction Edge, sans déploiement.

Reprise ponctuelle des trois paiements antérieurs à l'activation : `node test/shared_queue/integration.mjs --publication-only`. Ce scénario local vérifie la sélection exacte, l'intégrité des données/historique, la restauration des protections, la visibilité territoriale, les événements uniques et le retry après acceptation ; aucune production n'est contactée. Le script opérateur associé est spécifique aux trois références autorisées et ne doit pas être utilisé comme rattrapage global.

Chaque runner SQL initialise une nouvelle instance PostgreSQL sous `scratch`, écoutant uniquement sur `127.0.0.1` avec un port temporaire, puis l'arrête. Aucune URL de base ni clé distante n'est consommée. Les fichiers de catalogue décrivent le schéma ; toutes les lignes de commande, utilisateurs, soldes et notifications du test sont synthétiques.

La fixture intégrée couvre 28 tables, 422 colonnes et 45 fonctions. Les contraintes hors clés étrangères, les droits, les policies et les triggers métier utiles sont repris du catalogue. Les clés étrangères vers des tables de comptes non incluses et les hooks d'audit du cycle de vie des comptes sont exclus. Le transport HTTP/FCM et le stockage de messagerie client sont des puits locaux. Les mesures sur 1 000 commandes sont locales et ne constituent pas un dimensionnement de production.

## Flutter et captures AURA

Traitement sans photo : `node test/shared_queue/integration.mjs --fast-processing` applique aussi la migration ciblée de suppression du prérequis photo, puis vérifie les parcours réels Agent et Cabiniste sur la fixture locale. Résultats distincts dans `docs/shared_queue/FAST_PROCESSING_INTEGRATION_RESULTS.json` ; aucun ordre réel n'est exécuté.

```powershell
flutter analyze --no-pub
flutter test --no-pub test/features/orders/presentation/shared_order_queue_test.dart test/features/orders/data/repositories/shared_queue_payment_publication_test.dart --reporter expanded
```

Pour produire les captures avec Manrope et les icônes réelles :

```powershell
& ./test/shared_queue/prepare_visual_qa.ps1
$env:IZYTEL_SHARED_CAPTURE = '1'
try {
    flutter test --no-pub test/features/orders/presentation/shared_order_queue_visual_test.dart --reporter expanded
} finally {
    Remove-Item Env:IZYTEL_SHARED_CAPTURE
}
```

La préparation met les cinq fichiers Manrope en cache sous `scratch/ussd_reprise_visual`, après vérification de leurs empreintes SHA-256. Le premier passage utilise la source officielle `fonts.gstatic.com`. Les captures sous `docs/shared_queue/visual_qa` sont des rendus des widgets applicatifs, avec données synthétiques. Agent : 320/390 px ; Manager : 320/390/768/1440 px. Les fichiers 1024 px conservés sont ceux d'une passe antérieure et ne sont pas la référence finale.

La suite habituelle ignore volontairement ce test de capture ; elle est lancée une seule fois en validation finale :

```powershell
flutter test --no-pub --reporter expanded
```

## Android réel, sans backend ni paiement

Le harness utilise les composants et routes du projet avec des repositories synthétiques. Son identifiant `com.izytel.qa.shared_queue_qa` permet l'installation à côté d'IzyTel ; il n'initialise pas Firebase ni les repositories de production. Il ne prouve pas la réception FCM.

```powershell
& ./test/shared_queue/prepare_android_qa.ps1
flutter devices
Push-Location scratch/shared_queue_android_qa
flutter test --no-pub integration_test/shared_queue_test.dart -d R5CY511XDCP --reporter expanded
Pop-Location
```

Remplacer l'identifiant de téléphone par celui de `flutter devices` si nécessaire. La source versionnée est `device_scenarios.dart.template` ; le projet Android est généré dans `scratch`. Le script copie le verrou de dépendances du projet avant `flutter pub get`.

Deux scénarios vérifient l'acceptation suivie du détail sans traitement implicite, le retour, la route de notification vers À prendre, le refus hors connexion, l'alerte Manager persistante et le refus d'accès pour un rôle non autorisé. Aucun véritable envoi de notification, paiement ou ordre télécom n'est effectué.

## Builds de la candidate

```powershell
flutter build web --no-pub -t lib/main.dart --output build/shared_queue/mobile_web
flutter build web --no-pub -t lib/main_backoffice_web.dart --output build/shared_queue/backoffice_web
flutter build apk --release --no-pub
```

La signature Android utilise uniquement la configuration locale déjà existante. L'APK de livraison n'est pas le harness QA. Le build `mobile_web` valide la compilation ; il ne doit pas remplacer un site client existant sans vérifier sa cible. Les procédures distantes et la recette FCM se trouvent dans `docs/shared_queue/LIVRAISON_20261106.md`.
