import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import '../models/task.dart';
import '../models/category.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tasks.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    String dbPath;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      dbPath = '.';
    } else {
      dbPath = await getDatabasesPath();
    }
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        completed INTEGER NOT NULL,
        priority TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        dueDate TEXT,
        categoryId TEXT,
        reminderTime TEXT,
        photoPath TEXT,
        photosPaths TEXT,
        completedAt TEXT,
        completedBy TEXT,
        latitude REAL,
        longitude REAL,
        locationName TEXT,
        locationHistory TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color TEXT NOT NULL,
        icon TEXT NOT NULL DEFAULT '📋'
      )
    ''');

    final categories = Category.defaultCategories;
    for (final category in categories) {
      await db.insert('categories', category.toMap());
    }
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE tasks ADD COLUMN dueDate TEXT');
    }

    if (oldVersion < 3) {
      await db.execute('ALTER TABLE tasks ADD COLUMN categoryId TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN reminderTime TEXT');

      await db.execute('''
        CREATE TABLE categories (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          color TEXT NOT NULL,
          icon TEXT NOT NULL DEFAULT '📋'
        )
      ''');

      final categories = Category.defaultCategories;
      for (final category in categories) {
        await db.insert('categories', category.toMap());
      }
    }

    if (oldVersion < 4) {
      await db.execute('ALTER TABLE tasks ADD COLUMN photoPath TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN completedAt TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN completedBy TEXT');
    }

    if (oldVersion < 5) {
      await db.execute('ALTER TABLE tasks ADD COLUMN photosPaths TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN latitude REAL');
      await db.execute('ALTER TABLE tasks ADD COLUMN longitude REAL');
      await db.execute('ALTER TABLE tasks ADD COLUMN locationName TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN locationHistory TEXT');
    }
  }

  Future<Task> create(Task task) async {
    final db = await instance.database;
    await db.insert('tasks', task.toMap());
    return task;
  }

  Future<Task?> read(String id) async {
    final db = await instance.database;

    final maps = await db.query(
      'tasks',
      columns: [
        'id',
        'title',
        'description',
        'completed',
        'priority',
        'createdAt',
        'dueDate',
        'categoryId',
        'reminderTime',
      ],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Task.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<List<Task>> readAll() async {
    final db = await instance.database;
    const orderBy = 'createdAt DESC';
    final result = await db.query('tasks', orderBy: orderBy);

    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<List<Task>> searchTasks(String query) async {
    final db = await instance.database;
    final result = await db.query(
      'tasks',
      where: 'title LIKE ? OR description LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'createdAt DESC',
    );

    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<List<Task>> getTasksByStatus(bool completed) async {
    final db = await instance.database;
    final result = await db.query(
      'tasks',
      where: 'completed = ?',
      whereArgs: [completed ? 1 : 0],
      orderBy: 'createdAt DESC',
    );

    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<List<Task>> getTasksByPriority(String priority) async {
    final db = await instance.database;
    final result = await db.query(
      'tasks',
      where: 'priority = ?',
      whereArgs: [priority],
      orderBy: 'createdAt DESC',
    );

    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<List<Task>> getOverdueTasks() async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();

    final result = await db.query(
      'tasks',
      where:
          'dueDate IS NOT NULL AND dueDate != "" AND dueDate < ? AND completed = 0',
      whereArgs: [now],
      orderBy: 'dueDate ASC',
    );

    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<List<Task>> getTasksDueToday() async {
    final db = await instance.database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

    final result = await db.query(
      'tasks',
      where:
          'dueDate IS NOT NULL AND dueDate != "" AND dueDate >= ? AND dueDate <= ? AND completed = 0',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'dueDate ASC',
    );

    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<List<Task>> getTasksByCategory(String categoryId) async {
    final db = await instance.database;
    final result = await db.query(
      'tasks',
      where: 'categoryId = ?',
      whereArgs: [categoryId],
      orderBy: 'createdAt DESC',
    );

    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<Category> createCategory(Category category) async {
    final db = await instance.database;
    await db.insert('categories', category.toMap());
    return category;
  }

  Future<List<Category>> readAllCategories() async {
    final db = await instance.database;
    final result = await db.query('categories');
    return result.map((json) => Category.fromMap(json)).toList();
  }

  Future<Category?> readCategory(String id) async {
    final db = await instance.database;
    final maps = await db.query('categories', where: 'id = ?', whereArgs: [id]);

    if (maps.isNotEmpty) {
      return Category.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateCategory(Category category) async {
    final db = await instance.database;
    return db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(String id) async {
    final db = await instance.database;

    await db.update(
      'tasks',
      {'categoryId': null},
      where: 'categoryId = ?',
      whereArgs: [id],
    );

    return db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>> exportToJson() async {
    final tasks = await readAll();
    final categories = await readAllCategories();

    return {
      'tasks': tasks.map((task) => task.toMap()).toList(),
      'categories': categories.map((category) => category.toMap()).toList(),
    };
  }

  Future<void> importFromJson(Map<String, dynamic> data) async {
    final db = await instance.database;

    await db.transaction((txn) async {
      await txn.delete('tasks');
      await txn.delete('categories');

      if (data['categories'] != null) {
        for (final categoryData in data['categories']) {
          await txn.insert('categories', categoryData);
        }
      } else {
        final categories = Category.defaultCategories;
        for (final category in categories) {
          await txn.insert('categories', category.toMap());
        }
      }

      if (data['tasks'] != null) {
        for (final taskData in data['tasks']) {
          await txn.insert('tasks', taskData);
        }
      }
    });
  }

  Future<int> update(Task task) async {
    final db = await instance.database;

    return db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> delete(String id) async {
    final db = await instance.database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAll() async {
    final db = await instance.database;
    return await db.delete('tasks');
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
