import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:share_plus/share_plus.dart';
import 'models/item_compra.dart';
import 'services/lista_compras_service.dart';
import 'widgets/item_compra_widget.dart';
import 'widgets/dialogos.dart';

void main() {
  runApp(const ListaComprasApp());
}

class ListaComprasApp extends StatelessWidget {
  const ListaComprasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lista de Compras',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          elevation: 2,
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
        ),
      ),
      home: const TelaListaCompras(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class TelaListaCompras extends StatefulWidget {
  const TelaListaCompras({super.key});

  @override
  State<TelaListaCompras> createState() => _TelaListaComprasState();
}

class _TelaListaComprasState extends State<TelaListaCompras>
    with TickerProviderStateMixin {
  final TextEditingController _controladorBusca = TextEditingController();

  List<ItemCompra> _todosItens = [];
  List<ItemCompra> _itensFiltrados = [];
  String? _filtroCategoria;
  String _ordenacao = 'nome';
  bool _mostrandoBusca = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _carregarDados();
    _animationController.forward();
  }

  @override
  void dispose() {
    _controladorBusca.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    final itens = await ListaComprasService.carregarItens();
    final categoria = await ListaComprasService.carregarFiltroCategoria();
    final ordenacao = await ListaComprasService.carregarOrdenacao();

    setState(() {
      _todosItens = itens;
      _filtroCategoria = categoria;
      _ordenacao = ordenacao;
      _aplicarFiltrosEOrdenacao();
    });
  }

  void _aplicarFiltrosEOrdenacao() {
    List<ItemCompra> itens = List.from(_todosItens);

    if (_filtroCategoria != null) {
      itens = itens
          .where((item) => item.categoria == _filtroCategoria)
          .toList();
    }

    final textoBusca = _controladorBusca.text.toLowerCase();
    if (textoBusca.isNotEmpty) {
      itens = itens
          .where(
            (item) =>
                item.nome.toLowerCase().contains(textoBusca) ||
                item.categoria.toLowerCase().contains(textoBusca),
          )
          .toList();
    }

    switch (_ordenacao) {
      case 'nome':
        itens.sort((a, b) => a.nome.compareTo(b.nome));
        break;
      case 'nome_desc':
        itens.sort((a, b) => b.nome.compareTo(a.nome));
        break;
      case 'categoria':
        itens.sort((a, b) => a.categoria.compareTo(b.categoria));
        break;
      case 'data':
        itens.sort((a, b) => b.dataCriacao.compareTo(a.dataCriacao));
        break;
      case 'status':
        itens.sort((a, b) => a.comprado ? 1 : -1);
        break;
    }

    setState(() {
      _itensFiltrados = itens;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _mostrandoBusca
            ? _buildBarraBusca()
            : const Text('Lista de Compras'),
        actions: _buildAcoes(),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            if (_getCategorias().isNotEmpty) _buildFiltrosCategorias(),

            _buildEstatisticas(),

            Expanded(child: _buildListaItens()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarDialogoAdicionar,
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar'),
      ),
    );
  }

  Widget _buildBarraBusca() {
    return TextField(
      controller: _controladorBusca,
      autofocus: true,
      decoration: const InputDecoration(
        hintText: 'Buscar itens...',
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.white70),
      ),
      style: const TextStyle(color: Colors.white),
      onChanged: (_) => _aplicarFiltrosEOrdenacao(),
    );
  }

  List<Widget> _buildAcoes() {
    return [
      IconButton(
        icon: Icon(_mostrandoBusca ? Icons.close : Icons.search),
        onPressed: () {
          setState(() {
            _mostrandoBusca = !_mostrandoBusca;
            if (!_mostrandoBusca) {
              _controladorBusca.clear();
              _aplicarFiltrosEOrdenacao();
            }
          });
        },
        tooltip: _mostrandoBusca ? 'Fechar busca' : 'Buscar',
      ),
      IconButton(
        icon: const Icon(Icons.tune),
        onPressed: _mostrarDialogoFiltros,
        tooltip: 'Filtros e Ordenação',
      ),
      PopupMenuButton<String>(
        onSelected: _onMenuSelecionado,
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'share',
            child: Text('Compartilhar Lista'),
          ),
          const PopupMenuItem(value: 'clear', child: Text('Limpar Lista')),
        ],
      ),
    ];
  }

  Widget _buildFiltrosCategorias() {
    final categorias = _getCategorias();

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categorias.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return CategoriaChip(
              categoria: 'Todas',
              isSelected: _filtroCategoria == null,
              onTap: () => _selecionarCategoria(null),
            );
          }

          final categoria = categorias[index - 1];
          return CategoriaChip(
            categoria: categoria,
            isSelected: _filtroCategoria == categoria,
            onTap: () => _selecionarCategoria(categoria),
          );
        },
      ),
    );
  }

  Widget _buildEstatisticas() {
    final total = _todosItens.length;
    final comprados = _todosItens.where((item) => item.comprado).length;
    final restantes = total - comprados;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              EstatisticaCard(
                titulo: 'Total',
                valor: '$total',
                icone: Icons.list,
                cor: Colors.blue,
              ),
              const SizedBox(width: 8),
              EstatisticaCard(
                titulo: 'Comprados',
                valor: '$comprados',
                icone: Icons.check_circle,
                cor: Colors.green,
              ),
              const SizedBox(width: 8),
              EstatisticaCard(
                titulo: 'Restantes',
                valor: '$restantes',
                icone: Icons.pending,
                cor: Colors.orange,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListaItens() {
    if (_itensFiltrados.isEmpty) {
      return _buildEstadoVazio();
    }

    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _itensFiltrados.length,
        itemBuilder: (context, index) {
          final item = _itensFiltrados[index];
          return ItemCompraWidget(
            item: item,
            index: index,
            onToggle: () => _alternarStatusItem(item),
            onDelete: () => _confirmarRemocao(item),
            onEdit: () => _mostrarDialogoEditar(item),
          );
        },
      ),
    );
  }

  Widget _buildEstadoVazio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _todosItens.isEmpty
                ? 'Sua lista está vazia!'
                : 'Nenhum item encontrado',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            _todosItens.isEmpty
                ? 'Adicione itens para começar suas compras'
                : 'Tente ajustar os filtros de busca',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarDialogoAdicionar() async {
    final item = await showDialog<ItemCompra>(
      context: context,
      builder: (context) => const DialogoAdicionarItem(),
    );

    if (item != null) {
      await _adicionarItem(item);
    }
  }

  Future<void> _mostrarDialogoEditar(ItemCompra item) async {
    final itemEditado = await showDialog<ItemCompra>(
      context: context,
      builder: (context) => DialogoAdicionarItem(itemParaEditar: item),
    );

    if (itemEditado != null) {
      await _editarItem(item, itemEditado);
    }
  }

  Future<void> _mostrarDialogoFiltros() async {
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => DialogoFiltrosOrdenacao(
        categoriaAtual: _filtroCategoria,
        ordenacaoAtual: _ordenacao,
      ),
    );

    if (resultado != null) {
      setState(() {
        _filtroCategoria = resultado['categoria'];
        _ordenacao = resultado['ordenacao'];
      });

      await ListaComprasService.salvarFiltroCategoria(_filtroCategoria);
      await ListaComprasService.salvarOrdenacao(_ordenacao);
      _aplicarFiltrosEOrdenacao();
    }
  }

  Future<void> _adicionarItem(ItemCompra item) async {
    if (_todosItens.any(
      (existente) => existente.nome.toLowerCase() == item.nome.toLowerCase(),
    )) {
      _mostrarMensagem('Este item já está na sua lista!');
      return;
    }

    setState(() {
      _todosItens.add(item);
      _aplicarFiltrosEOrdenacao();
    });

    await ListaComprasService.salvarItens(_todosItens);
    _mostrarMensagem('Item "${item.nome}" adicionado!');
  }

  Future<void> _editarItem(
    ItemCompra itemOriginal,
    ItemCompra itemEditado,
  ) async {
    final index = _todosItens.indexWhere((item) => item.id == itemOriginal.id);
    if (index != -1) {
      setState(() {
        _todosItens[index] = itemEditado;
        _aplicarFiltrosEOrdenacao();
      });

      await ListaComprasService.salvarItens(_todosItens);
      _mostrarMensagem('Item atualizado!');
    }
  }

  Future<void> _alternarStatusItem(ItemCompra item) async {
    final index = _todosItens.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      setState(() {
        _todosItens[index] = item.copyWith(comprado: !item.comprado);
        _aplicarFiltrosEOrdenacao();
      });

      await ListaComprasService.salvarItens(_todosItens);
      _mostrarMensagem(item.comprado ? 'Item desmarcado!' : 'Item comprado!');
    }
  }

  Future<void> _confirmarRemocao(ItemCompra item) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover Item'),
        content: Text('Remover "${item.nome}" da lista?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remover', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      await _removerItem(item);
    }
  }

  Future<void> _removerItem(ItemCompra item) async {
    setState(() {
      _todosItens.removeWhere((i) => i.id == item.id);
      _aplicarFiltrosEOrdenacao();
    });

    await ListaComprasService.salvarItens(_todosItens);
    _mostrarMensagem('Item "${item.nome}" removido!');
  }

  void _selecionarCategoria(String? categoria) {
    setState(() {
      _filtroCategoria = categoria;
      _aplicarFiltrosEOrdenacao();
    });
    ListaComprasService.salvarFiltroCategoria(categoria);
  }

  void _onMenuSelecionado(String opcao) {
    switch (opcao) {
      case 'share':
        _compartilharLista();
        break;
      case 'clear':
        _confirmarLimpeza();
        break;
    }
  }

  void _compartilharLista() {
    if (_todosItens.isEmpty) {
      _mostrarMensagem('Sua lista está vazia!');
      return;
    }

    final textoCompartilhamento = ListaComprasService.exportarLista(
      _todosItens,
    );
    Share.share(textoCompartilhamento, subject: 'Minha Lista de Compras');
  }

  Future<void> _confirmarLimpeza() async {
    if (_todosItens.isEmpty) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar Lista'),
        content: const Text('Tem certeza que deseja remover todos os itens?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Limpar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      setState(() {
        _todosItens.clear();
        _aplicarFiltrosEOrdenacao();
      });

      await ListaComprasService.salvarItens(_todosItens);
      _mostrarMensagem('Lista limpa!');
    }
  }

  List<String> _getCategorias() {
    return _todosItens.map((item) => item.categoria).toSet().toList()..sort();
  }

  void _mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
