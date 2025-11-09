import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io' show Platform;
import '../models/task.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/backup_service.dart';
import '../services/sensor_service.dart';
import '../services/location_service.dart';
import '../widgets/task_card.dart';
import 'task_form_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Task> _tasks = [];
  List<Task> _filteredTasks = [];
  List<Category> _categories = [];
  String _filterStatus = 'all';
  String _filterCategory = 'all';
  String _sortBy = 'dueDate';
  bool _isLoading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _setupShakeDetection();
    _setupGeofencing();
  }

  @override
  void dispose() {
    SensorService.instance.stop();
    LocationService.instance.stopGeofenceMonitoring();
    super.dispose();
  }

  void _setupShakeDetection() {
    if (Platform.isAndroid || Platform.isIOS) {
      SensorService.instance.startShakeDetection(
        () {},
        onLongShake: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.cyclone, color: Colors.white),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '🌀 Estou ficando tonto!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.deepPurple,
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        },
      );
    } else {
      print(
        '⚠️ Sensores não disponíveis nesta plataforma (Windows/Linux/macOS)',
      );
    }
  }

  void _setupGeofencing() {
    if (Platform.isAndroid || Platform.isIOS) {
      LocationService.instance.startGeofenceMonitoring((geofenceId, entered) {
        final task = _tasks.firstWhere(
          (t) => t.id == geofenceId,
          orElse: () => _tasks.first,
        );
        if (task.id == geofenceId) {
          NotificationService().showGeofenceNotification(task.title, entered);
        }
      });
    }
  }

  Future<void> _initializeApp() async {
    await NotificationService().initialize();
    await _loadCategories();
    await _loadTasks();
    await _checkOverdueTasks();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await DatabaseService.instance.readAllCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar categorias: $e');
    }
  }

  Future<void> _checkOverdueTasks() async {
    try {
      final overdueTasks = await DatabaseService.instance.getOverdueTasks();
      for (final task in overdueTasks) {
        await NotificationService().scheduleOverdueAlert(task);
      }

      final todayTasks = await DatabaseService.instance.getTasksDueToday();
      if (todayTasks.isNotEmpty) {
        await NotificationService().scheduleDueTodayAlert(todayTasks);
      }
    } catch (e) {
      debugPrint('Erro ao verificar tarefas vencidas: $e');
    }
  }

  Future<void> _loadTasks() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final tasks = await DatabaseService.instance.readAll();
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _applyFiltersAndSort();
          _isLoading = false;
        });
        _updateGeofences();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar tarefas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updateGeofences() {
    if (Platform.isAndroid || Platform.isIOS) {
      for (final task in _tasks) {
        if (task.hasLocation && !task.completed) {
          LocationService.instance.addGeofence(
            task.id,
            task.latitude!,
            task.longitude!,
            100.0,
          );
        }
      }
    }
  }

  Future<void> _refreshTasks() async {
    if (!mounted) return;

    setState(() => _isRefreshing = true);
    await _loadTasks();
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  void _applyFiltersAndSort() {
    List<Task> filtered = List.from(_tasks);

    switch (_filterStatus) {
      case 'pending':
        filtered = filtered.where((task) => !task.completed).toList();
        break;
      case 'completed':
        filtered = filtered.where((task) => task.completed).toList();
        break;
      case 'overdue':
        filtered = filtered
            .where((task) => task.isOverdue && !task.completed)
            .toList();
        break;
      default:
        break;
    }

    if (_filterCategory != 'all') {
      filtered = filtered
          .where((task) => task.categoryId == _filterCategory)
          .toList();
    }

    switch (_sortBy) {
      case 'priority':
        filtered.sort((a, b) {
          const priorityOrder = {'urgent': 4, 'high': 3, 'medium': 2, 'low': 1};
          return (priorityOrder[b.priority] ?? 0) -
              (priorityOrder[a.priority] ?? 0);
        });
        break;
      case 'title':
        filtered.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
      case 'created':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      default:
        filtered.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
        break;
    }

    setState(() {
      _filteredTasks = filtered;
    });
  }

  Future<void> _toggleTaskComplete(Task task) async {
    try {
      final updatedTask = task.copyWith(completed: !task.completed);
      await DatabaseService.instance.update(updatedTask);

      if (updatedTask.completed) {
        await NotificationService().cancelTaskReminder(task.id);
      } else if (updatedTask.reminderTime != null &&
          updatedTask.reminderTime!.isAfter(DateTime.now())) {
        await NotificationService().scheduleTaskReminder(updatedTask);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              updatedTask.completed
                  ? '✓ Tarefa marcada como concluída'
                  : '○ Tarefa marcada como pendente',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: updatedTask.completed ? Colors.green : Colors.blue,
          ),
        );
        _loadTasks();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar tarefa: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteTask(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Deseja realmente excluir a tarefa "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await DatabaseService.instance.delete(task.id);
        await NotificationService().cancelTaskReminder(task.id);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Tarefa excluída com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
        _loadTasks();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir tarefa: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportTasks() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Exportando backup...'),
            ],
          ),
        ),
      );

      final filePath = await BackupService().exportToDeviceStorage();

      if (mounted) {
        Navigator.pop(context);

        if (filePath != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Backup salvo em: ${filePath.split('/').last}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Compartilhar',
                textColor: Colors.white,
                onPressed: () async {
                  try {
                    await BackupService().shareBackup();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erro ao compartilhar: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Exportação cancelada pelo usuário'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao exportar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importTasks() async {
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('Importar Backup'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Esta ação irá:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Substituir todas as tarefas atuais'),
            Text('• Substituir todas as categorias'),
            Text('• Validar a estrutura do arquivo'),
            SizedBox(height: 16),
            Text(
              'Certifique-se de ter um backup atual antes de continuar.',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text(
              'Selecionar Arquivo',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (shouldProceed != true) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Importando e validando...'),
            ],
          ),
        ),
      );

      final success = await BackupService().importFromJson();

      if (mounted) {
        Navigator.pop(context);

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Backup importado com sucesso!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          await _loadCategories();
          await _loadTasks();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '❌ Falha na importação - arquivo inválido ou cancelado',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);

        String errorMessage = 'Erro desconhecido';
        if (e.toString().contains('Arquivo de backup inválido')) {
          errorMessage = 'Arquivo de backup inválido - estrutura incorreta';
        } else if (e.toString().contains('FormatException')) {
          errorMessage = 'Arquivo JSON com formato inválido';
        } else if (e.toString().contains('FileSystemException')) {
          errorMessage = 'Erro ao ler o arquivo selecionado';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro na importação: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _navigateToForm({Task? task}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => TaskFormScreen(task: task)),
    );

    if (result == true && mounted) {
      _loadTasks();
    }
  }

  Future<void> _shareFilteredTasks() async {
    if (_filteredTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhuma tarefa para compartilhar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final buffer = StringBuffer();
      buffer.writeln('📋 **LISTA DE TAREFAS**');
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln();

      if (_filterStatus != 'all' || _filterCategory != 'all') {
        buffer.writeln('🔍 **Filtros aplicados:**');
        if (_filterStatus != 'all') {
          String statusText = '';
          switch (_filterStatus) {
            case 'pending':
              statusText = 'Pendentes';
              break;
            case 'completed':
              statusText = 'Concluídas';
              break;
            case 'overdue':
              statusText = 'Vencidas';
              break;
          }
          buffer.writeln('   • Status: $statusText');
        }
        if (_filterCategory != 'all') {
          final category = _categories.firstWhere(
            (c) => c.id == _filterCategory,
          );
          buffer.writeln('   • Categoria: ${category.icon} ${category.name}');
        }
        buffer.writeln();
      }

      buffer.writeln(
        '📊 **Resumo:** ${_filteredTasks.length} tarefa${_filteredTasks.length != 1 ? 's' : ''}',
      );
      buffer.writeln();

      for (int i = 0; i < _filteredTasks.length; i++) {
        final task = _filteredTasks[i];
        final category = _categories.firstWhere(
          (c) => c.id == task.categoryId,
          orElse: () => Category(
            id: 'default',
            name: 'Geral',
            color: '#2196F3',
            icon: '📝',
          ),
        );

        buffer.writeln(
          '${i + 1}. ${task.completed ? "✅" : "⭕"} **${task.title}**',
        );

        if (task.description.isNotEmpty) {
          buffer.writeln('   📝 ${task.description}');
        }

        buffer.writeln('   📂 ${category.icon} ${category.name}');
        buffer.writeln('   🎯 ${Task.getPriorityText(task.priority)}');

        if (task.dueDate != null) {
          final dateStr =
              '${task.dueDate!.day.toString().padLeft(2, '0')}/${task.dueDate!.month.toString().padLeft(2, '0')}/${task.dueDate!.year}';
          if (task.isOverdue && !task.completed) {
            buffer.writeln('   ⚠️ Vencida em $dateStr');
          } else if (task.isDueToday && !task.completed) {
            buffer.writeln('   🔥 VENCE HOJE ($dateStr)');
          } else {
            buffer.writeln('   📅 Vence em $dateStr');
          }
        }

        buffer.writeln();
      }

      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('📱 Compartilhado via App Lista de Tarefas');

      final shouldShare = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Compartilhar Lista'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(
              child: SelectableText(
                buffer.toString(),
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Compartilhar'),
            ),
          ],
        ),
      );

      if (shouldShare == true) {
        await Share.share(buffer.toString());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao compartilhar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Map<String, int> _getStatistics() {
    final total = _tasks.length;
    final completed = _tasks.where((task) => task.completed).length;
    final pending = total - completed;
    final urgent = _tasks
        .where((task) => task.priority == 'urgent' && !task.completed)
        .length;
    final high = _tasks
        .where((task) => task.priority == 'high' && !task.completed)
        .length;
    final overdue = _tasks
        .where((task) => task.isOverdue && !task.completed)
        .length;
    final dueToday = _tasks
        .where((task) => task.isDueToday && !task.completed)
        .length;

    return {
      'total': total,
      'completed': completed,
      'pending': pending,
      'urgent': urgent,
      'high': high,
      'overdue': overdue,
      'dueToday': dueToday,
    };
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _filterStatus,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          prefixIcon: Icon(Icons.filter_list),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Todas')),
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text('Pendentes'),
                          ),
                          DropdownMenuItem(
                            value: 'completed',
                            child: Text('Concluídas'),
                          ),
                          DropdownMenuItem(
                            value: 'overdue',
                            child: Text('Vencidas'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _filterStatus = value;
                              _applyFiltersAndSort();
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filterCategory,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Categoria',
                          prefixIcon: Icon(Icons.category),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('Todas'),
                          ),
                          ..._categories.map(
                            (category) => DropdownMenuItem(
                              value: category.id,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(category.icon),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      category.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _filterCategory = value;
                              _applyFiltersAndSort();
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _sortBy,
                        decoration: const InputDecoration(
                          labelText: 'Ordenar por',
                          prefixIcon: Icon(Icons.sort),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'dueDate',
                            child: Text('Vencimento'),
                          ),
                          DropdownMenuItem(
                            value: 'priority',
                            child: Text('Prioridade'),
                          ),
                          DropdownMenuItem(
                            value: 'title',
                            child: Text('Título'),
                          ),
                          DropdownMenuItem(
                            value: 'created',
                            child: Text('Criação'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _sortBy = value;
                              _applyFiltersAndSort();
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _filterStatus = 'all';
                          _filterCategory = 'all';
                          _sortBy = 'dueDate';
                          _applyFiltersAndSort();
                        });
                      },
                      icon: const Icon(Icons.clear_all),
                      tooltip: 'Limpar filtros',
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _filterStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    prefixIcon: Icon(Icons.filter_list),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Todas')),
                    DropdownMenuItem(
                      value: 'pending',
                      child: Text('Pendentes'),
                    ),
                    DropdownMenuItem(
                      value: 'completed',
                      child: Text('Concluídas'),
                    ),
                    DropdownMenuItem(value: 'overdue', child: Text('Vencidas')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _filterStatus = value;
                        _applyFiltersAndSort();
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _filterCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    prefixIcon: Icon(Icons.category),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('Todas')),
                    ..._categories.map(
                      (category) => DropdownMenuItem(
                        value: category.id,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(category.icon),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                category.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _filterCategory = value;
                        _applyFiltersAndSort();
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _sortBy,
                  decoration: const InputDecoration(
                    labelText: 'Ordenar',
                    prefixIcon: Icon(Icons.sort),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'dueDate',
                      child: Text('Vencimento'),
                    ),
                    DropdownMenuItem(
                      value: 'priority',
                      child: Text('Prioridade'),
                    ),
                    DropdownMenuItem(value: 'title', child: Text('Título')),
                    DropdownMenuItem(value: 'created', child: Text('Criação')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _sortBy = value;
                        _applyFiltersAndSort();
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),

              IconButton(
                onPressed: () {
                  setState(() {
                    _filterStatus = 'all';
                    _filterCategory = 'all';
                    _sortBy = 'dueDate';
                    _applyFiltersAndSort();
                  });
                },
                icon: const Icon(Icons.clear_all),
                tooltip: 'Limpar filtros',
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatistics() {
    final stats = _getStatistics();

    return Container(
      margin: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Container(
              width: 100,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.list_alt, color: Colors.blue, size: 24),
                  const SizedBox(height: 4),
                  Text(
                    stats['total']!.toString(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            Container(
              width: 100,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.pending_actions,
                    color: Colors.orange,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stats['pending']!.toString(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  Text(
                    'Pendentes',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            Container(
              width: 100,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 24),
                  const SizedBox(height: 4),
                  Text(
                    stats['completed']!.toString(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    'Concluídas',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            if (stats['overdue']! > 0)
              Container(
                width: 100,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.warning, color: Colors.red, size: 24),
                    const SizedBox(height: 4),
                    Text(
                      stats['overdue']!.toString(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    Text(
                      'Vencidas',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),

            if (stats['overdue']! > 0) const SizedBox(width: 8),

            if (stats['urgent']! > 0)
              Container(
                width: 100,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.priority_high,
                      color: Colors.purple,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stats['urgent']!.toString(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                    Text(
                      'Urgentes',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.purple.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    String suggestion;

    switch (_filterStatus) {
      case 'pending':
        message = 'Nenhuma tarefa pendente';
        suggestion = 'Todas as tarefas estão concluídas! 🎉';
        break;
      case 'completed':
        message = 'Nenhuma tarefa concluída';
        suggestion = 'Complete algumas tarefas para vê-las aqui.';
        break;
      default:
        message = 'Nenhuma tarefa encontrada';
        suggestion = 'Toque no botão + para criar sua primeira tarefa.';
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _filterStatus == 'completed' ? Icons.celebration : Icons.task_alt,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              suggestion,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            if (_filterStatus == 'all') ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _navigateToForm(),
                icon: const Icon(Icons.add),
                label: const Text('Criar Primeira Tarefa'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Tarefas'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _refreshTasks,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Atualizar',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _exportTasks();
                  break;
                case 'import':
                  _importTasks();
                  break;
                case 'share_list':
                  _shareFilteredTasks();
                  break;
                case 'backup_auto':
                  BackupService().createAutoBackup();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✓ Backup automático criado'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  break;
                case 'settings':
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.file_download, size: 20, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Exportar para JSON'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.file_upload, size: 20, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Importar de JSON'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'share_list',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 20, color: Colors.purple),
                    SizedBox(width: 8),
                    Text('Compartilhar Lista'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'backup_auto',
                child: Row(
                  children: [
                    Icon(Icons.backup, size: 20, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Backup Automático'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Configurações'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshTasks,
              child: Column(
                children: [
                  _buildStatistics(),

                  _buildFilterChips(),

                  if (_filteredTasks.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.task_alt,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_filteredTasks.length} tarefa${_filteredTasks.length != 1 ? 's' : ''} encontrada${_filteredTasks.length != 1 ? 's' : ''}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),

                          IconButton(
                            onPressed: _shareFilteredTasks,
                            icon: const Icon(Icons.share, size: 18),
                            tooltip: 'Compartilhar esta lista',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.purple.withOpacity(0.1),
                              foregroundColor: Colors.purple,
                              padding: const EdgeInsets.all(6),
                            ),
                          ),

                          const SizedBox(width: 8),

                          if (_filterStatus != 'all' ||
                              _filterCategory != 'all' ||
                              _sortBy != 'dueDate')
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _filterStatus = 'all';
                                  _filterCategory = 'all';
                                  _sortBy = 'dueDate';
                                  _applyFiltersAndSort();
                                });
                              },
                              icon: const Icon(Icons.clear, size: 16),
                              label: const Text('Limpar'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey[600],
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                  Expanded(
                    child: _filteredTasks.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            itemCount: _filteredTasks.length,
                            itemBuilder: (context, index) {
                              final task = _filteredTasks[index];
                              return TaskCard(
                                key: ValueKey('${task.id}_${task.categoryId}'),
                                task: task,
                                onToggle: () => _toggleTaskComplete(task),
                                onEdit: () => _navigateToForm(task: task),
                                onDelete: () => _deleteTask(task),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToForm(),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        tooltip: 'Nova Tarefa',
        child: const Icon(Icons.add),
      ),
    );
  }
}
