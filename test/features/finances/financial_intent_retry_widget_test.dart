import 'dart:async';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/finances/data/repositories/supabase_finance_operations_repository.dart';
import 'package:cabine_flow/features/finances/domain/models/finance_operations_models.dart';
import 'package:cabine_flow/features/finances/presentation/pages/finance_expenses_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

class _LostResponseRepository extends SupabaseFinanceOperationsRepository {
  final drafts = <FinanceExpenseDraft>[];
  @override
  Stream<List<FinanceExpense>> watchExpenses() => Stream.value(const []);
  @override
  Future<String> recordExpense({
    required FinanceExpenseDraft draft,
    required String staffId,
    required String staffName,
  }) async {
    drafts.add(draft);
    if (drafts.length == 1) throw TimeoutException('Réponse perdue');
    return 'expense-once';
  }
}

void main() {
  testWidgets(
    'mobile expense retries the captured intention after a lost response',
    (tester) async {
      final repository = _LostResponseRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: FinanceExpensesPage(
            user: const AppUser(
              id: 'admin',
              name: 'Admin',
              phoneNumber: '',
              role: UserRole.administrator,
            ),
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Symbols.add_rounded).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '1500');
      await tester.enterText(find.byType(TextField).at(1), 'Transport');
      await tester.enterText(find.byType(TextField).at(2), 'WAVE-1');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(find.text('Opération non confirmée'), findsOneWidget);
      expect(repository.drafts, hasLength(1));
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(repository.drafts, hasLength(2));
      expect(identical(repository.drafts[0], repository.drafts[1]), isTrue);
      expect(find.text('Opération non confirmée'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    },
  );
}
