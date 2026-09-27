// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

class CustomerWebHistoryEntry {
  const CustomerWebHistoryEntry({
    required this.location,
    required this.step,
  });

  final String location;
  final int step;

  bool matches(CustomerWebHistoryEntry other) {
    return location == other.location && step == other.step;
  }
}

typedef CustomerWebHistoryPopCallback = void Function(
  CustomerWebHistoryEntry? entry,
);

class CustomerWebHistoryController {
  CustomerWebHistoryController({required this.onPop}) {
    _subscription = html.window.onPopState.listen(_handlePopState);
  }

  static const String _marker = 'izytel_customer_web';

  final CustomerWebHistoryPopCallback onPop;
  StreamSubscription<html.PopStateEvent>? _subscription;

  bool get supported => true;

  Map<String, Object> _encode(CustomerWebHistoryEntry entry) {
    return <String, Object>{
      'app': _marker,
      'location': entry.location,
      'step': entry.step,
    };
  }

  void replace(CustomerWebHistoryEntry entry) {
    html.window.history.replaceState(
      _encode(entry),
      '',
      html.window.location.href,
    );
  }

  void push(CustomerWebHistoryEntry entry) {
    html.window.history.pushState(
      _encode(entry),
      '',
      html.window.location.href,
    );
  }

  void back() {
    html.window.history.back();
  }

  void _handlePopState(html.PopStateEvent event) {
    final dynamic raw = event.state;
    if (raw is! Map) {
      onPop(null);
      return;
    }

    if (raw['app'] != _marker) {
      onPop(null);
      return;
    }

    final Object? rawLocation = raw['location'];
    final Object? rawStep = raw['step'];
    if (rawLocation is! String || rawStep is! num) {
      onPop(null);
      return;
    }

    onPop(
      CustomerWebHistoryEntry(
        location: rawLocation,
        step: rawStep.toInt(),
      ),
    );
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

CustomerWebHistoryController createCustomerWebHistory({
  required CustomerWebHistoryPopCallback onPop,
}) {
  return CustomerWebHistoryController(onPop: onPop);
}
