// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lista_compras_simples/main.dart';

void main() {
  testWidgets('Shopping list app loads correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ListaComprasApp());

    // Verify that the app loads with the correct title
    expect(find.text('Lista de Compras'), findsOneWidget);
    
    // Verify that the empty state message is shown
    expect(find.text('Sua lista está vazia!'), findsOneWidget);
    expect(find.text('Adicione itens para começar suas compras'), findsOneWidget);

    // Verify that the floating action button is present
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Adicionar'), findsOneWidget);
  });

  testWidgets('Add item to shopping list', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ListaComprasApp());

    // Tap the floating action button to open dialog
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Verify dialog opened
    expect(find.text('Adicionar Item'), findsOneWidget);
    
    // Enter text in the text field
    await tester.enterText(find.byType(TextFormField).first, 'Leite');
    
    // Tap the add button in dialog
    await tester.tap(find.text('Adicionar').last);
    await tester.pumpAndSettle();

    // Verify that the item was added to the list
    expect(find.text('Leite'), findsOneWidget);
  });

  testWidgets('Mark item as purchased', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ListaComprasApp());

    // Add an item first
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    
    await tester.enterText(find.byType(TextFormField).first, 'Pão');
    await tester.tap(find.text('Adicionar').last);
    await tester.pumpAndSettle();

    // Find and tap the checkbox
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    // Verify that the checkbox is checked
    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, true);
  });

  testWidgets('Statistics update correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ListaComprasApp());

    // Initially should show 0 items
    expect(find.text('0'), findsWidgets);

    // Add an item
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    
    await tester.enterText(find.byType(TextFormField).first, 'Açúcar');
    await tester.tap(find.text('Adicionar').last);
    await tester.pumpAndSettle();

    // Should now show 1 total item and 1 remaining
    expect(find.text('1'), findsWidgets);
  });
}