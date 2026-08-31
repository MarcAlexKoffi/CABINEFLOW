IZYTEL — PHASE 13 COMPLETE (13A -> 13G)
======================================
Baseline: Phase 13A already integrated.
This bundle completes the financial module without replacing the existing app architecture.

WHAT IS INCLUDED
----------------
13A — Network balances
- Available and committed balances per Orange / MTN / Moov.
- Immutable networkTransactions journal.
- Successful order = atomic capacity deduction + network movement + existing commission flow.
- Manual capacity changes are now journaled as manualAdjustment movements.

13B — Suppliers
Collections:
- financeSuppliers
- supplierAccounts
- supplierRecharges
- supplierPayments
Behavior:
- Supplier creation / activation.
- Recharge attached to a real Agent and network.
- principalAmount + bonusAmount = receivedAmount.
- receivedAmount increases Agent network capacity atomically.
- supplier debt increases by principalAmount only.
- supplier payment reduces debt, with payment channel/reference.
- supplier recharge also writes an incoming networkTransactions entry atomically.

13C — Wave cash
Collections:
- financeSettings/wave
- waveBalanceAdjustments
Behavior:
- Admin sets/reconciles a Wave opening balance.
- Each reset is immutable in waveBalanceAdjustments.
- Theoretical Wave balance after opening date:
  opening + confirmed client payments + Wave credit settlements
  - Wave supplier payments - Wave refunds - Wave expenses - Wave commission payouts.
- Credit authorization itself NEVER counts as Wave income.

13D — Customer credit
Collections:
- customerCredits
- customerCreditSettlements
Behavior:
- Admin can authorize an unpaid eligible order as a credit sale.
- order.paymentStatus becomes "credit" (separate from "confirmed").
- order enters paidReady and auto-assignment without fabricating paidAt/paymentConfirmedAt/paymentReference.
- customerCredit document uses orderId as deterministic id (one credit per order).
- partial/full settlements are immutable and protected against overpayment.
- only settlements paid through Wave enter Wave cash.

13E — Expenses
Collection:
- financeExpenses
Behavior:
- category, amount, description, channel, reference, timestamp, actor.
- Wave expenses require a reference.
- entries are immutable.

13F — Working capital
Computed from existing sources of truth:
- Wave theoretical cash.
- network available / committed / free.
- supplier debt.
- customer receivables.
- commission debt.
- operating liquidity and net working capital.

13G — Daily close
Collection:
- dailyFinancialClosings
Behavior:
- deterministic document id YYYYMMDD: one closing per day.
- captures receipts, successful orders, supplier recharges/payments, credits,
  settlements, expenses, refunds, commissions, network positions, supplier debt,
  commission debt, Wave theoretical/actual balance, Wave difference and estimated profit.
- non-zero Wave difference requires a note.
- closing is immutable.

IMPORTANT ACCOUNTING RULES
--------------------------
1. Supplier bonus is stock received, not supplier debt.
2. Supplier principal is the economic stock cost even after the supplier has been paid.
3. A credit sale is not a Wave receipt.
4. A later credit settlement is a receipt only if its channel is Wave for Wave cash purposes.
5. A failed/refused order does not consume network stock.
6. Successful order network movement is deterministic: networkTransactions/order_<orderId>.
7. Supplier recharge movement is deterministic: networkTransactions/recharge_<rechargeId>.
8. Sensitive journals are immutable in Firestore rules.

INSTALLATION
------------
1. Back up the current project and firestore.rules.
2. Extract this bundle at the Flutter project root and replace matching lib/ and test/ files.
3. Replace the project firestore.rules with the included firestore.rules, but DO NOT deploy yet.
4. Run:
   flutter analyze
   flutter test
5. Validate rules locally if the Firebase emulator is configured, for example:
   firebase emulators:exec --only firestore "echo Firestore rules loaded"
6. Only after local validation, deploy the rules:
   firebase deploy --only firestore:rules

MANDATORY FUNCTIONAL TESTS BEFORE MARKING PHASE 13 VALIDATED
------------------------------------------------------------
A. 13A successful order
- Note Agent capacity and Finance network available.
- Process one paid order successfully.
- Verify exact capacity decrease and one order_<orderId> network movement.
- Verify no duplicate movement if the screen refreshes/reopens.

B. 13B supplier recharge
- Create a supplier.
- Recharge an authorized Agent/network with principal 100000 + bonus 5000.
- Verify Agent capacity +105000.
- Verify supplier debt +100000 (not 105000).
- Verify supplierRecharges, supplierAccounts and recharge_<id> networkTransactions.
- Record a partial supplier payment and verify remaining debt.
- Attempt overpayment: it must be refused.

C. 13C Wave
- Set a Wave opening balance and note the effective time.
- Confirm a new Wave client payment after that time: theoretical balance increases.
- Pay a supplier via Wave: theoretical balance decreases.
- Record a Wave expense: theoretical balance decreases.
- Pay an Agent commission via Wave: theoretical balance decreases.
- Refund via Wave: theoretical balance decreases.

D. 13D credit sale
- Select an eligible unpaid/expired order in Crédits clients.
- Authorize full order amount as credit.
- Verify order.paymentStatus == credit and status == paidReady.
- Verify paidAt/paymentConfirmedAt were NOT fabricated.
- Verify CREDIT_AUTHORIZED order event and autoAssignmentQueue entry.
- Verify order can be assigned/accepted/processed by Agent.
- Record a partial settlement; verify remaining receivable.
- Attempt settlement greater than outstanding: must fail.
- Finish settlement; status becomes settled.
- Verify only Wave settlements affect Wave theoretical cash.

E. 13E expenses
- Add cash expense: appears in expenses but not Wave cash.
- Add Wave expense with reference: appears and decreases Wave theoretical cash.
- Try Wave expense without reference: must fail.

F. 13F working capital
- Compare page totals with:
  Wave theoretical + free network + customer receivables - supplier debt - commission debt.
- Verify committed network is removed from free network availability.

G. 13G daily closing
- Open close preview and compare source totals.
- Enter actual Wave balance.
- If it differs from theoretical, verify note is mandatory.
- Close day once.
- Try to close same date again: must fail.
- Verify dailyFinancialClosings/YYYYMMDD is immutable.

FIRESTORE COLLECTIONS ADDED BY THE COMPLETE PHASE 13
-----------------------------------------------------
financeSuppliers
supplierAccounts
supplierRecharges
supplierPayments
customerCredits
customerCreditSettlements
financeExpenses
financeSettings
waveBalanceAdjustments
dailyFinancialClosings

networkTransactions already introduced in 13A and extended here.

NOTES
-----
- Existing historical orders are not retroactively converted into supplier/credit/expense records.
- Wave opening balance is intentionally an explicit accounting starting point; transactions before
  its effectiveAt are not re-counted into the new theoretical balance.
- Full runtime validation still requires Flutter/Firebase tooling on the development machine.
