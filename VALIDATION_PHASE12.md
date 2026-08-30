# IzyTel — Validation Phase 12 : commissions, performances et déconnexion Admin

## 0. Principe métier retenu

La règle provisoire de rémunération est : **10 F par transaction réellement réussie**, soit 1 000 F pour 100 transactions réussies.

Une commission est créée uniquement au moment où l'Agent marque réellement la commande comme réussie, après preuve. Une affectation, une acceptation, un refus, une mise en attente ou un échec ne génèrent aucune commission.

Les performances historiques restent visibles grâce aux vraies traces `orderEvents` et `orderAssignments`, mais **aucune commission n'est fabriquée rétroactivement pour les opérations antérieures à l'activation de la Phase 12**.

Les paiements de commission sont effectués réellement dans Wave par l'Admin, puis enregistrés dans IzyTel avec la référence Wave. IzyTel ne déclenche pas automatiquement le paiement Wave.

---

## 1. Tests techniques AVANT publication des Rules

À la racine du projet :

```powershell
dart format lib test
flutter analyze
flutter test
```

Résultats attendus :

```text
No issues found!
All tests passed!
```

En cas d'erreur, ne pas publier les nouvelles Rules.

---

## 2. Publication Firestore

Une fois les tests techniques verts, remplacer `firestore.rules` par le fichier complet Phase 12 fourni, puis :

```powershell
firebase deploy --only firestore:rules
```

Résultat attendu : `Deploy complete!`

**Important :** après l'activation des commissions, utiliser la nouvelle version de l'application Agent. Une ancienne version qui ne contient pas le moteur de commission ne doit plus être utilisée pour les nouveaux traitements rémunérés.

---

## 3. Test A — Aucune rétroactivité financière

Avant de créer de nouvelles commandes, ouvrir :

- Admin → Plus → Commissions ;
- Agent → Profil → Mes performances et commissions.

Résultat attendu :

- les anciennes performances peuvent être visibles ;
- les anciennes commandes réussies ne créent pas soudainement des documents dans `commissions` ;
- aucun ancien Agent ne reçoit artificiellement un solde de commission.

---

## 4. Test B — Première transaction réussie = 10 F

Créer une nouvelle commande de test et suivre le cycle réel :

1. paiement confirmé ;
2. affectation Agent ;
3. Agent accepte ;
4. Agent démarre le traitement ;
5. Agent ajoute une preuve ;
6. Agent marque la commande comme réussie.

Résultats attendus dans Firestore :

### `commissions/{orderId}`

Le document doit avoir le même ID que la commande et contenir notamment :

```text
schemaVersion = 1
orderId = ID réel de la commande
orderReference = référence CF-...
agentId = UID Agent
agentName = nom Agent
network = orange | mtn | moov
orderAmount = montant de la commande
commissionAmount = 10
policyId = fixed-10-v1
policyType = fixedPerSuccessfulTransaction
rate = 10
earnedAt = timestamp
createdAt = timestamp
```

### `commissionAccounts/{agentId}`

Pour la première commission de cet Agent :

```text
earnedTotal = 10
paidTotal = 0
earnedTransactions = 1
lastCommissionOrderId = orderId
```

La capacité réseau Agent doit toujours être déduite comme avant la Phase 12.

---

## 5. Test C — Deuxième réussite

Traiter une seconde commande avec le même Agent.

Résultat attendu :

```text
commissions/{deuxièmeOrderId}.commissionAmount = 10
commissionAccounts/{agentId}.earnedTotal = 20
commissionAccounts/{agentId}.earnedTransactions = 2
paidTotal = 0
```

Les deux documents `commissions` doivent rester présents. Le premier ne doit pas être modifié ou supprimé.

---

## 6. Test D — Pas de double commission

Sur une commande déjà réussie :

- revenir sur le détail ;
- vérifier qu'il n'est pas possible de relancer normalement `Marquer comme réussi` ;
- vérifier Firestore.

Résultat attendu :

- un seul document `commissions/{orderId}` ;
- le compte Agent n'augmente qu'une seule fois de 10 F.

---

## 7. Test E — Refus = 0 F

Créer une commande payée et affectée à un Agent, puis faire refuser la commande avec motif.

Résultat attendu :

- aucun `commissions/{orderId}` ;
- `earnedTotal` de l'Agent ne change pas ;
- `earnedTransactions` ne change pas ;
- le comportement de réaffectation 9E reste identique.

---

## 8. Test F — Échec de traitement = 0 F

Créer une autre commande, accepter, commencer, puis utiliser `Signaler échec`.

Résultat attendu :

- aucun document commission pour cette commande ;
- aucun +10 F ;
- capacité non déduite si c'était déjà le comportement validé avant Phase 12 ;
- événement `PROCESSING_FAILED` toujours enregistré.

---

## 9. Test G — Mise en attente / reprise = 0 F jusqu'à la réussite

1. accepter une commande ;
2. démarrer ;
3. mettre en attente ;
4. reprendre.

Avant la réussite : aucune commission.

Après preuve + réussite : exactement 10 F.

---

## 10. Test H — Admin : écran Commissions

Ouvrir :

**Plus → Commissions**

Vérifier :

- Commissions générées ;
- Solde à payer ;
- Payé sur la période ;
- Transactions rémunérées ;
- filtres Tous / À payer / Payés ;
- liste des Agents ;
- aucune erreur de responsivité sur 360–430 px.

Tester les périodes :

- Aujourd'hui ;
- 7 jours ;
- Ce mois.

Les chiffres doivent évoluer avec la période.

---

## 11. Test I — Admin : détail d'un Agent

Depuis Commissions → Voir le détail.

Vérifier :

- identité Agent ;
- réseaux autorisés ;
- transactions reçues ;
- réussies ;
- refusées ;
- échouées ;
- autres/en attente ;
- taux de réussite ;
- montant total traité ;
- temps moyen de traitement ;
- commissions générées sur la période ;
- commissions payées sur la période ;
- total acquis ;
- total payé ;
- solde à payer ;
- dernières commissions.

Le montant traité doit correspondre uniquement aux commandes réellement réussies de la période.

---

## 12. Test J — Agent : isolation de ses performances

Connecté en tant qu'Agent :

**Profil → Mes performances et commissions**

Vérifier :

- l'Agent voit ses propres statistiques ;
- il voit ses commissions ;
- il voit ses paiements ;
- il ne possède aucun bouton de paiement de commission ;
- il ne voit aucune donnée d'un autre Agent.

Tester Aujourd'hui / 7 jours / Ce mois.

---

## 13. Test K — Paiement partiel de commission

Précondition : Agent avec, par exemple, 100 F à recevoir.

1. Admin → Commissions → Agent → Enregistrer un paiement ;
2. effectuer réellement un paiement Wave de test ;
3. saisir, par exemple, 60 F ;
4. saisir la vraie référence Wave ;
5. confirmer.

Résultat attendu :

### `commissionPayouts/{payoutId}`

```text
agentId = bon Agent
amount = 60
paymentChannel = wave
paymentReference = référence saisie
paidAt = timestamp
createdBy = UID Admin
createdByName = nom Admin
```

### `commissionAccounts/{agentId}`

Si le compte était :

```text
earnedTotal = 100
paidTotal = 0
```

il doit devenir :

```text
earnedTotal = 100
paidTotal = 60
balance = 40 (calculé côté application)
```

Les documents individuels `commissions` ne doivent pas être supprimés ni modifiés.

---

## 14. Test L — Paiement supérieur au solde interdit

Avec 40 F restant, essayer d'enregistrer 50 F.

Résultat attendu :

- validation refusée ;
- aucun nouveau payout ;
- `paidTotal` reste inchangé.

Tester également 0 F.

---

## 15. Test M — Référence Wave obligatoire

Essayer d'enregistrer un paiement sans référence ou avec moins de 3 caractères.

Résultat attendu : refus et aucun changement Firestore.

---

## 16. Test N — Une même référence Wave ne doit pas être enregistrée deux fois

Après un paiement enregistré avec une référence Wave, tenter de réutiliser exactement la même référence (même avec des minuscules/majuscules différentes).

Résultat attendu :

- le second enregistrement est refusé ;
- `paidTotal` n'augmente pas une deuxième fois.

---

## 17. Test O — Paiements successifs

Exemple : Agent doit recevoir 100 F.

- paiement 1 : 60 F ;
- paiement 2 : 40 F.

Résultat attendu :

```text
earnedTotal = 100
paidTotal = 100
solde = 0
```

L'Agent doit apparaître dans le filtre `Payés` et ne plus apparaître dans `À payer`.

---

## 18. Test P — Temps réel

Laisser ouvert l'écran Agent `Mes performances et commissions`.

Depuis un autre appareil/Admin, enregistrer un paiement de commission.

Résultat attendu : le montant `À recevoir` se met à jour automatiquement sans relancer l'application.

Faire également une nouvelle transaction réussie : le solde et la liste des commissions doivent se mettre à jour automatiquement.

---

## 19. Test Q — Déconnexion Admin

Admin → Plus → Se déconnecter.

1. appuyer sur Annuler : rester connecté ;
2. recommencer ;
3. confirmer.

Résultat attendu :

- `FirebaseAuth.signOut()` est effectué ;
- retour à Connexion ;
- bouton Retour Android ne rouvre pas l'espace Admin.

---

## 20. Test R — Déconnexion Agent toujours fonctionnelle

Agent → Profil → Se déconnecter.

Résultat attendu identique : retour Connexion, aucune possibilité de revenir dans la session via Retour Android.

---

## 21. Test S — Sécurité Agent

Un Agent ne doit pouvoir lire que :

- ses commissions ;
- son compte de commission ;
- ses paiements ;
- ses propres traces de performance.

Il ne doit jamais pouvoir :

- voir les commissions d'un autre Agent ;
- créer un paiement ;
- modifier `paidTotal` ;
- modifier une commission ;
- supprimer une commission ou un payout.

---

## 22. Test T — Non-régression 9E

Après Phase 12, refaire au minimum :

1. paiement confirmé ;
2. auto-affectation ;
3. Agent accepte ;
4. preuve ;
5. réussite ;
6. capacité déduite une seule fois ;
7. commission créée une seule fois.

Puis :

- refus Agent A → Agent B ;
- tous les Agents éligibles refusent → `manualAssignmentRequired = true` ;
- affectation manuelle Admin toujours fonctionnelle.

La règle de commission ne doit pas modifier l'ordre de répartition 9E.

---

## 23. Test U — Non-régression Phase 11

Vérifier rapidement :

- demandes clients ;
- résolution ;
- notification WhatsApp ;
- remboursements ;
- remboursement `approved → refunded` ;
- rapprochement ;
- Journal d'activité 11C.

Aucun de ces flux ne doit dépendre des commissions.

---

## 24. Critères de validation finale Phase 12

La Phase 12 peut être déclarée validée si :

- 1 réussite = 10 F ;
- 100 réussites = 1 000 F ;
- refus/échec = 0 F ;
- aucune double commission par commande ;
- paiement Wave tracé et plafonné au solde ;
- réutilisation de référence Wave empêchée dans l'application ;
- commissions originales immuables ;
- Agent isolé sur ses propres données ;
- Admin dispose de la vue globale ;
- performances cohérentes avec les vraies traces ;
- Admin et Agent peuvent se déconnecter proprement ;
- 9E et Phase 11 restent fonctionnelles.

---

## 25. Contrôle Firestore Rules / non-régression structurelle

Le fichier Phase 12 doit conserver :

```text
getAfter() total = 24
```

La baseline précédente en contenait 21. Les trois nouvelles lectures `getAfter()` sont uniquement :

```text
commissionAccount -> commissionPayout
commissionAccount -> commission
commission -> order
```

Elles sont unidirectionnelles et ne modifient pas les dépendances 9E existantes.

Vérifier également que les fichiers d'affectation automatique et de remboursement restent fonctionnels après les tests réels.
