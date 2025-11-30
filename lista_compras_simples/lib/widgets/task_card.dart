import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' as fnd;
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/category.dart';
import '../services/database_service.dart';

class TaskCard extends StatefulWidget {
  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onToggle,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  Category? _category;

  @override
  void initState() {
    super.initState();
    _loadCategory();
  }

  @override
  void didUpdateWidget(TaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.id != widget.task.id ||
        oldWidget.task.categoryId != widget.task.categoryId) {
      _loadCategory();
    }
  }

  Future<void> _loadCategory() async {
    try {
      final category = await DatabaseService.instance.readCategory(
        widget.task.categoryId,
      );
      if (mounted) {
        setState(() {
          _category = category;
        });
      }
    } catch (e) {
      fnd.debugPrint('Erro ao carregar categoria: $e');
    }
  }

  Color _getPriorityColor() {
    switch (widget.task.priority) {
      case 'urgent':
        return const Color(0xFF9C27B0);
      case 'high':
        return const Color(0xFFFF5252);
      case 'medium':
        return const Color(0xFFFF9800);
      case 'low':
        return const Color(0xFF4CAF50);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  Icon _getPriorityIcon() {
    switch (widget.task.priority) {
      case 'urgent':
        return const Icon(Icons.priority_high, color: Color(0xFF9C27B0));
      case 'high':
        return const Icon(Icons.flag, color: Color(0xFFFF5252));
      case 'medium':
        return const Icon(Icons.flag, color: Color(0xFFFF9800));
      case 'low':
        return const Icon(Icons.flag, color: Color(0xFF4CAF50));
      default:
        return const Icon(Icons.flag, color: Color(0xFF9E9E9E));
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Hoje';
    } else if (difference.inDays == 1) {
      return 'Ontem';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} dias atrás';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: widget.onToggle,
        onLongPress: () {
          showDialog(
            context: context,
            builder: (context) => SimpleDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              children: [
                SimpleDialogOption(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onEdit?.call();
                  },
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: const Icon(Icons.edit),
                    title: const Text('Editar'),
                  ),
                ),
                SimpleDialogOption(
                  onPressed: () {
                    Navigator.pop(context);
                    final shareText = widget.task.getShareTextWithCategory(
                      _category?.name,
                      _category?.icon,
                    );
                    Share.share(shareText);
                  },
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: const Icon(Icons.share),
                    title: const Text('Compartilhar'),
                  ),
                ),
                SimpleDialogOption(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onDelete?.call();
                  },
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text(
                      'Excluir',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getPriorityColor().withAlpha((0.3 * 255).round()),
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (_category != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Color(
                            int.parse(
                              _category!.color.replaceFirst('#', '0xFF'),
                            ),
                          ).withAlpha((0.1 * 255).round()),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Color(
                              int.parse(
                                _category!.color.replaceFirst('#', '0xFF'),
                              ),
                            ).withAlpha((0.3 * 255).round()),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _category!.icon,
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _category!.name,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(
                                  int.parse(
                                    _category!.color.replaceFirst('#', '0xFF'),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const Spacer(),

                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            widget.onEdit?.call();
                            break;
                          case 'delete':
                            widget.onDelete?.call();
                            break;
                          case 'share':
                            final shareText = widget.task
                                .getShareTextWithCategory(
                                  _category?.name,
                                  _category?.icon,
                                );
                            Share.share(shareText);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 8),
                              Text('Editar'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'share',
                          child: Row(
                            children: [
                              Icon(Icons.share, size: 20),
                              SizedBox(width: 8),
                              Text('Compartilhar'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Excluir',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    Checkbox(
                      value: widget.task.completed,
                      onChanged: (_) => widget.onToggle?.call(),
                      activeColor: _getPriorityColor(),
                    ),

                    Expanded(
                      child: Text(
                        widget.task.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          decoration: widget.task.completed
                              ? TextDecoration.lineThrough
                              : null,
                          color: widget.task.completed
                              ? Colors.grey[600]
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),

                if (widget.task.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.task.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      decoration: widget.task.completed
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                if (widget.task.dueDate != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: widget.task.isOverdue
                          ? Colors.red.withAlpha((0.1 * 255).round())
                          : widget.task.isDueToday
                          ? Colors.amber.withAlpha((0.1 * 255).round())
                          : Colors.blue.withAlpha((0.1 * 255).round()),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.task.isOverdue
                            ? Colors.red.withAlpha((0.3 * 255).round())
                            : widget.task.isDueToday
                            ? Colors.amber.withAlpha((0.3 * 255).round())
                            : Colors.blue.withAlpha((0.3 * 255).round()),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.task.isOverdue
                              ? Icons.warning
                              : widget.task.isDueToday
                              ? Icons.today
                              : Icons.calendar_today,
                          size: 16,
                          color: widget.task.isOverdue
                              ? Colors.red
                              : widget.task.isDueToday
                              ? Colors.amber[700]
                              : Colors.blue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.task.isOverdue
                              ? 'Vencida em ${DateFormat('dd/MM/yyyy').format(widget.task.dueDate!)}'
                              : widget.task.isDueToday
                              ? 'VENCE HOJE'
                              : 'Vence em ${DateFormat('dd/MM/yyyy').format(widget.task.dueDate!)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: widget.task.isOverdue
                                ? Colors.red
                                : widget.task.isDueToday
                                ? Colors.amber[700]
                                : Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Chip(
                            avatar: _getPriorityIcon(),
                            label: Text(
                              Task.getPriorityText(widget.task.priority),
                              style: TextStyle(
                                fontSize: 12,
                                color: _getPriorityColor(),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            backgroundColor: _getPriorityColor().withAlpha(
                              (0.1 * 255).round(),
                            ),
                            side: BorderSide(
                              color: _getPriorityColor().withAlpha(
                                (0.3 * 255).round(),
                              ),
                            ),
                          ),

                          if (widget.task.hasPhoto)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withAlpha(
                                  (0.1 * 255).round(),
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue.withAlpha(
                                    (0.5 * 255).round(),
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.photo_camera,
                                    size: 14,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.task.hasMultiplePhotos
                                        ? '${widget.task.photosPaths!.length}'
                                        : '1',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          if (widget.task.hasLocation)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple.withAlpha(
                                  (0.1 * 255).round(),
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.purple.withAlpha(
                                    (0.5 * 255).round(),
                                  ),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 14,
                                    color: Colors.purple,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Local',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.purple,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    IconButton(
                      onPressed: () {
                        final shareText = widget.task.getShareTextWithCategory(
                          _category?.name,
                          _category?.icon,
                        );
                        Share.share(shareText);
                      },
                      icon: const Icon(Icons.share),
                      tooltip: 'Compartilhar tarefa',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue.withAlpha(
                          (0.1 * 255).round(),
                        ),
                        foregroundColor: Colors.blue,
                        padding: const EdgeInsets.all(8),
                      ),
                    ),

                    const SizedBox(width: 8),

                    SizedBox(
                      width: 140,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isBounded = constraints.maxWidth.isFinite;
                          if (isBounded) {
                            return Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _formatDate(widget.task.createdAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (!widget.task.synced) ...[
                                  Icon(
                                    Icons.cloud_off,
                                    size: 16,
                                    color: Colors.orange[700],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Pendente',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange[700],
                                    ),
                                  ),
                                ] else ...[
                                  Icon(
                                    Icons.cloud_done,
                                    size: 16,
                                    color: Colors.green[700],
                                  ),
                                ],
                              ],
                            );
                          }

                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 140,
                                ),
                                child: Text(
                                  _formatDate(widget.task.createdAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (!widget.task.synced) ...[
                                Icon(
                                  Icons.cloud_off,
                                  size: 16,
                                  color: Colors.orange[700],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Pendente',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              ] else ...[
                                Icon(
                                  Icons.cloud_done,
                                  size: 16,
                                  color: Colors.green[700],
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),

                if (widget.task.completed) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha((0.1 * 255).round()),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.green.withAlpha((0.3 * 255).round()),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 16, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Tarefa Concluída',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
