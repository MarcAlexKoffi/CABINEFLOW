import 'dart:async';

import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/features/messaging/domain/models/customer_conversation.dart';
import 'package:cabine_flow/features/messaging/domain/repositories/customer_messaging_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

class SupabaseCustomerMessagingRepository implements CustomerMessagingRepository {
  SupabaseCustomerMessagingRepository({
    SupabaseClient? client,
    FirebaseAuth? firebaseAuth,
  }) : _client = client ?? Supabase.instance.client,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  static const String conversationsTable = 'customer_conversations';
  static const String messagesTable = 'customer_messages';

  final SupabaseClient _client;
  final FirebaseAuth _firebaseAuth;

  @override
  Stream<List<CustomerConversation>> watchCustomerConversations() async* {
    final String uid = await _requireUid();
    yield await _fetchConversations(customerUid: uid);

    yield* _conversationRealtimeStream(customerUid: uid);
  }

  @override
  Stream<List<CustomerConversation>> watchManagerInbox() async* {
    yield await _fetchConversations();
    yield* _conversationRealtimeStream();
  }

  Stream<List<CustomerConversation>> _conversationRealtimeStream({
    String? customerUid,
  }) async* {
    try {
      await _syncRealtimeAuth();
      dynamic query = _client
          .from(conversationsTable)
          .stream(primaryKey: const <String>['id']);
      if (customerUid != null) {
        query = query.eq('customer_auth_uid', customerUid);
      }
      final Stream<List<Map<String, dynamic>>> rowsStream = query;
      await for (final List<Map<String, dynamic>> rows in rowsStream) {
        yield _conversationRows(rows);
      }
    } catch (error, stackTrace) {
      IzyTelLog.backendError(
        'CustomerMessaging.conversations-realtime',
        error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<List<CustomerConversation>> _fetchConversations({
    String? customerUid,
  }) async {
    dynamic query = _client.from(conversationsTable).select();
    if (customerUid != null) {
      query = query.eq('customer_auth_uid', customerUid);
    }
    final dynamic response = await query.order('updated_at', ascending: false);
    return _conversationRows(_rows(response));
  }

  @override
  Stream<List<CustomerMessage>> watchMessages({
    required String conversationId,
  }) async* {
    final String id = _requiredId(conversationId, 'conversation');
    yield await _fetchMessages(id);

    try {
      await _syncRealtimeAuth();
      final Stream<List<Map<String, dynamic>>> rowsStream = _client
          .from(messagesTable)
          .stream(primaryKey: const <String>['id'])
          .eq('conversation_id', id);
      await for (final List<Map<String, dynamic>> rows in rowsStream) {
        yield _messageRows(rows);
      }
    } catch (error, stackTrace) {
      IzyTelLog.backendError(
        'CustomerMessaging.messages-realtime',
        error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<List<CustomerMessage>> _fetchMessages(String conversationId) async {
    final dynamic response = await _client
        .from(messagesTable)
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at');
    return _messageRows(_rows(response));
  }

  @override
  Future<CustomerConversation> createConversation({
    String? orderId,
    String? orderReference,
    required String message,
  }) async {
    final String body = _message(message);
    final dynamic raw = await _client.rpc(
      'izytel_wc3_create_conversation',
      params: <String, dynamic>{
        'p_order_id': orderId?.trim() ?? '',
        'p_order_reference': orderReference?.trim().toUpperCase() ?? '',
        'p_body': body,
      },
    );
    final Map<String, dynamic>? row = _firstRow(raw);
    final CustomerConversation? conversation = row == null
        ? null
        : _conversationFromRow(row);
    if (conversation == null) {
      throw StateError('La conversation a été créée mais sa lecture a échoué.');
    }
    return conversation;
  }

  @override
  Future<void> sendClientMessage({
    required String conversationId,
    required String message,
  }) {
    return _rpcVoid(
      'izytel_wc3_send_client_message',
      <String, dynamic>{
        'p_conversation_id': _requiredId(conversationId, 'conversation'),
        'p_body': _message(message),
      },
    );
  }

  @override
  Future<void> takeConversation({required String conversationId}) {
    return _rpcVoid(
      'izytel_wc3_take_conversation',
      <String, dynamic>{
        'p_conversation_id': _requiredId(conversationId, 'conversation'),
      },
    );
  }

  @override
  Future<void> sendManagerMessage({
    required String conversationId,
    required String message,
  }) {
    return _rpcVoid(
      'izytel_wc3_send_manager_message',
      <String, dynamic>{
        'p_conversation_id': _requiredId(conversationId, 'conversation'),
        'p_body': _message(message),
      },
    );
  }

  @override
  Future<void> resolveConversation({required String conversationId}) {
    return _rpcVoid(
      'izytel_wc3_resolve_conversation',
      <String, dynamic>{
        'p_conversation_id': _requiredId(conversationId, 'conversation'),
      },
    );
  }

  Future<void> _rpcVoid(String function, Map<String, dynamic> params) async {
    await _client.rpc(function, params: params);
  }

  Future<String> _requireUid() async {
    final User? user = _firebaseAuth.currentUser ??
        await _firebaseAuth.authStateChanges().first;
    final String uid = user?.uid.trim() ?? '';
    if (uid.isEmpty) {
      throw StateError('Session client indisponible.');
    }
    return uid;
  }

  Future<void> _syncRealtimeAuth() async {
    final String? token = await _firebaseAuth.currentUser?.getIdToken();
    if (token == null || token.trim().isEmpty) return;
    await _client.realtime.setAuth(token);
  }

  List<CustomerConversation> _conversationRows(
    List<Map<String, dynamic>> rows,
  ) {
    final List<CustomerConversation> conversations = rows
        .map(_conversationFromRow)
        .whereType<CustomerConversation>()
        .toList(growable: false)
      ..sort(
        (CustomerConversation a, CustomerConversation b) =>
            b.updatedAt.compareTo(a.updatedAt),
      );
    return List<CustomerConversation>.unmodifiable(conversations);
  }

  List<CustomerMessage> _messageRows(List<Map<String, dynamic>> rows) {
    final List<CustomerMessage> messages = rows
        .map(_messageFromRow)
        .whereType<CustomerMessage>()
        .toList(growable: false)
      ..sort(
        (CustomerMessage a, CustomerMessage b) =>
            a.createdAt.compareTo(b.createdAt),
      );
    return List<CustomerMessage>.unmodifiable(messages);
  }

  CustomerConversation? _conversationFromRow(Map<String, dynamic> row) {
    final String id = _string(row['id']);
    final String customerUid = _string(row['customer_auth_uid']);
    final DateTime? lastMessageAt = _date(row['last_message_at']);
    final DateTime? createdAt = _date(row['created_at']);
    final DateTime? updatedAt = _date(row['updated_at']);
    if (id.isEmpty ||
        customerUid.isEmpty ||
        lastMessageAt == null ||
        createdAt == null ||
        updatedAt == null) {
      return null;
    }

    return CustomerConversation(
      id: id,
      customerAuthUid: customerUid,
      orderId: _nullable(row['order_id']),
      orderReference: _nullable(row['order_reference']),
      status: CustomerConversationStatusX.fromStorage(row['status']),
      assignedManagerUid: _nullable(row['assigned_manager_uid']),
      assignedManagerName: _nullable(row['assigned_manager_name']),
      lastMessageAt: lastMessageAt,
      lastMessagePreview: _string(row['last_message_preview']),
      lastSenderType: CustomerMessageSenderTypeX.fromStorage(
        row['last_sender_type'],
      ),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  CustomerMessage? _messageFromRow(Map<String, dynamic> row) {
    final String id = _string(row['id']);
    final String conversationId = _string(row['conversation_id']);
    final String body = _string(row['body']);
    final DateTime? createdAt = _date(row['created_at']);
    if (id.isEmpty ||
        conversationId.isEmpty ||
        body.isEmpty ||
        createdAt == null) {
      return null;
    }

    return CustomerMessage(
      id: id,
      conversationId: conversationId,
      senderType: CustomerMessageSenderTypeX.fromStorage(row['sender_type']),
      senderUid: _nullable(row['sender_uid']),
      senderName: _nullable(row['sender_name']),
      body: body,
      isSystem: _string(row['message_kind']) == 'system',
      createdAt: createdAt,
    );
  }

  List<Map<String, dynamic>> _rows(dynamic response) {
    if (response is! List) return const <Map<String, dynamic>>[];
    return response
        .whereType<Map>()
        .map((Map row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Map<String, dynamic>? _firstRow(dynamic response) {
    if (response is Map<String, dynamic>) return response;
    if (response is Map) return Map<String, dynamic>.from(response);
    if (response is List && response.isNotEmpty) {
      final dynamic first = response.first;
      if (first is Map<String, dynamic>) return first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    return null;
  }

  String _message(String value) {
    final String body = value.trim();
    if (body.isEmpty || body.length > 2000) {
      throw ArgumentError('Le message doit contenir entre 1 et 2000 caractères.');
    }
    return body;
  }

  String _requiredId(String value, String label) {
    final String cleaned = value.trim();
    if (cleaned.isEmpty) {
      throw ArgumentError('Identifiant $label invalide.');
    }
    return cleaned;
  }

  String _string(Object? value) => value?.toString().trim() ?? '';

  String? _nullable(Object? value) {
    final String text = _string(value);
    return text.isEmpty ? null : text;
  }

  DateTime? _date(Object? value) {
    if (value is DateTime) return value.toLocal();
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim())?.toLocal();
    }
    return null;
  }
}
