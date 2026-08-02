// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import 'package:cabine_flow/features/customer_order/domain/models/customer_order_session.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_order_session_store.dart';

class BrowserCustomerOrderSessionStore implements CustomerOrderSessionStore {
  static const String _storageKey = 'cabineflow.lastCustomerOrder';

  @override
  Future<void> clear() async {
    html.window.localStorage.remove(_storageKey);
  }

  @override
  Future<CustomerOrderSession?> read() async {
    final String? rawValue = html.window.localStorage[_storageKey];

    if (rawValue == null || rawValue.trim().isEmpty) {
      return null;
    }

    try {
      final Object? decoded = jsonDecode(rawValue);

      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      return CustomerOrderSession.fromMap(decoded);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> save(CustomerOrderSession session) async {
    html.window.localStorage[_storageKey] = jsonEncode(session.toMap());
  }
}
