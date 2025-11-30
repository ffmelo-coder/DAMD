import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lista_compras_simples/main.dart';

void main() {
  
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('Task Manager app loads correctly', (WidgetTester tester) async {
    
    await tester.pumpWidget(const MyApp());
    await tester.pump(); 

    
    expect(find.text('Minhas Tarefas'), findsOneWidget);

    
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('UI elements are present', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
