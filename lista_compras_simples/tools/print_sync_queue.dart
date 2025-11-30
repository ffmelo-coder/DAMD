import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

void main() async {
  try {
    sqfliteFfiInit();
    
    final candidate = 'tasks_device.db';
    final filePath = await (() async {
      final f = File(candidate);
      if (await f.exists()) return f.absolute.path;
      final f2 = File('tasks.db');
      return (await f2.exists()) ? f2.absolute.path : candidate;
    })();
    print('Opening DB: $filePath');
    final db = await databaseFactoryFfi.openDatabase(filePath);

    print('=== tables in DB ===');
    final tables = await db.rawQuery(
      "SELECT name, sql FROM sqlite_master WHERE type='table';",
    );
    for (final t in tables) {
      print(t);
    }

    print('\n=== sync_queue (id, taskId, action, timestamp) ===');
    
    final hasSyncQueue = tables.any(
      (t) => (t['name'] as String?) == 'sync_queue',
    );
    if (hasSyncQueue) {
      final syncRows = await db.rawQuery(
        'SELECT id, taskId, action, timestamp, payload FROM sync_queue ORDER BY id;',
      );
      if (syncRows.isEmpty) {
        print('(empty)');
      } else {
        for (final r in syncRows) print(r);
      }
    } else {
      print('(no sync_queue table present)');
    }

    print('\n=== pending tasks (id, title, synced, updatedAt) ===');
    final pending = await db.rawQuery(
      "SELECT id, title, synced, updatedAt FROM tasks WHERE synced = 0 ORDER BY updatedAt DESC;",
    );
    if (pending.isEmpty) {
      print('(none)');
    } else {
      for (final r in pending) {
        print(r);
      }
    }

    await db.close();
  } catch (e) {
    print('ERROR: $e');
  }
}
