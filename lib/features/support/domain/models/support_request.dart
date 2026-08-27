enum SupportRequestType {
  paymentNotRecognized,
  completedButNotReceived,
  wrongAmount,
  wrongNumber,
  transactionFailed,
  other,
}

extension SupportRequestTypeX on SupportRequestType {
  String get storageValue {
    switch (this) {
      case SupportRequestType.paymentNotRecognized:
        return 'paymentNotRecognized';
      case SupportRequestType.completedButNotReceived:
        return 'completedButNotReceived';
      case SupportRequestType.wrongAmount:
        return 'wrongAmount';
      case SupportRequestType.wrongNumber:
        return 'wrongNumber';
      case SupportRequestType.transactionFailed:
        return 'transactionFailed';
      case SupportRequestType.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case SupportRequestType.paymentNotRecognized:
        return 'Paiement effectué mais non reconnu';
      case SupportRequestType.completedButNotReceived:
        return 'Commande indiquée terminée mais rien reçu';
      case SupportRequestType.wrongAmount:
        return 'Mauvais montant';
      case SupportRequestType.wrongNumber:
        return 'Mauvais numéro';
      case SupportRequestType.transactionFailed:
        return 'Transaction échouée';
      case SupportRequestType.other:
        return 'Autre';
    }
  }

  static SupportRequestType fromStorage(String value) {
    return SupportRequestType.values.firstWhere(
      (SupportRequestType type) => type.storageValue == value,
      orElse: () => SupportRequestType.other,
    );
  }
}

enum SupportRequestStatus { newRequest, inProgress, resolved, closed }

extension SupportRequestStatusX on SupportRequestStatus {
  String get storageValue {
    switch (this) {
      case SupportRequestStatus.newRequest:
        return 'new';
      case SupportRequestStatus.inProgress:
        return 'inProgress';
      case SupportRequestStatus.resolved:
        return 'resolved';
      case SupportRequestStatus.closed:
        return 'closed';
    }
  }

  String get label {
    switch (this) {
      case SupportRequestStatus.newRequest:
        return 'Nouveau';
      case SupportRequestStatus.inProgress:
        return 'En cours';
      case SupportRequestStatus.resolved:
        return 'Résolu';
      case SupportRequestStatus.closed:
        return 'Fermé';
    }
  }

  static SupportRequestStatus fromStorage(String value) {
    switch (value) {
      case 'inProgress':
        return SupportRequestStatus.inProgress;
      case 'resolved':
        return SupportRequestStatus.resolved;
      case 'closed':
        return SupportRequestStatus.closed;
      case 'new':
      default:
        return SupportRequestStatus.newRequest;
    }
  }
}

class SupportRequestDraft {
  const SupportRequestDraft({required this.type, required this.description});

  final SupportRequestType type;
  final String description;
}

class SupportRequest {
  const SupportRequest({
    required this.id,
    required this.orderId,
    required this.orderReference,
    required this.customerAuthUid,
    required this.type,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.assignedTo,
    this.resolvedAt,
  });

  final String id;
  final String orderId;
  final String orderReference;
  final String customerAuthUid;
  final SupportRequestType type;
  final String description;
  final SupportRequestStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? assignedTo;
  final DateTime? resolvedAt;
}
