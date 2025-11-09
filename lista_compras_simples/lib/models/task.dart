import 'package:uuid/uuid.dart';

class Task {
  final String id;
  final String title;
  final String description;
  final bool completed;
  final String priority;
  final DateTime createdAt;
  final DateTime? dueDate;
  final String categoryId;
  final DateTime? reminderTime;

  Task({
    String? id,
    required this.title,
    this.description = '',
    this.completed = false,
    this.priority = 'medium',
    DateTime? createdAt,
    this.dueDate,
    this.categoryId = 'default',
    this.reminderTime,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'completed': completed ? 1 : 0,
      'priority': priority,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'categoryId': categoryId,
      'reminderTime': reminderTime?.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'] ?? '',
      completed: map['completed'] == 1,
      priority: map['priority'] ?? 'medium',
      createdAt: DateTime.parse(map['createdAt']),
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      categoryId: map['categoryId'] ?? 'default',
      reminderTime: map['reminderTime'] != null
          ? DateTime.parse(map['reminderTime'])
          : null,
    );
  }

  Task copyWith({
    String? title,
    String? description,
    bool? completed,
    String? priority,
    DateTime? dueDate,
    String? categoryId,
    DateTime? reminderTime,
    bool clearDueDate = false,
    bool clearReminderTime = false,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      completed: completed ?? this.completed,
      priority: priority ?? this.priority,
      createdAt: createdAt,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      categoryId: categoryId ?? this.categoryId,
      reminderTime: clearReminderTime
          ? null
          : (reminderTime ?? this.reminderTime),
    );
  }

  static String getPriorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return '#9C27B0';
      case 'high':
        return '#FF5252';
      case 'medium':
        return '#FF9800';
      case 'low':
        return '#4CAF50';
      default:
        return '#FF9800';
    }
  }

  static String getPriorityText(String priority) {
    switch (priority) {
      case 'urgent':
        return 'Urgente';
      case 'high':
        return 'Alta';
      case 'medium':
        return 'Média';
      case 'low':
        return 'Baixa';
      default:
        return 'Média';
    }
  }

  bool get isOverdue {
    if (dueDate == null || completed) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDateOnly = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return today.isAfter(dueDateOnly);
  }

  bool get isDueToday {
    if (dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDateOnly = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return dueDateOnly.isAtSameMomentAs(today);
  }

  bool get isDueTomorrow {
    if (dueDate == null) return false;
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final dueDateOnly = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return dueDateOnly.isAtSameMomentAs(tomorrow);
  }

  String get shareText {
    final buffer = StringBuffer();
    buffer.writeln('📋 **TAREFA**');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📌 $title');

    if (description.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('📝 **Descrição:**');
      buffer.writeln(description);
    }

    buffer.writeln();
    buffer.writeln('🎯 **Prioridade:** ${getPriorityText(priority)}');

    if (dueDate != null) {
      buffer.writeln('📅 **Vencimento:** ${_formatDate(dueDate!)}');
      if (isOverdue && !completed) {
        buffer.writeln('⚠️ **Status:** VENCIDA');
      } else if (isDueToday && !completed) {
        buffer.writeln('🔥 **Status:** VENCE HOJE');
      }
    }

    if (reminderTime != null && !completed) {
      buffer.writeln(
        '⏰ **Lembrete:** ${_formatDate(reminderTime!)} ${_formatTime(reminderTime!)}',
      );
    }

    buffer.writeln(
      '✅ **Situação:** ${completed ? "✓ Concluída" : "○ Pendente"}',
    );
    buffer.writeln('📆 **Criada em:** ${_formatDate(createdAt)}');

    buffer.writeln();
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📱 Compartilhado via App Lista de Tarefas');

    return buffer.toString();
  }

  String getShareTextWithCategory(String? categoryName, String? categoryIcon) {
    final buffer = StringBuffer();
    buffer.writeln('📋 **TAREFA**');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📌 $title');

    if (categoryName != null && categoryIcon != null) {
      buffer.writeln('📂 **Categoria:** $categoryIcon $categoryName');
    }

    if (description.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('📝 **Descrição:**');
      buffer.writeln(description);
    }

    buffer.writeln();
    buffer.writeln('🎯 **Prioridade:** ${getPriorityText(priority)}');

    if (dueDate != null) {
      buffer.writeln('📅 **Vencimento:** ${_formatDate(dueDate!)}');
      if (isOverdue && !completed) {
        buffer.writeln('⚠️ **Status:** VENCIDA');
      } else if (isDueToday && !completed) {
        buffer.writeln('🔥 **Status:** VENCE HOJE');
      }
    }

    if (reminderTime != null && !completed) {
      buffer.writeln(
        '⏰ **Lembrete:** ${_formatDate(reminderTime!)} ${_formatTime(reminderTime!)}',
      );
    }

    buffer.writeln(
      '✅ **Situação:** ${completed ? "✓ Concluída" : "○ Pendente"}',
    );
    buffer.writeln('📆 **Criada em:** ${_formatDate(createdAt)}');

    buffer.writeln();
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📱 Compartilhado via App Lista de Tarefas');

    return buffer.toString();
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
