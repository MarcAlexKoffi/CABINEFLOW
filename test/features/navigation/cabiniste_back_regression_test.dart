import 'package:cabine_flow/core/theme/app_theme.dart';
import 'package:cabine_flow/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/partners/data/repositories/supabase_partner_order_repository.dart';
import 'package:cabine_flow/features/partners/domain/models/partner_order_models.dart';
import 'package:cabine_flow/features/partners/presentation/pages/partner_shell_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await Supabase.initialize(
      url: 'http://127.0.0.1:1',
      publishableKey: 'test-public-key',
      accessToken: () async => null,
      debug: false,
      authOptions: FlutterAuthClientOptions(
        persistSession: false,
        pkceAsyncStorage: _MemoryStorage(),
      ),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  testWidgets('Cabiniste conserve ses piles et ne sort que depuis Accueil', (
    tester,
  ) async {
    // Isolated local client: no production endpoint or authenticated identity.
    var exits = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemNavigator.pop') exits++;
        return null;
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PartnerShellPage(
          user: const AppUser(
            id: 'cabiniste-test',
            name: 'Test',
            phoneNumber: '',
            role: UserRole.cabiniste,
          ),
          authRepository: FakeAuthRepository(),
          repository: _Partner(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Tab taps and detail navigation use the production Cabiniste shell.
    await tester.tap(find.text('Commandes').last);
    await tester.pumpAndSettle();
    final orders = tester.state<NavigatorState>(find.byType(Navigator).at(1));
    orders.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('detail cabiniste')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Historique').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Commandes').last);
    await tester.pumpAndSettle();
    expect(find.text('detail cabiniste'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('detail cabiniste'), findsNothing);
    expect(exits, 0);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(exits, 0);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(exits, 0);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(exits, 1);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });
}

class _Partner extends SupabasePartnerOrderRepository {
  _Partner() : super(firebaseAuth: _Auth());
  @override
  Future<PartnerAccountSnapshot?> fetchOwnAccount() async => null;
  @override
  Future<List<PartnerOrderSnapshot>> fetchAssignedOrders() async => [];
  @override
  Future<PartnerFinanceSnapshot> fetchFinanceSnapshot() async =>
      const PartnerFinanceSnapshot(
        partnerId: 'partner-test',
        partnerCode: 'test',
        displayName: 'Test',
        status: 'active',
        earnedTotal: 0,
        paidTotal: 0,
        balanceDue: 0,
        earnedTransactions: 0,
        payouts: [],
      );
  @override
  Future<List<PartnerAssignmentHistoryItem>> fetchOwnAssignmentHistory({
    int limit = 100,
  }) async => [];
}

class _Auth implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemoryStorage extends GotrueAsyncStorage {
  @override
  Future<String?> getItem({required String key}) async => null;
  @override
  Future<void> removeItem({required String key}) async {}
  @override
  Future<void> setItem({required String key, required String value}) async {}
}
