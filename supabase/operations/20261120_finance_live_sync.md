# Finances synchronisées — 1.0.13+14

Migrations installées : `20261120020136_finance_live_consistent_totals` et `20261120225552_finance_closing_consistent_snapshot`.

Back-office publié : https://izytel-backoffice-4bca7.web.app (1.0.13, build 14). Bundle vérifié par HTTP, SHA-256 `f72862a1dba5540a263d10c64b2e462ada10167c28de783393ea198bb82fc3e5`.

APK signé : `dist/android/latest/izytel-1.0.13-build14.apk`, paquet `com.izytel.app`, versionCode 14. SHA-256 `abe2753651ca4d6ea6f6e9cba8e703ddd5a08cbfac459f307f079f063ccd3101`. Certificat identique à la version 1.0.12 ; mise à jour possible avec `adb install -r`.

## Comportement livré

- Un seul RPC et un même snapshot PostgreSQL pour les soldes, dettes, règlements Cabinistes et indicateurs courants. Un contrat incomplet échoue explicitement ; aucune dette absente n’est remplacée par zéro.
- Totaux journaliers et créances calculés sur toutes les écritures, indépendamment des fenêtres de présentation (500/600/700/1000 lignes). Les contrôles commande/paiement/crédit/remboursement rapprochent les tables complètes.
- Périodes : totaux exacts au-delà des 2000 lignes de détail, actualisation après une nouvelle lecture financière, dernière période valide conservée pendant son rafraîchissement, protection contre les réponses devenues obsolètes. Journée métier : Africa/Abidjan.
- Signal Realtime existant conservé pour les commandes, stocks, commissions, fournisseurs, dépenses, crédits, remboursements et compensations. Ajout des modifications de partenaires. Relecture de secours toutes les 15 secondes lorsque la page est ouverte, même si le signal reste silencieux. Le temps de lecture et la connectivité s’ajoutent à ce délai.
- Les stocks des comptes suspendus restent des actifs comptables et apparaissent explicitement dans chaque synthèse réseau.
- Une ancienne copie Firestore ne peut plus écraser le stock Supabase d’un Agent déjà initialisé.
- La clôture utilise la même lecture PostgreSQL pour tous ses totaux et déduit aussi les règlements Cabinistes Wave XOF, conformément au solde affiché. Les anciennes clôtures restent inchangées.
- Règlement fournisseur mobile : validation du montant et d’une référence de 3 à 120 caractères avant fermeture du formulaire ; pas de proposition de rejouer une saisie définitivement refusée. Les reprises réseau gardent la même intention et leur protection contre les doublons.

## Vérification

- `node test/finance_sql/run.mjs` : 15 cas PostgreSQL isolés, dont 601 crédits, 1201 commandes, 2101 dépenses, limites de dates/canaux, rapprochement complet, reprise historique, signal transactionnel et concordance clôture/Wave.
- `node test/manager_supplier_payment/run.mjs` : 10 cas PostgreSQL isolés (périmètre Manager, identité, refus de doublons et surpaiements, droits).
- 68 tests Flutter finance, données, reprise, rafraîchissement périodique et formulaire de règlement ; analyse statique sans anomalie.
- Lecture de contrôle du RPC installé en production ; propriétaires et droits des fonctions existantes conservés. Le nouvel agrégateur privé n’est pas exécutable par les clients.
- Aucune opération commerciale réelle exécutée pour les tests. La migration ne met à jour aucun stock, paiement, compte ou clôture. L’activité utilisateur continue pendant la livraison et peut changer les empreintes des données.

Les listes restent des fenêtres d’historique ; les totaux financiers ne dépendent plus de leur longueur. Le résultat opérationnel conserve sa qualification d’estimation de marge réseau, ce n’est pas un bénéfice comptable certifié.

## Retour arrière

Les définitions, ACL et empreintes avant installation se trouvent dans `.izytel_backups/finance_live_before.json`, `finance_live_access_before.json` et `finance_live_rollback.sql` (ignorés par Git). Aucune donnée financière n’est à restaurer.

1. Republier le bundle Back-office précédent avant de retirer les clés du nouveau contrat ; les nouveaux clients refusent un snapshot incomplet.
2. Restaurer les définitions sauvegardées via une nouvelle migration Supabase, avec lecture UTF-8 explicite.
3. Retirer `bo5_touch_partner_accounts` de `public.partner_accounts`, puis le helper `private.izytel_finance_period_totals(timestamptz,timestamptz)` après restauration des fonctions qui l’appellent.
4. Vérifier les contrôles Admin, les ACL et une lecture financière. Ne rétablir aucune ancienne valeur de stock ou dette depuis une copie historique.
