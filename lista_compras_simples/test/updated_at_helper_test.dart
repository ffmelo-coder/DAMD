import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_simples/utils/updated_at_helper.dart';

void main() {
  test('parse ISO8601 string', () {
    final iso = '2023-11-30T12:34:56.000Z';
    final dt = parseUpdatedAt(iso);
    expect(dt, isNotNull);
    expect(dt!.toUtc().year, 2023);
    expect(dt.toUtc().month, 11);
  });

  test('parse numeric milliseconds', () {
    final ms = 1701363296000; 
    final dt = parseUpdatedAt(ms);
    expect(dt, isNotNull);
    expect(dt!.toUtc().year, 2023);
    expect(dt.toUtc().month, 11);
  });

  test('parse numeric string milliseconds', () {
    final s = '1701363296000';
    final dt = parseUpdatedAt(s);
    expect(dt, isNotNull);
    expect(dt!.toUtc().day, 30);
  });
}
