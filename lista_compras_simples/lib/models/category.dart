import 'package:uuid/uuid.dart';

class Category {
  final String id;
  final String name;
  final String color;
  final String icon;

  Category({
    String? id,
    required this.name,
    required this.color,
    this.icon = '📋',
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'color': color, 'icon': icon};
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      color: map['color'],
      icon: map['icon'] ?? '📋',
    );
  }

  Category copyWith({String? name, String? color, String? icon}) {
    return Category(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
    );
  }

  // Categorias padrão
  static List<Category> getDefaultCategories() {
    return [
      Category(id: 'default', name: 'Geral', color: '#2196F3', icon: '📋'),
      Category(id: 'work', name: 'Trabalho', color: '#FF9800', icon: '💼'),
      Category(id: 'personal', name: 'Pessoal', color: '#4CAF50', icon: '👤'),
      Category(id: 'shopping', name: 'Compras', color: '#9C27B0', icon: '🛒'),
      Category(id: 'health', name: 'Saúde', color: '#F44336', icon: '🏥'),
      Category(id: 'study', name: 'Estudos', color: '#795548', icon: '📚'),
    ];
  }
}
