import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ekrili_karhba/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('opens the maintenance dashboard', (tester) async {
    await tester.pumpWidget(const EkriliKarhbaApp());

    expect(find.text('Maintenance'), findsWidgets);
    expect(find.text('Maintenance urgente'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle maintenance'), findsOneWidget);
  });
}
