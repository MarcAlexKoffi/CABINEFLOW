import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';

enum FinancePaymentChannel { wave, cash, bank, other }

extension FinancePaymentChannelX on FinancePaymentChannel {
  String get storageValue => name;

  String get label {
    switch (this) {
      case FinancePaymentChannel.wave:
        return 'Wave';
      case FinancePaymentChannel.cash:
        return 'Espèces';
      case FinancePaymentChannel.bank:
        return 'Banque';
      case FinancePaymentChannel.other:
        return 'Autre';
    }
  }

  static FinancePaymentChannel fromStorage(String value) {
    return FinancePaymentChannel.values.firstWhere(
      (FinancePaymentChannel item) => item.storageValue == value,
      orElse: () => FinancePaymentChannel.other,
    );
  }
}

class FinanceSupplier {
  const FinanceSupplier({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.isActive,
    required this.createdAt,
    required this.createdBy,
    required this.createdByName,
    required this.updatedAt,
    this.note,
  });

  final String id;
  final String name;
  final String phoneNumber;
  final bool isActive;
  final String? note;
  final DateTime createdAt;
  final String createdBy;
  final String createdByName;
  final DateTime updatedAt;
}

class SupplierAccount {
  const SupplierAccount({
    required this.supplierId,
    required this.supplierName,
    required this.totalOwed,
    required this.totalPaid,
    required this.totalRecharged,
    required this.rechargeCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String supplierId;
  final String supplierName;
  final int totalOwed;
  final int totalPaid;
  final int totalRecharged;
  final int rechargeCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get balance => totalOwed - totalPaid;
}

class SupplierRecharge {
  const SupplierRecharge({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.agentId,
    required this.agentName,
    required this.network,
    required this.principalAmount,
    required this.bonusAmount,
    required this.receivedAmount,
    required this.amountOwed,
    required this.capacityBefore,
    required this.capacityAfter,
    required this.createdAt,
    required this.createdBy,
    required this.createdByName,
    this.note,
  });

  final String id;
  final String supplierId;
  final String supplierName;
  final String agentId;
  final String agentName;
  final AgentNetwork network;
  final int principalAmount;
  final int bonusAmount;
  final int receivedAmount;
  final int amountOwed;
  final int capacityBefore;
  final int capacityAfter;
  final String? note;
  final DateTime createdAt;
  final String createdBy;
  final String createdByName;
}

class SupplierRechargeDraft {
  const SupplierRechargeDraft({
    required this.supplierId,
    required this.supplierName,
    required this.agentId,
    required this.agentName,
    required this.network,
    required this.principalAmount,
    required this.bonusAmount,
    required this.amountOwed,
    this.note,
  });

  final String supplierId;
  final String supplierName;
  final String agentId;
  final String agentName;
  final AgentNetwork network;
  final int principalAmount;
  final int bonusAmount;
  final int amountOwed;
  final String? note;

  int get receivedAmount => principalAmount + bonusAmount;
}

class SupplierPayment {
  const SupplierPayment({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.amount,
    required this.channel,
    required this.reference,
    required this.paidAt,
    required this.createdBy,
    required this.createdByName,
    this.note,
  });

  final String id;
  final String supplierId;
  final String supplierName;
  final int amount;
  final FinancePaymentChannel channel;
  final String reference;
  final String? note;
  final DateTime paidAt;
  final String createdBy;
  final String createdByName;
}

class SupplierPaymentDraft {
  const SupplierPaymentDraft({
    required this.supplierId,
    required this.supplierName,
    required this.amount,
    required this.channel,
    required this.reference,
    this.note,
  });

  final String supplierId;
  final String supplierName;
  final int amount;
  final FinancePaymentChannel channel;
  final String reference;
  final String? note;
}

enum CustomerCreditStatus { open, partial, settled }

extension CustomerCreditStatusX on CustomerCreditStatus {
  String get storageValue => name;

  String get label {
    switch (this) {
      case CustomerCreditStatus.open:
        return 'À recouvrer';
      case CustomerCreditStatus.partial:
        return 'Partiellement réglé';
      case CustomerCreditStatus.settled:
        return 'Réglé';
    }
  }

  static CustomerCreditStatus fromStorage(String value) {
    return CustomerCreditStatus.values.firstWhere(
      (CustomerCreditStatus item) => item.storageValue == value,
      orElse: () => CustomerCreditStatus.open,
    );
  }
}

class CustomerCredit {
  const CustomerCredit({
    required this.id,
    required this.orderId,
    required this.orderReference,
    required this.clientName,
    required this.clientWhatsappPhone,
    required this.amount,
    required this.paidAmount,
    required this.status,
    required this.createdAt,
    required this.createdBy,
    required this.createdByName,
    required this.updatedAt,
    this.note,
    this.settledAt,
  });

  final String id;
  final String orderId;
  final String orderReference;
  final String clientName;
  final String clientWhatsappPhone;
  final int amount;
  final int paidAmount;
  final CustomerCreditStatus status;
  final String? note;
  final DateTime createdAt;
  final String createdBy;
  final String createdByName;
  final DateTime updatedAt;
  final DateTime? settledAt;

  int get outstanding => amount - paidAmount;
}

class CustomerCreditDraft {
  const CustomerCreditDraft({
    required this.orderId,
    required this.orderReference,
    required this.clientName,
    required this.clientWhatsappPhone,
    required this.amount,
    this.note,
  });

  final String orderId;
  final String orderReference;
  final String clientName;
  final String clientWhatsappPhone;
  final int amount;
  final String? note;
}

class CustomerCreditSettlement {
  const CustomerCreditSettlement({
    required this.id,
    required this.creditId,
    required this.orderId,
    required this.orderReference,
    required this.clientName,
    required this.amount,
    required this.channel,
    required this.reference,
    required this.paidAt,
    required this.createdBy,
    required this.createdByName,
    this.note,
  });

  final String id;
  final String creditId;
  final String orderId;
  final String orderReference;
  final String clientName;
  final int amount;
  final FinancePaymentChannel channel;
  final String reference;
  final String? note;
  final DateTime paidAt;
  final String createdBy;
  final String createdByName;
}

enum FinanceExpenseCategory {
  transport,
  internet,
  electricity,
  maintenance,
  salary,
  communication,
  fees,
  marketing,
  office,
  other,
}

extension FinanceExpenseCategoryX on FinanceExpenseCategory {
  String get storageValue => name;

  String get label {
    switch (this) {
      case FinanceExpenseCategory.transport:
        return 'Transport';
      case FinanceExpenseCategory.internet:
        return 'Internet';
      case FinanceExpenseCategory.electricity:
        return 'Électricité';
      case FinanceExpenseCategory.maintenance:
        return 'Maintenance';
      case FinanceExpenseCategory.salary:
        return 'Salaire';
      case FinanceExpenseCategory.communication:
        return 'Communication';
      case FinanceExpenseCategory.fees:
        return 'Frais';
      case FinanceExpenseCategory.marketing:
        return 'Marketing';
      case FinanceExpenseCategory.office:
        return 'Fonctionnement';
      case FinanceExpenseCategory.other:
        return 'Autre';
    }
  }

  static FinanceExpenseCategory fromStorage(String value) {
    return FinanceExpenseCategory.values.firstWhere(
      (FinanceExpenseCategory item) => item.storageValue == value,
      orElse: () => FinanceExpenseCategory.other,
    );
  }
}

class FinanceExpense {
  const FinanceExpense({
    required this.id,
    required this.category,
    required this.amount,
    required this.description,
    required this.channel,
    required this.spentAt,
    required this.createdBy,
    required this.createdByName,
    this.reference,
  });

  final String id;
  final FinanceExpenseCategory category;
  final int amount;
  final String description;
  final FinancePaymentChannel channel;
  final String? reference;
  final DateTime spentAt;
  final String createdBy;
  final String createdByName;
}

class FinanceExpenseDraft {
  const FinanceExpenseDraft({
    required this.category,
    required this.amount,
    required this.description,
    required this.channel,
    this.reference,
  });

  final FinanceExpenseCategory category;
  final int amount;
  final String description;
  final FinancePaymentChannel channel;
  final String? reference;
}

class WaveBalanceAdjustment {
  const WaveBalanceAdjustment({
    required this.id,
    required this.previousOpeningBalance,
    required this.openingBalance,
    required this.effectiveAt,
    required this.createdBy,
    required this.createdByName,
    this.note,
  });

  final String id;
  final int previousOpeningBalance;
  final int openingBalance;
  final DateTime effectiveAt;
  final String? note;
  final String createdBy;
  final String createdByName;

  int get difference => openingBalance - previousOpeningBalance;
}

class WaveOpeningBalance {
  const WaveOpeningBalance({
    required this.amount,
    required this.effectiveAt,
    required this.updatedAt,
    required this.updatedBy,
    required this.updatedByName,
    this.note,
  });

  final int amount;
  final DateTime effectiveAt;
  final String? note;
  final DateTime updatedAt;
  final String updatedBy;
  final String updatedByName;
}

class DailyFinancialClosing {
  const DailyFinancialClosing({
    required this.id,
    required this.dateKey,
    required this.clientReceipts,
    required this.successfulOrdersCount,
    required this.successfulOrdersAmount,
    required this.supplierRechargePrincipal,
    required this.supplierRechargeBonus,
    required this.supplierRechargeReceived,
    required this.supplierPayments,
    required this.creditsCreated,
    required this.creditSettlements,
    required this.customerReceivables,
    required this.expenses,
    required this.refunds,
    required this.commissionsEarned,
    required this.commissionsPaid,
    required this.orangeAvailable,
    required this.orangeCommitted,
    required this.mtnAvailable,
    required this.mtnCommitted,
    required this.moovAvailable,
    required this.moovCommitted,
    required this.supplierDebt,
    required this.commissionDebt,
    required this.waveTheoreticalBalance,
    required this.waveActualBalance,
    required this.waveDifference,
    required this.estimatedProfit,
    this.waveDifferenceNote,
    required this.closedAt,
    required this.closedBy,
    required this.closedByName,
  });

  final String id;
  final String dateKey;
  final int clientReceipts;
  final int successfulOrdersCount;
  final int successfulOrdersAmount;
  final int supplierRechargePrincipal;
  final int supplierRechargeBonus;
  final int supplierRechargeReceived;
  final int supplierPayments;
  final int creditsCreated;
  final int creditSettlements;
  final int customerReceivables;
  final int expenses;
  final int refunds;
  final int commissionsEarned;
  final int commissionsPaid;
  final int orangeAvailable;
  final int orangeCommitted;
  final int mtnAvailable;
  final int mtnCommitted;
  final int moovAvailable;
  final int moovCommitted;
  final int supplierDebt;
  final int commissionDebt;
  final int waveTheoreticalBalance;
  final int waveActualBalance;
  final int waveDifference;
  final int estimatedProfit;
  final String? waveDifferenceNote;
  final DateTime closedAt;
  final String closedBy;
  final String closedByName;
}

class DailyFinancialClosingDraft {
  const DailyFinancialClosingDraft({
    required this.dateKey,
    required this.clientReceipts,
    required this.successfulOrdersCount,
    required this.successfulOrdersAmount,
    required this.supplierRechargePrincipal,
    required this.supplierRechargeBonus,
    required this.supplierRechargeReceived,
    required this.supplierPayments,
    required this.creditsCreated,
    required this.creditSettlements,
    required this.customerReceivables,
    required this.expenses,
    required this.refunds,
    required this.commissionsEarned,
    required this.commissionsPaid,
    required this.orangeAvailable,
    required this.orangeCommitted,
    required this.mtnAvailable,
    required this.mtnCommitted,
    required this.moovAvailable,
    required this.moovCommitted,
    required this.supplierDebt,
    required this.commissionDebt,
    required this.waveTheoreticalBalance,
    required this.waveActualBalance,
    required this.estimatedProfit,
    this.waveDifferenceNote,
  });

  final String dateKey;
  final int clientReceipts;
  final int successfulOrdersCount;
  final int successfulOrdersAmount;
  final int supplierRechargePrincipal;
  final int supplierRechargeBonus;
  final int supplierRechargeReceived;
  final int supplierPayments;
  final int creditsCreated;
  final int creditSettlements;
  final int customerReceivables;
  final int expenses;
  final int refunds;
  final int commissionsEarned;
  final int commissionsPaid;
  final int orangeAvailable;
  final int orangeCommitted;
  final int mtnAvailable;
  final int mtnCommitted;
  final int moovAvailable;
  final int moovCommitted;
  final int supplierDebt;
  final int commissionDebt;
  final int waveTheoreticalBalance;
  final int waveActualBalance;
  final int estimatedProfit;
  final String? waveDifferenceNote;

  int get waveDifference => waveActualBalance - waveTheoreticalBalance;
}
