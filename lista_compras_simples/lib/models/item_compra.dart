import 'dart:convert';

class ItemCompra {
  final String id;
  final String nome;
  final String categoria;
  final bool comprado;
  final DateTime dataCriacao;

  ItemCompra({
    required this.id,
    required this.nome,
    required this.categoria,
    this.comprado = false,
    DateTime? dataCriacao,
  }) : dataCriacao = dataCriacao ?? DateTime.now();

  ItemCompra copyWith({
    String? id,
    String? nome,
    String? categoria,
    bool? comprado,
    DateTime? dataCriacao,
  }) {
    return ItemCompra(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      categoria: categoria ?? this.categoria,
      comprado: comprado ?? this.comprado,
      dataCriacao: dataCriacao ?? this.dataCriacao,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'categoria': categoria,
      'comprado': comprado,
      'dataCriacao': dataCriacao.millisecondsSinceEpoch,
    };
  }

  factory ItemCompra.fromMap(Map<String, dynamic> map) {
    return ItemCompra(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      categoria: map['categoria'] ?? 'Geral',
      comprado: map['comprado'] ?? false,
      dataCriacao: DateTime.fromMillisecondsSinceEpoch(map['dataCriacao'] ?? 0),
    );
  }

  String toJson() => json.encode(toMap());

  factory ItemCompra.fromJson(String source) =>
      ItemCompra.fromMap(json.decode(source));

  @override
  String toString() {
    return 'ItemCompra(id: $id, nome: $nome, categoria: $categoria, comprado: $comprado, dataCriacao: $dataCriacao)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ItemCompra && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

enum CategoriaItem {
  geral('Geral', '🛒'),
  alimentacao('Alimentação', '🍎'),
  bebidas('Bebidas', '🥤'),
  limpeza('Limpeza', '🧽'),
  higiene('Higiene', '🧴'),
  carne('Carnes', '🥩'),
  lacticinios('Laticínios', '🥛'),
  padaria('Padaria', '🍞'),
  frutas('Frutas', '🍓'),
  verduras('Verduras', '🥬'),
  farmacia('Farmácia', '💊'),
  eletronicos('Eletrônicos', '📱'),
  roupas('Roupas', '👕'),
  casa('Casa', '🏠');

  const CategoriaItem(this.nome, this.emoji);
  final String nome;
  final String emoji;

  static List<String> get nomes =>
      CategoriaItem.values.map((e) => e.nome).toList();
  static List<String> get nomesComEmoji =>
      CategoriaItem.values.map((e) => '${e.emoji} ${e.nome}').toList();
}
