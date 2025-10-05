import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_simples/models/item_compra.dart';
import 'package:lista_compras_simples/services/lista_compras_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Testes de Persistência de Dados', () {
    setUp(() async {
      // Configurar SharedPreferences mock para testes
      SharedPreferences.setMockInitialValues({});
    });

    test('Deve salvar e carregar itens corretamente', () async {
      // Criar itens de teste
      final itens = [
        ItemCompra(
          id: '1',
          nome: 'Leite',
          categoria: 'Laticínios',
          comprado: false,
        ),
        ItemCompra(id: '2', nome: 'Pão', categoria: 'Padaria', comprado: true),
      ];

      // Salvar itens
      await ListaComprasService.salvarItens(itens);

      // Carregar itens
      final itensCarregados = await ListaComprasService.carregarItens();

      // Verificar se os dados foram persistidos corretamente
      expect(itensCarregados.length, 2);
      expect(itensCarregados[0].nome, 'Leite');
      expect(itensCarregados[0].categoria, 'Laticínios');
      expect(itensCarregados[0].comprado, false);
      expect(itensCarregados[1].nome, 'Pão');
      expect(itensCarregados[1].categoria, 'Padaria');
      expect(itensCarregados[1].comprado, true);
    });

    test('Deve salvar e carregar filtro de categoria', () async {
      // Salvar filtro
      await ListaComprasService.salvarFiltroCategoria('Alimentação');

      // Carregar filtro
      final filtro = await ListaComprasService.carregarFiltroCategoria();

      expect(filtro, 'Alimentação');
    });

    test('Deve salvar e carregar ordenação', () async {
      // Salvar ordenação
      await ListaComprasService.salvarOrdenacao('categoria');

      // Carregar ordenação
      final ordenacao = await ListaComprasService.carregarOrdenacao();

      expect(ordenacao, 'categoria');
    });

    test('Deve retornar lista vazia quando não há dados', () async {
      final itens = await ListaComprasService.carregarItens();
      expect(itens, isEmpty);
    });

    test('Deve retornar ordenação padrão quando não há dados', () async {
      final ordenacao = await ListaComprasService.carregarOrdenacao();
      expect(ordenacao, 'nome');
    });

    test('Deve retornar null para filtro quando não há dados', () async {
      final filtro = await ListaComprasService.carregarFiltroCategoria();
      expect(filtro, isNull);
    });

    test('ItemCompra deve converter para Map e de volta corretamente', () {
      final item = ItemCompra(
        id: '123',
        nome: 'Açúcar',
        categoria: 'Alimentação',
        comprado: true,
        dataCriacao: DateTime(2025, 10, 5),
      );

      // Converter para Map
      final map = item.toMap();

      // Verificar estrutura do Map
      expect(map['id'], '123');
      expect(map['nome'], 'Açúcar');
      expect(map['categoria'], 'Alimentação');
      expect(map['comprado'], true);
      expect(map['dataCriacao'], DateTime(2025, 10, 5).millisecondsSinceEpoch);

      // Converter de volta para ItemCompra
      final itemReconstruido = ItemCompra.fromMap(map);

      // Verificar se os dados foram preservados
      expect(itemReconstruido.id, item.id);
      expect(itemReconstruido.nome, item.nome);
      expect(itemReconstruido.categoria, item.categoria);
      expect(itemReconstruido.comprado, item.comprado);
      expect(itemReconstruido.dataCriacao, item.dataCriacao);
    });
  });
}
