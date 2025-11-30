import 'package:uuid/uuid.dart';

class Task {
  final String id;
  final String title;
  final String description;
  final bool completed;
  final String priority;
  final DateTime createdAt;
  final DateTime? dueDate;
  final DateTime updatedAt;
  final bool synced;
  final String categoryId;
  final DateTime? reminderTime;

  final String? photoPath;
  final List<String>? photosPaths;

  final DateTime? completedAt;
  final String? completedBy;

  final double? latitude;
  final double? longitude;
  final String? locationName;
  final List<Map<String, dynamic>>? locationHistory;

  Task({
    String? id,
    required this.title,
    this.description = '',
    this.completed = false,
    this.priority = 'medium',
    DateTime? createdAt,
    this.dueDate,
    DateTime? updatedAt,
    this.synced = false,
    this.categoryId = 'default',
    this.reminderTime,
    this.photoPath,
    this.photosPaths,
    this.completedAt,
    this.completedBy,
    this.latitude,
    this.longitude,
    this.locationName,
    this.locationHistory,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? (createdAt ?? DateTime.now());

  bool get hasPhoto => photoPath?.isNotEmpty ?? false;
  bool get hasMultiplePhotos => photosPaths?.isNotEmpty ?? false;
  bool get hasLocation => latitude != null && longitude != null;
  bool get wasCompletedByShake => completedBy == 'shake';
  bool get hasLocationHistory => locationHistory?.isNotEmpty ?? false;

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
      'photoPath': photoPath,
      'photosPaths': photosPaths?.join('|'),
      'completedAt': completedAt?.toIso8601String(),
      'completedBy': completedBy,
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'locationHistory': locationHistory == null
          ? null
          : _encodeLocationHistory(locationHistory!),
      'updatedAt': updatedAt.toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  String _encodeLocationHistory(List<Map<String, dynamic>> history) {
    return history
        .map((loc) => '${loc['lat']},${loc['lon']},${loc['timestamp']}')
        .join('|');
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
      photoPath: map['photoPath'] as String?,
      photosPaths: map['photosPaths'] != null
          ? (map['photosPaths'] as String)
                .split('|')
                .where((s) => s.isNotEmpty)
                .toList()
          : null,
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'] as String)
          : null,
      completedBy: map['completedBy'] as String?,
      latitude: map['latitude'] != null
          ? (map['latitude'] as num).toDouble()
          : null,
      longitude: map['longitude'] != null
          ? (map['longitude'] as num).toDouble()
          : null,
      locationName: map['locationName'] as String?,
      locationHistory: map['locationHistory'] != null
          ? _decodeLocationHistoryStatic(map['locationHistory'] as String)
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : DateTime.parse(map['createdAt']),
      synced: (map['synced'] ?? 0) == 1,
    );
  }

  static List<Map<String, dynamic>> _decodeLocationHistoryStatic(
    String encoded,
  ) {
    if (encoded.isEmpty) return [];
    return encoded
        .split('|')
        .where((loc) => loc.isNotEmpty)
        .map((loc) {
          try {
            final parts = loc.split(',');
            if (parts.length < 3) return <String, dynamic>{};
            final lat = double.tryParse(parts[0].trim());
            final lon = double.tryParse(parts[1].trim());
            if (lat == null || lon == null) return <String, dynamic>{};
            return {'lat': lat, 'lon': lon, 'timestamp': parts[2].trim()};
          } catch (e) {
            return <String, dynamic>{};
          }
        })
        .where((loc) => loc.isNotEmpty)
        .toList();
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
    String? photoPath,
    List<String>? photosPaths,
    DateTime? completedAt,
    String? completedBy,
    double? latitude,
    double? longitude,
    String? locationName,
    List<Map<String, dynamic>>? locationHistory,
    DateTime? updatedAt,
    bool? synced,
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
      photoPath: photoPath ?? this.photoPath,
      photosPaths: photosPaths ?? this.photosPaths,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      locationHistory: locationHistory ?? this.locationHistory,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
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
