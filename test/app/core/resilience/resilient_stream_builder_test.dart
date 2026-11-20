import 'dart:async';
import 'package:cabine_flow/app/shared/widgets/resilient_stream_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('showing the warning preserves nested stream subscriptions', (
    tester,
  ) async {
    final outer = StreamController<int>.broadcast(sync: true);
    var listens = 0;
    final inner = StreamController<int>.broadcast(
      sync: true,
      onListen: () => listens++,
    );
    final innerStream = inner.stream;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResilientStreamBuilder<int>(
            stream: outer.stream,
            builder: (_, snapshot) => ResilientStreamBuilder<int>(
              stream: innerStream,
              builder: (_, other) => Text('${snapshot.data}/${other.data}'),
            ),
          ),
        ),
      ),
    );
    outer.add(4);
    inner.add(40);
    await tester.pumpAndSettle();
    expect(
      find.text('4/40'),
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .join(' | '),
    );
    outer.addError(TimeoutException('offline'));
    await tester.pumpAndSettle();
    expect(
      find.text('4/40'),
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .join(' | '),
    );
    expect(listens, 1);
    inner.addError(TimeoutException('offline'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Connexion interrompue'), findsOneWidget);
    expect(find.text('4/40'), findsOneWidget);
    inner.add(40);
    await tester.pumpAndSettle();
    outer.add(4);
    await tester.pumpAndSettle();
    expect(find.text('4/40'), findsOneWidget);
    expect(listens, 1);
    await tester.pumpWidget(const SizedBox());
    await outer.close();
    await inner.close();
  });
  testWidgets(
    'temporary failure retains data, recovery clears warning, denial clears data',
    (tester) async {
      final events = StreamController<int>.broadcast(sync: true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResilientStreamBuilder<int>(
              stream: events.stream,
              builder: (_, snapshot) => Text(
                snapshot.hasError
                    ? 'Accès refusé'
                    : 'Total ${snapshot.data ?? "…"}',
              ),
            ),
          ),
        ),
      );
      events.add(40);
      await tester.pumpAndSettle();
      expect(find.text('Total 40'), findsOneWidget);
      events.addError(TimeoutException('network'));
      await tester.pumpAndSettle();
      expect(find.text('Total 40'), findsOneWidget);
      expect(find.textContaining('Connexion interrompue'), findsOneWidget);
      events.add(40);
      await tester.pumpAndSettle();
      expect(find.textContaining('Connexion interrompue'), findsNothing);
      events.addError(
        const PostgrestException(message: 'denied', code: '42501'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Total 40'), findsNothing);
      expect(find.text('Accès refusé'), findsOneWidget);
      events.addError(TimeoutException('network'));
      await tester.pumpAndSettle();
      expect(find.text('Total 40'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await events.close();
    },
  );

  testWidgets('another identity never inherits the previous successful value', (
    tester,
  ) async {
    final first = StreamController<int>.broadcast(sync: true);
    final second = StreamController<int>.broadcast(sync: true);
    Widget page(Stream<int> stream) => MaterialApp(
      home: Scaffold(
        body: ResilientStreamBuilder<int>(
          stream: stream,
          builder: (_, snapshot) => Text('${snapshot.data ?? "chargement"}'),
        ),
      ),
    );
    await tester.pumpWidget(page(first.stream));
    first.add(40);
    await tester.pumpAndSettle();
    await tester.pumpWidget(page(second.stream));
    await tester.pumpAndSettle();
    expect(find.text('40'), findsNothing);
    second.addError(TimeoutException('offline'));
    await tester.pumpAndSettle();
    expect(find.text('40'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await first.close();
    await second.close();
  });
}
