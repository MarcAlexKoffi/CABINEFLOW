import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/finances/domain/models/finance_operations_models.dart';
import 'package:cabine_flow/features/finances/domain/repositories/finance_operations_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreFinanceOperationsRepository
    implements FinanceOperationsRepository {
  FirestoreFinanceOperationsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _suppliers =>
      _firestore.collection('financeSuppliers');
  CollectionReference<Map<String, dynamic>> get _supplierAccounts =>
      _firestore.collection('supplierAccounts');
  CollectionReference<Map<String, dynamic>> get _supplierRecharges =>
      _firestore.collection('supplierRecharges');
  CollectionReference<Map<String, dynamic>> get _supplierPayments =>
      _firestore.collection('supplierPayments');
  CollectionReference<Map<String, dynamic>> get _credits =>
      _firestore.collection('customerCredits');
  CollectionReference<Map<String, dynamic>> get _creditSettlements =>
      _firestore.collection('customerCreditSettlements');
  CollectionReference<Map<String, dynamic>> get _expenses =>
      _firestore.collection('financeExpenses');
  CollectionReference<Map<String, dynamic>> get _settings =>
      _firestore.collection('financeSettings');
  CollectionReference<Map<String, dynamic>> get _waveAdjustments =>
      _firestore.collection('waveBalanceAdjustments');
  CollectionReference<Map<String, dynamic>> get _dailyClosings =>
      _firestore.collection('dailyFinancialClosings');
  CollectionReference<Map<String, dynamic>> get _agentProfiles =>
      _firestore.collection('agentProfiles');
  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection('orders');
  CollectionReference<Map<String, dynamic>> get _orderEvents =>
      _firestore.collection('orderEvents');
  CollectionReference<Map<String, dynamic>> get _autoAssignmentQueue =>
      _firestore.collection('autoAssignmentQueue');
  CollectionReference<Map<String, dynamic>> get _networkTransactions =>
      _firestore.collection('networkTransactions');

  @override
  Stream<List<FinanceSupplier>> watchSuppliers() {
    return _suppliers
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => List<FinanceSupplier>.unmodifiable(
            snapshot.docs
                .map(_supplierFromDocument)
                .whereType<FinanceSupplier>(),
          ),
        );
  }

  @override
  Stream<List<SupplierAccount>> watchSupplierAccounts() {
    return _supplierAccounts
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => List<SupplierAccount>.unmodifiable(
            snapshot.docs
                .map(_supplierAccountFromDocument)
                .whereType<SupplierAccount>(),
          ),
        );
  }

  @override
  Stream<List<SupplierRecharge>> watchSupplierRecharges() {
    return _supplierRecharges
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => List<SupplierRecharge>.unmodifiable(
            snapshot.docs
                .map(_supplierRechargeFromDocument)
                .whereType<SupplierRecharge>(),
          ),
        );
  }

  @override
  Stream<List<SupplierPayment>> watchSupplierPayments() {
    return _supplierPayments
        .orderBy('paidAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => List<SupplierPayment>.unmodifiable(
            snapshot.docs
                .map(_supplierPaymentFromDocument)
                .whereType<SupplierPayment>(),
          ),
        );
  }

  @override
  Stream<List<CustomerCredit>> watchCustomerCredits() {
    return _credits
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => List<CustomerCredit>.unmodifiable(
            snapshot.docs
                .map(_customerCreditFromDocument)
                .whereType<CustomerCredit>(),
          ),
        );
  }

  @override
  Stream<List<CustomerCreditSettlement>> watchCustomerCreditSettlements() {
    return _creditSettlements
        .orderBy('paidAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => List<CustomerCreditSettlement>.unmodifiable(
            snapshot.docs
                .map(_creditSettlementFromDocument)
                .whereType<CustomerCreditSettlement>(),
          ),
        );
  }

  @override
  Stream<List<FinanceExpense>> watchExpenses() {
    return _expenses
        .orderBy('spentAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => List<FinanceExpense>.unmodifiable(
            snapshot.docs.map(_expenseFromDocument).whereType<FinanceExpense>(),
          ),
        );
  }

  @override
  Stream<WaveOpeningBalance?> watchWaveOpeningBalance() {
    return _settings.doc('wave').snapshots().map(_waveOpeningFromDocument);
  }

  @override
  Stream<List<WaveBalanceAdjustment>> watchWaveBalanceAdjustments() {
    return _waveAdjustments
        .orderBy('effectiveAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => List<WaveBalanceAdjustment>.unmodifiable(
            snapshot.docs
                .map(_waveAdjustmentFromDocument)
                .whereType<WaveBalanceAdjustment>(),
          ),
        );
  }

  @override
  Stream<List<DailyFinancialClosing>> watchDailyClosings() {
    return _dailyClosings
        .orderBy('closedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => List<DailyFinancialClosing>.unmodifiable(
            snapshot.docs
                .map(_dailyClosingFromDocument)
                .whereType<DailyFinancialClosing>(),
          ),
        );
  }

  @override
  Future<String> createSupplier({
    required String name,
    required String phoneNumber,
    required String staffId,
    required String staffName,
    String? note,
  }) async {
    final String cleanedName = name.trim();
    if (cleanedName.length < 2) {
      throw ArgumentError('Le nom du fournisseur est requis.');
    }
    final DocumentReference<Map<String, dynamic>> ref = _suppliers.doc();
    await ref.set(<String, dynamic>{
      'schemaVersion': 1,
      'name': cleanedName,
      'phoneNumber': phoneNumber.trim(),
      'isActive': true,
      'note': _nullable(note),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': staffId,
      'createdByName': staffName.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': staffId,
      'updatedByName': staffName.trim(),
    });
    return ref.id;
  }

  Future<void> createSupplierCompatibilityMirror({
    required String supplierId,
    required String name,
    required String phoneNumber,
    required String staffId,
    required String staffName,
    String? note,
  }) async {
    final String cleanedName = name.trim();
    if (cleanedName.length < 2) {
      throw ArgumentError('Le nom du fournisseur est requis.');
    }
    await _suppliers.doc(supplierId.trim()).set(<String, dynamic>{
      'schemaVersion': 1,
      'name': cleanedName,
      'phoneNumber': phoneNumber.trim(),
      'isActive': true,
      'note': _nullable(note),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': staffId,
      'createdByName': staffName.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': staffId,
      'updatedByName': staffName.trim(),
    });
  }

  @override
  Future<void> setSupplierActive({
    required String supplierId,
    required bool isActive,
    required String staffId,
    required String staffName,
  }) async {
    await _suppliers.doc(supplierId).update(<String, dynamic>{
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': staffId,
      'updatedByName': staffName.trim(),
    });
  }

  @override
  Future<void> updateSupplier({
    required String supplierId,
    required String name,
    required String phoneNumber,
    required String staffId,
    required String staffName,
    String? note,
  }) async {
    final String cleanedName = name.trim();
    if (cleanedName.length < 2) {
      throw ArgumentError('Le nom du fournisseur est requis.');
    }
    await _suppliers.doc(supplierId).update(<String, dynamic>{
      'name': cleanedName,
      'phoneNumber': phoneNumber.trim(),
      'note': _nullable(note),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': staffId,
      'updatedByName': staffName.trim(),
    });
  }

  @override
  Future<void> deleteSupplier({required String supplierId}) async {
    final DocumentReference<Map<String, dynamic>> supplierRef = _suppliers.doc(
      supplierId,
    );
    final DocumentSnapshot<Map<String, dynamic>> supplier = await supplierRef
        .get();
    if (!supplier.exists) {
      throw StateError('Fournisseur introuvable.');
    }

    final DocumentSnapshot<Map<String, dynamic>> account =
        await _supplierAccounts.doc(supplierId).get();
    if (account.exists) {
      throw StateError(
        'Ce fournisseur possède déjà un historique financier. Désactive-le plutôt que de le supprimer.',
      );
    }

    await supplierRef.delete();
  }

  @override
  Future<String> recordSupplierRecharge({
    required SupplierRechargeDraft draft,
    required String staffId,
    required String staffName,
  }) async {
    if (draft.principalAmount <= 0 ||
        draft.bonusAmount < 0 ||
        draft.receivedAmount <= 0) {
      throw ArgumentError('Les montants de recharge sont invalides.');
    }
    if (draft.amountOwed != draft.principalAmount) {
      throw ArgumentError(
        'Une recharge crée d’abord la dette complète du principal. Enregistre ensuite tout règlement fournisseur séparément.',
      );
    }

    final DocumentReference<Map<String, dynamic>> rechargeRef =
        _supplierRecharges.doc();
    final DocumentReference<Map<String, dynamic>> networkRef =
        _networkTransactions.doc('recharge_${rechargeRef.id}');
    final DocumentReference<Map<String, dynamic>> supplierRef = _suppliers.doc(
      draft.supplierId,
    );
    final DocumentReference<Map<String, dynamic>> accountRef = _supplierAccounts
        .doc(draft.supplierId);
    final DocumentReference<Map<String, dynamic>> agentRef = _agentProfiles.doc(
      draft.agentId,
    );

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> supplierSnapshot =
          await transaction.get(supplierRef);
      final DocumentSnapshot<Map<String, dynamic>> agentSnapshot =
          await transaction.get(agentRef);
      final DocumentSnapshot<Map<String, dynamic>> accountSnapshot =
          await transaction.get(accountRef);
      if (!supplierSnapshot.exists ||
          supplierSnapshot.data()?['isActive'] != true) {
        throw StateError('Ce fournisseur est indisponible.');
      }
      if (!agentSnapshot.exists || agentSnapshot.data() == null) {
        throw StateError('Le profil Agent est introuvable.');
      }

      // Pendant la migration hybride, le nom courant du fournisseur vit sur
      // Supabase. Les règles Firestore historiques comparent encore la recharge
      // au nom du miroir financeSuppliers : on utilise donc ce nom legacy
      // uniquement dans les écritures Firestore de compatibilité.
      final String compatibilitySupplierName =
          (supplierSnapshot.data()?['name'] as String? ?? '').trim();
      if (compatibilitySupplierName.length < 2) {
        throw StateError('Le miroir fournisseur Firebase est invalide.');
      }

      final Map<String, dynamic> agentData = agentSnapshot.data()!;
      final List<String> authorizedNetworks =
          (agentData['authorizedNetworks'] is List)
          ? (agentData['authorizedNetworks'] as List)
                .whereType<String>()
                .toList(growable: false)
          : const <String>[];
      if (!authorizedNetworks.contains(draft.network.firestoreValue)) {
        throw StateError(
          'Cet Agent n’est pas autorisé sur ${draft.network.label}.',
        );
      }
      final String capacityField = _capacityField(draft.network);
      final int before = _int(agentData[capacityField]);
      final int after = before + draft.receivedAmount;
      if (after > 100000000) {
        throw StateError('La capacité réseau dépasse la limite autorisée.');
      }

      transaction.update(agentRef, <String, dynamic>{
        capacityField: after,
        _movementMarkerField(draft.network): networkRef.id,
        'lastCapacityUpdateAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(rechargeRef, <String, dynamic>{
        'schemaVersion': 1,
        'supplierId': draft.supplierId,
        'supplierName': compatibilitySupplierName,
        'agentId': draft.agentId,
        'agentName': draft.agentName.trim(),
        'network': draft.network.firestoreValue,
        'principalAmount': draft.principalAmount,
        'bonusAmount': draft.bonusAmount,
        'receivedAmount': draft.receivedAmount,
        'amountOwed': draft.amountOwed,
        'capacityBefore': before,
        'capacityAfter': after,
        'note': _nullable(draft.note),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': staffId,
        'createdByName': staffName.trim(),
      });

      transaction.set(networkRef, <String, dynamic>{
        'schemaVersion': 1,
        'network': draft.network.firestoreValue,
        'direction': 'incoming',
        'type': 'supplierRecharge',
        'amount': draft.receivedAmount,
        'capacityBefore': before,
        'capacityAfter': after,
        'agentId': draft.agentId,
        'agentName': draft.agentName.trim(),
        'orderId': null,
        'orderReference': null,
        'supplierId': draft.supplierId,
        'supplierName': compatibilitySupplierName,
        'supplierRechargeId': rechargeRef.id,
        'createdBy': staffId,
        'createdByRole': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      });

      final Map<String, dynamic>? accountData = accountSnapshot.data();
      final int currentOwed = _int(accountData?['totalOwed']);
      final int currentPaid = _int(accountData?['totalPaid']);
      final int currentRecharged = _int(accountData?['totalRecharged']);
      final int currentCount = _int(accountData?['rechargeCount']);
      transaction.set(accountRef, <String, dynamic>{
        'schemaVersion': 1,
        'supplierId': draft.supplierId,
        'supplierName': compatibilitySupplierName,
        'totalOwed': currentOwed + draft.amountOwed,
        'totalPaid': currentPaid,
        'totalRecharged': currentRecharged + draft.receivedAmount,
        'rechargeCount': currentCount + 1,
        'lastRechargeId': rechargeRef.id,
        'lastPaymentId': accountData?['lastPaymentId'],
        'createdAt': accountSnapshot.exists
            ? accountData!['createdAt']
            : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    return rechargeRef.id;
  }

  @override
  Future<String> recordSupplierPayment({
    required SupplierPaymentDraft draft,
    required String staffId,
    required String staffName,
  }) async {
    if (draft.amount <= 0) {
      throw ArgumentError('Le montant du règlement doit être positif.');
    }
    if (draft.reference.trim().length < 3) {
      throw ArgumentError('La référence du règlement est requise.');
    }
    final DocumentReference<Map<String, dynamic>> paymentRef = _supplierPayments
        .doc();
    final DocumentReference<Map<String, dynamic>> supplierRef = _suppliers.doc(
      draft.supplierId,
    );
    final DocumentReference<Map<String, dynamic>> accountRef = _supplierAccounts
        .doc(draft.supplierId);

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> supplierSnapshot =
          await transaction.get(supplierRef);
      final DocumentSnapshot<Map<String, dynamic>> accountSnapshot =
          await transaction.get(accountRef);
      if (!supplierSnapshot.exists) {
        throw StateError('Fournisseur introuvable.');
      }
      if (!accountSnapshot.exists || accountSnapshot.data() == null) {
        throw StateError('Aucune dette fournisseur n’est enregistrée.');
      }
      final Map<String, dynamic> account = accountSnapshot.data()!;
      final int owed = _int(account['totalOwed']);
      final int paid = _int(account['totalPaid']);
      final int balance = owed - paid;
      if (draft.amount > balance) {
        throw StateError('Le règlement dépasse le montant restant dû.');
      }

      transaction.set(paymentRef, <String, dynamic>{
        'schemaVersion': 1,
        'supplierId': draft.supplierId,
        'supplierName': draft.supplierName.trim(),
        'amount': draft.amount,
        'paymentChannel': draft.channel.storageValue,
        'paymentReference': draft.reference.trim(),
        'note': _nullable(draft.note),
        'paidAt': FieldValue.serverTimestamp(),
        'createdBy': staffId,
        'createdByName': staffName.trim(),
      });
      transaction.update(accountRef, <String, dynamic>{
        'totalPaid': paid + draft.amount,
        'lastPaymentId': paymentRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    return paymentRef.id;
  }

  @override
  Future<String> createCustomerCredit({
    required CustomerCreditDraft draft,
    required String staffId,
    required String staffName,
  }) async {
    if (draft.amount <= 0) {
      throw ArgumentError('Le montant du crédit doit être positif.');
    }
    final String cleanedStaffId = staffId.trim();
    final String cleanedStaffName = staffName.trim();
    if (cleanedStaffId.isEmpty || cleanedStaffName.length < 2) {
      throw ArgumentError('L’administrateur connecté est invalide.');
    }

    final DocumentReference<Map<String, dynamic>> orderRef = _orders.doc(
      draft.orderId,
    );
    final DocumentReference<Map<String, dynamic>> creditRef = _credits.doc(
      draft.orderId,
    );
    final DocumentReference<Map<String, dynamic>> eventRef = _orderEvents.doc();
    final DocumentReference<Map<String, dynamic>> queueRef =
        _autoAssignmentQueue.doc(draft.orderId);

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> orderSnapshot =
          await transaction.get(orderRef);
      final DocumentSnapshot<Map<String, dynamic>> existingCredit =
          await transaction.get(creditRef);
      if (!orderSnapshot.exists || orderSnapshot.data() == null) {
        throw StateError('Commande introuvable.');
      }
      if (existingCredit.exists) {
        throw StateError('Un crédit existe déjà pour cette commande.');
      }

      final Map<String, dynamic> order = orderSnapshot.data()!;
      final String paymentStatus = (order['paymentStatus'] as String? ?? '')
          .trim();
      final String status = (order['status'] as String? ?? '').trim();
      if (paymentStatus == 'confirmed' || paymentStatus == 'credit') {
        throw StateError('Cette commande est déjà financée.');
      }
      if (!<String>{
        'awaitingPayment',
        'paymentToVerify',
        'expired',
      }.contains(status)) {
        throw StateError(
          'Cette commande ne peut plus être autorisée à crédit.',
        );
      }

      final int orderAmount = _int(order['amount']);
      if (draft.amount != orderAmount) {
        throw StateError(
          'Le crédit doit couvrir exactement le montant de la commande.',
        );
      }
      final String orderReference =
          (order['reference'] as String? ?? draft.orderReference).trim();
      final String clientName =
          (order['clientName'] as String? ?? draft.clientName).trim();
      final String clientPhone =
          (order['clientWhatsappPhone'] as String? ?? draft.clientWhatsappPhone)
              .trim();
      final List<String> refusedAgentIds =
          (order['autoAssignmentRefusedAgentIds'] is List)
          ? (order['autoAssignmentRefusedAgentIds'] as List)
                .whereType<String>()
                .toList(growable: false)
          : const <String>[];
      final String? lastRefusedAgentId = _nullable(
        order['lastAssignmentRefusedAgentId'] as String?,
      );

      transaction.set(creditRef, <String, dynamic>{
        'schemaVersion': 1,
        'orderId': draft.orderId,
        'orderReference': orderReference,
        'clientName': clientName,
        'clientWhatsappPhone': clientPhone,
        'amount': orderAmount,
        'paidAmount': 0,
        'status': 'open',
        'note': _nullable(draft.note),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': cleanedStaffId,
        'createdByName': cleanedStaffName,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastSettlementId': null,
        'settledAt': null,
      });

      transaction.update(orderRef, <String, dynamic>{
        'status': 'paidReady',
        'paymentStatus': 'credit',
        'updatedAt': FieldValue.serverTimestamp(),
        'lastEventId': eventRef.id,
        'lastEventType': 'CREDIT_AUTHORIZED',
        'lastEventAt': FieldValue.serverTimestamp(),
      });

      transaction.set(eventRef, <String, dynamic>{
        'schemaVersion': 1,
        'orderId': draft.orderId,
        'orderReference': orderReference,
        'type': 'CREDIT_AUTHORIZED',
        'actorId': cleanedStaffId,
        'actorRole': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
        'metadata': <String, dynamic>{'amount': orderAmount},
      });

      transaction.set(queueRef, <String, dynamic>{
        'schemaVersion': 1,
        'orderId': draft.orderId,
        'orderReference': orderReference,
        'network': order['network'],
        'amount': orderAmount,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastRefusedAgentId': lastRefusedAgentId,
        'refusedAgentIds': refusedAgentIds,
      });
    });
    return creditRef.id;
  }

  @override
  Future<String> settleCustomerCredit({
    required String creditId,
    required int amount,
    required FinancePaymentChannel channel,
    required String reference,
    required String staffId,
    required String staffName,
    String? note,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Le montant du règlement doit être positif.');
    }
    if (reference.trim().length < 3) {
      throw ArgumentError('La référence du règlement est requise.');
    }
    final DocumentReference<Map<String, dynamic>> creditRef = _credits.doc(
      creditId,
    );
    final DocumentReference<Map<String, dynamic>> settlementRef =
        _creditSettlements.doc();
    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(creditRef);
      if (!snapshot.exists || snapshot.data() == null) {
        throw StateError('Crédit client introuvable.');
      }
      final Map<String, dynamic> credit = snapshot.data()!;
      final int total = _int(credit['amount']);
      final int alreadyPaid = _int(credit['paidAmount']);
      final int outstanding = total - alreadyPaid;
      if (outstanding <= 0) {
        throw StateError('Ce crédit est déjà soldé.');
      }
      if (amount > outstanding) {
        throw StateError('Le règlement dépasse le reste à payer.');
      }
      final int nextPaid = alreadyPaid + amount;
      final bool settled = nextPaid == total;

      transaction.set(settlementRef, <String, dynamic>{
        'schemaVersion': 1,
        'creditId': creditId,
        'orderId': credit['orderId'],
        'orderReference': credit['orderReference'],
        'clientName': credit['clientName'],
        'amount': amount,
        'paymentChannel': channel.storageValue,
        'paymentReference': reference.trim(),
        'note': _nullable(note),
        'paidAt': FieldValue.serverTimestamp(),
        'createdBy': staffId,
        'createdByName': staffName.trim(),
      });
      transaction.update(creditRef, <String, dynamic>{
        'paidAmount': nextPaid,
        'status': settled ? 'settled' : 'partial',
        'updatedAt': FieldValue.serverTimestamp(),
        'lastSettlementId': settlementRef.id,
        'settledAt': settled ? FieldValue.serverTimestamp() : null,
      });
    });
    return settlementRef.id;
  }

  @override
  Future<String> recordExpense({
    required FinanceExpenseDraft draft,
    required String staffId,
    required String staffName,
  }) async {
    if (draft.amount <= 0) {
      throw ArgumentError('Le montant de la dépense doit être positif.');
    }
    if (draft.description.trim().length < 3) {
      throw ArgumentError('La description de la dépense est requise.');
    }
    if (draft.channel == FinancePaymentChannel.wave &&
        (draft.reference?.trim().length ?? 0) < 3) {
      throw ArgumentError(
        'La référence Wave est requise pour une dépense payée via Wave.',
      );
    }
    final DocumentReference<Map<String, dynamic>> ref = _expenses.doc();
    await ref.set(<String, dynamic>{
      'schemaVersion': 1,
      'category': draft.category.storageValue,
      'amount': draft.amount,
      'description': draft.description.trim(),
      'paymentChannel': draft.channel.storageValue,
      'paymentReference': _nullable(draft.reference),
      'spentAt': FieldValue.serverTimestamp(),
      'createdBy': staffId,
      'createdByName': staffName.trim(),
    });
    return ref.id;
  }

  @override
  Future<void> setWaveOpeningBalance({
    required int amount,
    required String staffId,
    required String staffName,
    String? note,
  }) async {
    if (amount < 0) {
      throw ArgumentError('Le solde Wave ne peut pas être négatif.');
    }
    final String cleanedStaffName = staffName.trim();
    if (staffId.trim().isEmpty || cleanedStaffName.length < 2) {
      throw ArgumentError('L’administrateur connecté est invalide.');
    }
    final DocumentReference<Map<String, dynamic>> settingRef = _settings.doc(
      'wave',
    );
    final DocumentReference<Map<String, dynamic>> adjustmentRef =
        _waveAdjustments.doc();
    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> current = await transaction
          .get(settingRef);
      final int previous = _int(current.data()?['openingBalance']);
      transaction.set(adjustmentRef, <String, dynamic>{
        'schemaVersion': 1,
        'previousOpeningBalance': previous,
        'openingBalance': amount,
        'effectiveAt': FieldValue.serverTimestamp(),
        'note': _nullable(note),
        'createdBy': staffId,
        'createdByName': cleanedStaffName,
      });
      transaction.set(settingRef, <String, dynamic>{
        'schemaVersion': 1,
        'openingBalance': amount,
        'effectiveAt': FieldValue.serverTimestamp(),
        'note': _nullable(note),
        'lastAdjustmentId': adjustmentRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': staffId,
        'updatedByName': cleanedStaffName,
      });
    });
  }

  @override
  Future<void> createDailyClosing({
    required DailyFinancialClosingDraft draft,
    required String staffId,
    required String staffName,
  }) async {
    final DocumentReference<Map<String, dynamic>> ref = _dailyClosings.doc(
      draft.dateKey,
    );
    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> existing = await transaction
          .get(ref);
      if (existing.exists) {
        throw StateError('Cette journée a déjà été clôturée.');
      }
      transaction.set(ref, <String, dynamic>{
        'schemaVersion': 1,
        'dateKey': draft.dateKey,
        'clientReceipts': draft.clientReceipts,
        'successfulOrdersCount': draft.successfulOrdersCount,
        'successfulOrdersAmount': draft.successfulOrdersAmount,
        'supplierRechargePrincipal': draft.supplierRechargePrincipal,
        'supplierRechargeBonus': draft.supplierRechargeBonus,
        'supplierRechargeReceived': draft.supplierRechargeReceived,
        'supplierPayments': draft.supplierPayments,
        'creditsCreated': draft.creditsCreated,
        'creditSettlements': draft.creditSettlements,
        'customerReceivables': draft.customerReceivables,
        'expenses': draft.expenses,
        'refunds': draft.refunds,
        'commissionsEarned': draft.commissionsEarned,
        'commissionsPaid': draft.commissionsPaid,
        'orangeAvailable': draft.orangeAvailable,
        'orangeCommitted': draft.orangeCommitted,
        'mtnAvailable': draft.mtnAvailable,
        'mtnCommitted': draft.mtnCommitted,
        'moovAvailable': draft.moovAvailable,
        'moovCommitted': draft.moovCommitted,
        'supplierDebt': draft.supplierDebt,
        'commissionDebt': draft.commissionDebt,
        'waveTheoreticalBalance': draft.waveTheoreticalBalance,
        'waveActualBalance': draft.waveActualBalance,
        'waveDifference': draft.waveDifference,
        'waveDifferenceNote': _nullable(draft.waveDifferenceNote),
        'estimatedProfit': draft.estimatedProfit,
        'closedAt': FieldValue.serverTimestamp(),
        'closedBy': staffId,
        'closedByName': staffName.trim(),
      });
    });
  }

  FinanceSupplier? _supplierFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    final DateTime? createdAt = _date(data['createdAt']);
    final DateTime? updatedAt = _date(data['updatedAt']);
    final String name = _string(data['name']);
    if (createdAt == null || updatedAt == null || name.isEmpty) {
      return null;
    }
    return FinanceSupplier(
      id: doc.id,
      name: name,
      phoneNumber: _string(data['phoneNumber']),
      isActive: data['isActive'] == true,
      note: _nullableString(data['note']),
      createdAt: createdAt,
      createdBy: _string(data['createdBy']),
      createdByName: _string(data['createdByName']),
      updatedAt: updatedAt,
    );
  }

  SupplierAccount? _supplierAccountFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    final DateTime? createdAt = _date(data['createdAt']);
    final DateTime? updatedAt = _date(data['updatedAt']);
    if (createdAt == null || updatedAt == null) {
      return null;
    }
    return SupplierAccount(
      supplierId: _string(data['supplierId']),
      supplierName: _string(data['supplierName']),
      totalOwed: _int(data['totalOwed']),
      totalPaid: _int(data['totalPaid']),
      totalRecharged: _int(data['totalRecharged']),
      rechargeCount: _int(data['rechargeCount']),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  SupplierRecharge? _supplierRechargeFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    final AgentNetwork? network = _network(data['network']);
    final DateTime? createdAt = _date(data['createdAt']);
    if (network == null || createdAt == null) {
      return null;
    }
    return SupplierRecharge(
      id: doc.id,
      supplierId: _string(data['supplierId']),
      supplierName: _string(data['supplierName']),
      agentId: _string(data['agentId']),
      agentName: _string(data['agentName']),
      network: network,
      principalAmount: _int(data['principalAmount']),
      bonusAmount: _int(data['bonusAmount']),
      receivedAmount: _int(data['receivedAmount']),
      amountOwed: _int(data['amountOwed']),
      capacityBefore: _int(data['capacityBefore']),
      capacityAfter: _int(data['capacityAfter']),
      note: _nullableString(data['note']),
      createdAt: createdAt,
      createdBy: _string(data['createdBy']),
      createdByName: _string(data['createdByName']),
    );
  }

  SupplierPayment? _supplierPaymentFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    final DateTime? paidAt = _date(data['paidAt']);
    if (paidAt == null) {
      return null;
    }
    return SupplierPayment(
      id: doc.id,
      supplierId: _string(data['supplierId']),
      supplierName: _string(data['supplierName']),
      amount: _int(data['amount']),
      channel: FinancePaymentChannelX.fromStorage(
        _string(data['paymentChannel']),
      ),
      reference: _string(data['paymentReference']),
      note: _nullableString(data['note']),
      paidAt: paidAt,
      createdBy: _string(data['createdBy']),
      createdByName: _string(data['createdByName']),
    );
  }

  CustomerCredit? _customerCreditFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    final DateTime? createdAt = _date(data['createdAt']);
    final DateTime? updatedAt = _date(data['updatedAt']);
    if (createdAt == null || updatedAt == null) {
      return null;
    }
    return CustomerCredit(
      id: doc.id,
      orderId: _string(data['orderId']),
      orderReference: _string(data['orderReference']),
      clientName: _string(data['clientName']),
      clientWhatsappPhone: _string(data['clientWhatsappPhone']),
      amount: _int(data['amount']),
      paidAmount: _int(data['paidAmount']),
      status: CustomerCreditStatusX.fromStorage(_string(data['status'])),
      note: _nullableString(data['note']),
      createdAt: createdAt,
      createdBy: _string(data['createdBy']),
      createdByName: _string(data['createdByName']),
      updatedAt: updatedAt,
      settledAt: _date(data['settledAt']),
    );
  }

  CustomerCreditSettlement? _creditSettlementFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    final DateTime? paidAt = _date(data['paidAt']);
    if (paidAt == null) {
      return null;
    }
    return CustomerCreditSettlement(
      id: doc.id,
      creditId: _string(data['creditId']),
      orderId: _string(data['orderId']),
      orderReference: _string(data['orderReference']),
      clientName: _string(data['clientName']),
      amount: _int(data['amount']),
      channel: FinancePaymentChannelX.fromStorage(
        _string(data['paymentChannel']),
      ),
      reference: _string(data['paymentReference']),
      note: _nullableString(data['note']),
      paidAt: paidAt,
      createdBy: _string(data['createdBy']),
      createdByName: _string(data['createdByName']),
    );
  }

  FinanceExpense? _expenseFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    final DateTime? spentAt = _date(data['spentAt']);
    if (spentAt == null) {
      return null;
    }
    return FinanceExpense(
      id: doc.id,
      category: FinanceExpenseCategoryX.fromStorage(_string(data['category'])),
      amount: _int(data['amount']),
      description: _string(data['description']),
      channel: FinancePaymentChannelX.fromStorage(
        _string(data['paymentChannel']),
      ),
      reference: _nullableString(data['paymentReference']),
      spentAt: spentAt,
      createdBy: _string(data['createdBy']),
      createdByName: _string(data['createdByName']),
    );
  }

  WaveBalanceAdjustment? _waveAdjustmentFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    final DateTime? effectiveAt = _date(data['effectiveAt']);
    if (effectiveAt == null) {
      return null;
    }
    return WaveBalanceAdjustment(
      id: doc.id,
      previousOpeningBalance: _int(data['previousOpeningBalance']),
      openingBalance: _int(data['openingBalance']),
      effectiveAt: effectiveAt,
      note: _nullableString(data['note']),
      createdBy: _string(data['createdBy']),
      createdByName: _string(data['createdByName']),
    );
  }

  WaveOpeningBalance? _waveOpeningFromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    final Map<String, dynamic> data = doc.data()!;
    final DateTime? effectiveAt = _date(data['effectiveAt']);
    final DateTime? updatedAt = _date(data['updatedAt']);
    if (effectiveAt == null || updatedAt == null) {
      return null;
    }
    return WaveOpeningBalance(
      amount: _int(data['openingBalance']),
      effectiveAt: effectiveAt,
      note: _nullableString(data['note']),
      updatedAt: updatedAt,
      updatedBy: _string(data['updatedBy']),
      updatedByName: _string(data['updatedByName']),
    );
  }

  DailyFinancialClosing? _dailyClosingFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    final DateTime? closedAt = _date(data['closedAt']);
    if (closedAt == null) {
      return null;
    }
    return DailyFinancialClosing(
      id: doc.id,
      dateKey: _string(data['dateKey']),
      clientReceipts: _int(data['clientReceipts']),
      successfulOrdersCount: _int(data['successfulOrdersCount']),
      successfulOrdersAmount: _int(data['successfulOrdersAmount']),
      supplierRechargePrincipal: _int(data['supplierRechargePrincipal']),
      supplierRechargeBonus: _int(data['supplierRechargeBonus']),
      supplierRechargeReceived: _int(data['supplierRechargeReceived']),
      supplierPayments: _int(data['supplierPayments']),
      creditsCreated: _int(data['creditsCreated']),
      creditSettlements: _int(data['creditSettlements']),
      customerReceivables: _int(data['customerReceivables']),
      expenses: _int(data['expenses']),
      refunds: _int(data['refunds']),
      commissionsEarned: _int(data['commissionsEarned']),
      commissionsPaid: _int(data['commissionsPaid']),
      orangeAvailable: _int(data['orangeAvailable']),
      orangeCommitted: _int(data['orangeCommitted']),
      mtnAvailable: _int(data['mtnAvailable']),
      mtnCommitted: _int(data['mtnCommitted']),
      moovAvailable: _int(data['moovAvailable']),
      moovCommitted: _int(data['moovCommitted']),
      supplierDebt: _int(data['supplierDebt']),
      commissionDebt: _int(data['commissionDebt']),
      waveTheoreticalBalance: _int(data['waveTheoreticalBalance']),
      waveActualBalance: _int(data['waveActualBalance']),
      waveDifference: _int(data['waveDifference']),
      estimatedProfit: _int(data['estimatedProfit']),
      waveDifferenceNote: _nullableString(data['waveDifferenceNote']),
      closedAt: closedAt,
      closedBy: _string(data['closedBy']),
      closedByName: _string(data['closedByName']),
    );
  }

  String _movementMarkerField(AgentNetwork network) {
    switch (network) {
      case AgentNetwork.orange:
        return 'lastOrangeMovementId';
      case AgentNetwork.mtn:
        return 'lastMtnMovementId';
      case AgentNetwork.moov:
        return 'lastMoovMovementId';
    }
  }

  String _capacityField(AgentNetwork network) {
    switch (network) {
      case AgentNetwork.orange:
        return 'orangeCapacity';
      case AgentNetwork.mtn:
        return 'mtnCapacity';
      case AgentNetwork.moov:
        return 'moovCapacity';
    }
  }

  AgentNetwork? _network(Object? value) {
    if (value is! String) {
      return null;
    }
    for (final AgentNetwork item in AgentNetwork.values) {
      if (item.firestoreValue == value) {
        return item;
      }
    }
    return null;
  }

  int _int(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return 0;
  }

  String _string(Object? value) => value is String ? value.trim() : '';

  String? _nullableString(Object? value) {
    final String text = _string(value);
    return text.isEmpty ? null : text;
  }

  String? _nullable(String? value) {
    final String cleaned = value?.trim() ?? '';
    return cleaned.isEmpty ? null : cleaned;
  }

  DateTime? _date(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}
