import 'package:flutter/material.dart';
import '../models/item_compra.dart';

class DialogoAdicionarItem extends StatefulWidget {
  final ItemCompra? itemParaEditar;

  const DialogoAdicionarItem({super.key, this.itemParaEditar});

  @override
  State<DialogoAdicionarItem> createState() => _DialogoAdicionarItemState();
}

class _DialogoAdicionarItemState extends State<DialogoAdicionarItem> {
  final _formKey = GlobalKey<FormState>();
  final _controladorNome = TextEditingController();
  String _categoriaSelecionada = CategoriaItem.geral.nome;

  @override
  void initState() {
    super.initState();
    if (widget.itemParaEditar != null) {
      _controladorNome.text = widget.itemParaEditar!.nome;
      _categoriaSelecionada = widget.itemParaEditar!.categoria;
    }
  }

  @override
  void dispose() {
    _controladorNome.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdicao = widget.itemParaEditar != null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isEdicao ? Icons.edit : Icons.add_shopping_cart,
            color: Colors.blue[600],
          ),
          const SizedBox(width: 8),
          Text(isEdicao ? 'Editar Item' : 'Adicionar Item'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _controladorNome,
              decoration: const InputDecoration(
                labelText: 'Nome do item',
                hintText: 'Ex: Leite, Pão, Sabonete...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.shopping_cart),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Por favor, digite o nome do item';
                }
                return null;
              },
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _categoriaSelecionada,
              decoration: const InputDecoration(
                labelText: 'Categoria',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: CategoriaItem.values.map((categoria) {
                return DropdownMenuItem<String>(
                  value: categoria.nome,
                  child: Row(
                    children: [
                      Text(
                        categoria.emoji,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(categoria.nome),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _categoriaSelecionada = value!;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _salvarItem,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[600],
            foregroundColor: Colors.white,
          ),
          child: Text(isEdicao ? 'Salvar' : 'Adicionar'),
        ),
      ],
    );
  }

  void _salvarItem() {
    if (_formKey.currentState!.validate()) {
      final item = ItemCompra(
        id:
            widget.itemParaEditar?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        nome: _controladorNome.text.trim(),
        categoria: _categoriaSelecionada,
        comprado: widget.itemParaEditar?.comprado ?? false,
        dataCriacao: widget.itemParaEditar?.dataCriacao,
      );

      Navigator.of(context).pop(item);
    }
  }
}

class DialogoFiltrosOrdenacao extends StatefulWidget {
  final String? categoriaAtual;
  final String ordenacaoAtual;

  const DialogoFiltrosOrdenacao({
    super.key,
    this.categoriaAtual,
    required this.ordenacaoAtual,
  });

  @override
  State<DialogoFiltrosOrdenacao> createState() =>
      _DialogoFiltrosOrdenacaoState();
}

class _DialogoFiltrosOrdenacaoState extends State<DialogoFiltrosOrdenacao> {
  String? _categoriaSelecionada;
  String _ordenacaoSelecionada = 'nome';

  @override
  void initState() {
    super.initState();
    _categoriaSelecionada = widget.categoriaAtual;
    _ordenacaoSelecionada = widget.ordenacaoAtual;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.tune, color: Colors.blue),
          SizedBox(width: 8),
          Text('Filtros e Ordenação'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filtrar por categoria:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            value: _categoriaSelecionada,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.filter_list),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Todas as categorias'),
              ),
              ...CategoriaItem.values.map((categoria) {
                return DropdownMenuItem<String?>(
                  value: categoria.nome,
                  child: Row(
                    children: [
                      Text(
                        categoria.emoji,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(categoria.nome),
                    ],
                  ),
                );
              }),
            ],
            onChanged: (value) {
              setState(() {
                _categoriaSelecionada = value;
              });
            },
          ),

          const SizedBox(height: 16),
          const Text(
            'Ordenar por:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _ordenacaoSelecionada,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.sort),
            ),
            items: const [
              DropdownMenuItem(value: 'nome', child: Text('Nome (A-Z)')),
              DropdownMenuItem(value: 'nome_desc', child: Text('Nome (Z-A)')),
              DropdownMenuItem(value: 'categoria', child: Text('Categoria')),
              DropdownMenuItem(value: 'data', child: Text('Data de criação')),
              DropdownMenuItem(
                value: 'status',
                child: Text('Status (pendentes primeiro)'),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _ordenacaoSelecionada = value!;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop({
              'categoria': _categoriaSelecionada,
              'ordenacao': _ordenacaoSelecionada,
            });
          },
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}
