import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/item_compra.dart';

class ListaComprasService {
  static const String _keyItens = 'lista_compras_itens';
  static const String _keyFiltroCategoria = 'filtro_categoria';
  static const String _keyOrdenacao = 'ordenacao';

  static Future<void> salvarItens(List<ItemCompra> itens) async {
    final prefs = await SharedPreferences.getInstance();
    final itensJson = itens.map((item) => item.toMap()).toList();
    await prefs.setString(_keyItens, json.encode(itensJson));
  }

  static Future<List<ItemCompra>> carregarItens() async {
    final prefs = await SharedPreferences.getInstance();
    final itensJson = prefs.getString(_keyItens);

    if (itensJson == null) return [];

    final List<dynamic> itensData = json.decode(itensJson);
    return itensData.map((item) => ItemCompra.fromMap(item)).toList();
  }

  static Future<void> salvarFiltroCategoria(String? categoria) async {
    final prefs = await SharedPreferences.getInstance();
    if (categoria == null) {
      await prefs.remove(_keyFiltroCategoria);
    } else {
      await prefs.setString(_keyFiltroCategoria, categoria);
    }
  }

  static Future<String?> carregarFiltroCategoria() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFiltroCategoria);
  }

  static Future<void> salvarOrdenacao(String ordenacao) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOrdenacao, ordenacao);
  }

  static Future<String> carregarOrdenacao() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyOrdenacao) ?? 'nome';
  }

  static Future<void> limparTodos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static String exportarLista(List<ItemCompra> itens) {
    final buffer = StringBuffer();
    buffer.writeln('📝 Minha Lista de Compras\n');

    final itensPorCategoria = <String, List<ItemCompra>>{};
    for (final item in itens) {
      itensPorCategoria.putIfAbsent(item.categoria, () => []).add(item);
    }

    for (final categoria in itensPorCategoria.keys) {
      final emoji =
          CategoriaItem.values
              .where((c) => c.nome == categoria)
              .firstOrNull
              ?.emoji ??
          '🛒';

      buffer.writeln('$emoji $categoria:');

      final itensCategoria = itensPorCategoria[categoria]!;
      for (final item in itensCategoria) {
        final status = item.comprado ? '✅' : '⬜';
        buffer.writeln('  $status ${item.nome}');
      }
      buffer.writeln();
    }

    final total = itens.length;
    final comprados = itens.where((item) => item.comprado).length;
    final restantes = total - comprados;

    buffer.writeln('📊 Resumo:');
    buffer.writeln('• Total: $total itens');
    buffer.writeln('• Comprados: $comprados itens');
    buffer.writeln('• Restantes: $restantes itens');

    return buffer.toString();
  }
}
