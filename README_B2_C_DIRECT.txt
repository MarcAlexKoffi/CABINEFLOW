IZYTEL - LOT B2 + C - LIVRAISON DIRECTE LIB + TEST
Date: 2026-09-01

OBJECTIF
- Avatar Agent en Blob Firestore, sans Firebase Storage.
- Piece d'identite Agent en Blob Firestore, sans Firebase Storage.
- Limites: avatar 250000 octets; piece 850000 octets.
- Images compressees localement en JPEG; PDF accepte seulement s'il reste <= 850000 octets.
- Activite Agent V2 en lecture seule: commandes, affectations/refus, mouvements/recharges,
  commissions, versements, capacites et signalements.
- Profil personnel, avatar, piece et activite consultables par l'Administrateur.
- Aucun nouveau stockage agentActivities; les donnees restent derivees des collections metier existantes.

STRUCTURE DE CE ZIP
lib/       -> a fusionner directement avec le lib/ du projet
test/      -> a fusionner directement avec le test/ du projet
scripts/   -> patch Firestore et raccord Admin securises

IMPORTANT - ANCIEN PAQUET
Si un dossier payload/ existe encore a la racine de cabine_flow, supprime-le AVANT toute validation:
  Remove-Item -Recurse -Force .\payload

POURQUOI IL N'Y A PAS UN FIRESTORE.RULES DE REMPLACEMENT DANS CE ZIP
La baseline B2+C doit conserver strictement 9E, commandes, capacites, paiements,
commissions, remboursements et les flux deja valides. Le script fourni modifie donc
le firestore.rules ACTUEL de ton projet de facon additive et cree une sauvegarde.
Il ne remplace jamais les regles par une ancienne copie.

INSTALLATION
Depuis la racine de cabine_flow:

1. Sauvegarder le projet.
2. Extraire CE ZIP directement a la racine et accepter la fusion de lib/ et test/.
3. Brancher le nouvel acces B2+C dans la fiche Agent Admin existante:
   powershell -ExecutionPolicy Bypass -File .\scripts\patch_admin_agent_detail_b2c.ps1 -Root .
4. Appliquer les ajouts Firestore sur les regles ACTUELLES:
   powershell -ExecutionPolicy Bypass -File .\scripts\apply_agent_blob_activity_v2_rules.ps1 -RulesPath .\firestore.rules
5. Regenerer/valider:
   flutter pub get
   dart format lib test
   flutter analyze
   flutter test
6. Verification structurelle supplementaire:
   powershell -ExecutionPolicy Bypass -File .\scripts\verify_agent_blob_activity_v2.ps1 -Root .

RESULTATS ATTENDUS
flutter analyze:
  No issues found!
flutter test:
  All tests passed!

Ne deployer les regles qu'apres ces validations:
  firebase deploy --only firestore:rules --project cabineflow-4bca7

FIREBASE STORAGE
B2 n'utilise aucune API Firebase Storage pour l'avatar ni pour la piece d'identite.
Ce correctif ne supprime volontairement pas la dependance firebase_storage du pubspec:
un autre module historique pourrait encore l'utiliser. La suppression globale de la
dependance ne doit se faire qu'apres verification de tout le projet.

SCHEMA BLOB
agentPersonalMedia/{agentId}/items/avatar
agentPersonalMedia/{agentId}/items/identity

Champs:
- schemaVersion
- agentId
- kind
- fileName
- mimeType
- contentBytes (Firestore Blob)
- sizeBytes
- createdAt
- updatedAt

SECURITE
- Agent: lecture de ses propres medias uniquement.
- Agent: creation/remplacement de ses propres medias uniquement.
- Avatar: reste modifiable apres verification.
- Piece: verrouillee lorsque le profil est verified.
- Admin: lecture de l'identite, des medias et de l'activite.
- Admin: verification du profil; le statut verified exige l'existence du Blob identity.
- Aucune suppression de media depuis le client.

ACTIVITE V2 - SOURCES EXISTANTES
- orders
- orderAssignments
- networkTransactions
- commissions
- commissionAccounts
- commissionPayouts
- agentProfiles
- agentIssues

NON-REGRESSION
Le lot ne fournit aucun remplacement des repositories de commandes, du moteur 9E,
des paiements ou des commissions. Il ajoute des lectures et le stockage prive B2.
Le script de regles refuse de continuer s'il ne retrouve pas les contrats critiques.

RECETTE MINIMALE
1. Agent: enregistrer profil texte seul.
2. Agent: choisir avatar depuis galerie puis appareil photo; verifier l'affichage apres relance.
3. Agent: ajouter une piece image > 850 Ko; verifier qu'elle est compressee sous la limite.
4. Agent: ajouter un PDF <= 850 Ko; verifier l'enregistrement.
5. Agent: essayer un PDF > 850 Ko; verifier le refus local avant Firestore.
6. Admin: ouvrir la fiche Agent -> Identite & activite; voir infos, avatar et piece.
7. Admin: verifier le profil; puis Agent: verifier que la piece est verrouillee et avatar modifiable.
8. Activite: verifier commandes, historique, mouvements/recharges, commissions et capacites.
9. Non-regression: paiement -> 9E -> acceptation -> preuve -> succes -> completed ->
   deduction capacite une seule fois -> networkTransaction -> commission une seule fois.
10. Tester refus/reaffectation, mise en attente/reprise, remboursements et historique existant.

VALIDATION DANS CET ENVIRONNEMENT
Le SDK Flutter/Dart et PowerShell ne sont pas installes ici. Le paquet est donc controle
structurellement, mais la validation definitive reste flutter analyze + flutter test sur
ton poste Windows avec la baseline reelle.
