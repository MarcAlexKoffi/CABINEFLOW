enum CustomerConversationStatus { open, inProgress, resolved, closed }

extension CustomerConversationStatusX on CustomerConversationStatus {
  String get storageValue => name;

  String get label {
    switch (this) {
      case CustomerConversationStatus.open:
        return 'Nouvelle';
      case CustomerConversationStatus.inProgress:
        return 'En cours';
      case CustomerConversationStatus.resolved:
        return 'Résolue';
      case CustomerConversationStatus.closed:
        return 'Fermée';
    }
  }

  static CustomerConversationStatus fromStorage(Object? value) {
    final String token = value?.toString().trim() ?? '';
    return CustomerConversationStatus.values.firstWhere(
      (CustomerConversationStatus status) => status.name == token,
      orElse: () => CustomerConversationStatus.open,
    );
  }
}

enum CustomerMessageSenderType { client, manager, system }

extension CustomerMessageSenderTypeX on CustomerMessageSenderType {
  String get storageValue => name;

  static CustomerMessageSenderType fromStorage(Object? value) {
    final String token = value?.toString().trim() ?? '';
    return CustomerMessageSenderType.values.firstWhere(
      (CustomerMessageSenderType type) => type.name == token,
      orElse: () => CustomerMessageSenderType.system,
    );
  }
}

class CustomerConversation {
  const CustomerConversation({
    required this.id,
    required this.customerAuthUid,
    required this.status,
    required this.lastMessageAt,
    required this.lastMessagePreview,
    required this.lastSenderType,
    required this.createdAt,
    required this.updatedAt,
    this.orderId,
    this.orderReference,
    this.customerName = 'Client',
    this.zoneId,
    this.assignedManagerUid,
    this.assignedManagerName,
  });

  final String id;
  final String customerAuthUid;
  final String? orderId;
  final String? orderReference;
  final String customerName;
  final String? zoneId;
  final CustomerConversationStatus status;
  final String? assignedManagerUid;
  final String? assignedManagerName;
  final DateTime lastMessageAt;
  final String lastMessagePreview;
  final CustomerMessageSenderType lastSenderType;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isOrderLinked => orderId != null && orderReference != null;
  bool get isAssigned => assignedManagerUid != null;
  bool get isResolved => status == CustomerConversationStatus.resolved;
  bool get isClosed => status == CustomerConversationStatus.closed;

  CustomerConversation copyWith({
    CustomerConversationStatus? status,
    String? assignedManagerUid,
    String? assignedManagerName,
    DateTime? lastMessageAt,
    String? lastMessagePreview,
    CustomerMessageSenderType? lastSenderType,
    DateTime? updatedAt,
  }) {
    return CustomerConversation(
      id: id,
      customerAuthUid: customerAuthUid,
      orderId: orderId,
      orderReference: orderReference,
      customerName: customerName,
      zoneId: zoneId,
      status: status ?? this.status,
      assignedManagerUid: assignedManagerUid ?? this.assignedManagerUid,
      assignedManagerName: assignedManagerName ?? this.assignedManagerName,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastSenderType: lastSenderType ?? this.lastSenderType,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CustomerMessage {
  const CustomerMessage({
    required this.id,
    required this.conversationId,
    required this.senderType,
    required this.body,
    required this.createdAt,
    this.senderUid,
    this.senderName,
    this.isSystem = false,
  });

  final String id;
  final String conversationId;
  final CustomerMessageSenderType senderType;
  final String? senderUid;
  final String? senderName;
  final String body;
  final bool isSystem;
  final DateTime createdAt;

  bool get isFromClient => senderType == CustomerMessageSenderType.client;
  bool get isFromManager => senderType == CustomerMessageSenderType.manager;
}
