import 'package:databasehelper/main.dart';
import 'package:databasehelper/models/my_transaction.dart';
import 'package:databasehelper/providers/transaction_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// UI tests use a fake; provider tests exercise real SQLite separately.
class FakeTransactionProvider extends TransactionProvider {
  FakeTransactionProvider() : super(factory: databaseFactoryFfi);

  final items = <MyTransaction>[];
  bool failSave = false;
  int _nextId = 1;

  @override
  Future<void> fetchAndSetTransactions() async {}

  @override
  List<MyTransaction> get transactions => List.unmodifiable(items);

  @override
  double get balance => items.fold(
    0,
    (sum, item) =>
        sum +
        (item.type == TransactionType.income ? item.amount : -item.amount),
  );

  @override
  Future<void> addTransaction(
    String title,
    double amount,
    DateTime date,
    TransactionType type, {
    String note = '',
  }) async {
    if (failSave) throw StateError('Simulated database failure');
    items.add(
      MyTransaction(
        id: _nextId++,
        title: title,
        amount: amount,
        date: date,
        type: type,
        note: note,
      ),
    );
    notifyListeners();
  }

  @override
  Future<void> deleteTransaction(int id) async {
    items.removeWhere((item) => item.id == id);
    notifyListeners();
  }
}

void main() {
  late FakeTransactionProvider provider;

  setUp(() => provider = FakeTransactionProvider());
  tearDown(() => provider.dispose());

  Future<void> openApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<TransactionProvider>.value(
        value: provider,
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('plus adds the exercise sample directly without opening a form', (
    tester,
  ) async {
    await openApp(tester);
    expect(find.text('ไม่มีรายการ'), findsOneWidget);
    final before = DateTime.now();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    final item = provider.items.single;
    expect(item.title, 'ค่าอาหาร');
    expect(item.amount, 120.0);
    expect(item.type, TransactionType.expense);
    expect(item.date.isBefore(before), isFalse);
    expect(item.date.isAfter(DateTime.now()), isFalse);
    expect(find.text('-120.00 บาท'), findsNWidgets(2));
    expect(find.byType(TextFormField), findsNothing);
    expect(tester.widget<ListTile>(find.byType(ListTile)).onTap, isNull);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(provider.items, hasLength(2));
    expect(find.text('ค่าอาหาร'), findsNWidgets(2));
    expect(find.text('-240.00 บาท'), findsOneWidget);
  });

  testWidgets('cancel keeps the row and confirmed delete removes it', (
    tester,
  ) async {
    await openApp(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
    expect(provider.items, hasLength(1));
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ลบ'));
    await tester.pumpAndSettle();
    expect(provider.items, isEmpty);
    expect(find.text('ไม่มีรายการ'), findsOneWidget);
    expect(find.text('0.00 บาท'), findsOneWidget);
  });

  testWidgets('failed insert shows an error and allows retry', (tester) async {
    provider.failSave = true;
    await openApp(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('เพิ่มรายการไม่สำเร็จ กรุณาลองใหม่'), findsOneWidget);
    expect(provider.items, isEmpty);
    provider.failSave = false;
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(provider.items, hasLength(1));
    expect(find.text('ค่าอาหาร'), findsOneWidget);
  });
}
