import 'dart:async';

import 'package:cabine_flow/features/messaging/domain/models/customer_conversation.dart';
import 'package:cabine_flow/features/messaging/domain/repositories/customer_messaging_repository.dart';

class FakeCustomerMessagingRepository implements CustomerMessagingRepository {
  FakeCustomerMessagingRepository({
    this.customerUid = 'customer-test-uid',
    this.managerUid = 'manager-test-uid',
    this.managerName = 'Manager IzyTel',
  });

  final String customerUid;
  final String managerUid;
  final String managerName;

  final StreamController<List<CustomerConversation>> _conversationController =
      StreamController<List<CustomerConversation>>.broadcast();
  final Map<String, StreamController<List<CustomerMessage>>>
      _messageControllers = <String, StreamController<List<CustomerMessage>>>{};
  final List<CustomerConversation> _conversations = <CustomerConversation>[];
  final Map<String, List<CustomerMessage>> _messages =
      <String, List<CustomerMessage>>{};

  int _conversationSequence = 0;
  int _messageSequence = 0;

  @override
  Stream<List<CustomerConversation>> watchCustomerConversations() async* {
    yield _snapshotConversations();
    yield* _conversationController.stream;
  }

  @override
  Stream<List<CustomerConversation>> watchManagerInbox() async* {
    yield _snapshotConversations();
    yield* _conversationController.stream;
  }

  @override
  Stream<List<CustomerMessage>> watchMessages({
    required String conversationId,
  }) async* {
    yield _snapshotMessages(conversationId);
    yield* _controllerFor(conversationId).stream;
  }

  @override
  Future<CustomerConversation> createConversation({
    String? orderId,
    String? orderReference,
    required String message,
  }) async {
    final String body = _message(message);
    _conversationSequence += 1;
    final DateTime now = DateTime.now();
    final CustomerConversation conversation = CustomerConversation(
      id: 'conversation-$_conversationSequence',
      customerAuthUid: customerUid,
      orderId: _nullable(orderId),
      orderReference: _nullable(orderReference)?.toUpperCase(),
      status: CustomerConversationStatus.open,
      lastMessageAt: now,
      lastMessagePreview: body,
      lastSenderType: CustomerMessageSenderType.client,
      createdAt: now,
      updatedAt: now,
    );
    _conversations.add(conversation);
    _appendMessage(
      conversation.id,
      CustomerMessageSenderType.client,
      body,
      senderUid: customerUid,
      senderName: 'Client',
    );
    _emitConversations();
    return conversation;
  }

  @override
  Future<void> sendClientMessage({
    required String conversationId,
    required String message,
  }) async {
    final CustomerConversation current = _requireConversation(conversationId);
    if (current.isClosed) throw StateError('Conversation fermée.');
    final String body = _message(message);
    _appendMessage(
      current.id,
      CustomerMessageSenderType.client,
      body,
      senderUid: customerUid,
      senderName: 'Client',
    );
    final CustomerConversationStatus nextStatus = current.isResolved
        ? current.isAssigned
              ? CustomerConversationStatus.inProgress
              : CustomerConversationStatus.open
        : current.status;
    _replaceConversation(
      current.copyWith(
        status: nextStatus,
        lastMessageAt: DateTime.now(),
        lastMessagePreview: body,
        lastSenderType: CustomerMessageSenderType.client,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> takeConversation({required String conversationId}) async {
    final CustomerConversation current = _requireConversation(conversationId);
    if (current.isClosed) throw StateError('Conversation fermée.');
    if (current.assignedManagerUid != null &&
        current.assignedManagerUid != managerUid) {
      throw StateError('Conversation déjà attribuée.');
    }
    final DateTime now = DateTime.now();
    const String systemBody =
        'Un Manager IzyTel a pris en charge votre conversation.';
    if (!current.isAssigned) {
      _appendMessage(
        current.id,
        CustomerMessageSenderType.system,
        systemBody,
        senderName: 'IzyTel',
        isSystem: true,
      );
    }
    _replaceConversation(
      CustomerConversation(
        id: current.id,
        customerAuthUid: current.customerAuthUid,
        orderId: current.orderId,
        orderReference: current.orderReference,
        status: CustomerConversationStatus.inProgress,
        assignedManagerUid: managerUid,
        assignedManagerName: managerName,
        lastMessageAt: now,
        lastMessagePreview: current.isAssigned
            ? current.lastMessagePreview
            : systemBody,
        lastSenderType: current.isAssigned
            ? current.lastSenderType
            : CustomerMessageSenderType.system,
        createdAt: current.createdAt,
        updatedAt: now,
      ),
    );
  }

  @override
  Future<void> sendManagerMessage({
    required String conversationId,
    required String message,
  }) async {
    final CustomerConversation current = _requireConversation(conversationId);
    if (current.assignedManagerUid != managerUid || current.isClosed) {
      throw StateError('Conversation non attribuée au Manager.');
    }
    final String body = _message(message);
    _appendMessage(
      current.id,
      CustomerMessageSenderType.manager,
      body,
      senderUid: managerUid,
      senderName: managerName,
    );
    _replaceConversation(
      current.copyWith(
        status: CustomerConversationStatus.inProgress,
        lastMessageAt: DateTime.now(),
        lastMessagePreview: body,
        lastSenderType: CustomerMessageSenderType.manager,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> resolveConversation({required String conversationId}) async {
    final CustomerConversation current = _requireConversation(conversationId);
    if (current.assignedManagerUid != managerUid ||
        current.status != CustomerConversationStatus.inProgress) {
      throw StateError('Conversation non attribuée au Manager.');
    }
    const String systemBody =
        'La conversation a été marquée comme résolue. Vous pouvez répondre pour la rouvrir si nécessaire.';
    _appendMessage(
      current.id,
      CustomerMessageSenderType.system,
      systemBody,
      senderName: 'IzyTel',
      isSystem: true,
    );
    _replaceConversation(
      current.copyWith(
        status: CustomerConversationStatus.resolved,
        lastMessageAt: DateTime.now(),
        lastMessagePreview: 'Conversation résolue',
        lastSenderType: CustomerMessageSenderType.system,
        updatedAt: DateTime.now(),
      ),
    );
  }

  void dispose() {
    _conversationController.close();
    for (final StreamController<List<CustomerMessage>> controller
        in _messageControllers.values) {
      controller.close();
    }
  }

  CustomerConversation _requireConversation(String id) {
    return _conversations.firstWhere(
      (CustomerConversation item) => item.id == id.trim(),
      orElse: () => throw StateError('Conversation introuvable.'),
    );
  }

  void _replaceConversation(CustomerConversation next) {
    final int index = _conversations.indexWhere(
      (CustomerConversation item) => item.id == next.id,
    );
    if (index < 0) throw StateError('Conversation introuvable.');
    _conversations[index] = next;
    _emitConversations();
  }

  void _appendMessage(
    String conversationId,
    CustomerMessageSenderType senderType,
    String body, {
    String? senderUid,
    String? senderName,
    bool isSystem = false,
  }) {
    _messageSequence += 1;
    final CustomerMessage message = CustomerMessage(
      id: 'message-$_messageSequence',
      conversationId: conversationId,
      senderType: senderType,
      senderUid: senderUid,
      senderName: senderName,
      body: body,
      isSystem: isSystem,
      createdAt: DateTime.now(),
    );
    _messages.putIfAbsent(conversationId, () => <CustomerMessage>[]).add(message);
    _controllerFor(conversationId).add(_snapshotMessages(conversationId));
  }

  void _emitConversations() {
    _conversationController.add(_snapshotConversations());
  }

  List<CustomerConversation> _snapshotConversations() {
    final List<CustomerConversation> copy = List<CustomerConversation>.from(
      _conversations,
    )..sort(
        (CustomerConversation a, CustomerConversation b) =>
            b.updatedAt.compareTo(a.updatedAt),
      );
    return List<CustomerConversation>.unmodifiable(copy);
  }

  List<CustomerMessage> _snapshotMessages(String conversationId) {
    final List<CustomerMessage> copy = List<CustomerMessage>.from(
      _messages[conversationId] ?? const <CustomerMessage>[],
    )..sort(
        (CustomerMessage a, CustomerMessage b) =>
            a.createdAt.compareTo(b.createdAt),
      );
    return List<CustomerMessage>.unmodifiable(copy);
  }

  StreamController<List<CustomerMessage>> _controllerFor(String id) {
    return _messageControllers.putIfAbsent(
      id,
      () => StreamController<List<CustomerMessage>>.broadcast(),
    );
  }

  String _message(String value) {
    final String body = value.trim();
    if (body.isEmpty || body.length > 2000) {
      throw ArgumentError('Message invalide.');
    }
    return body;
  }

  String? _nullable(String? value) {
    final String text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
