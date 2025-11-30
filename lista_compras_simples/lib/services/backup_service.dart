import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'database_service.dart';

class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  final DatabaseService _databaseService = DatabaseService.instance;

  Future<String?> exportToJson() async {
    try {
      final data = await _databaseService.exportToJson();
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/backup_tarefas_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      await file.writeAsString(jsonString);
      return file.path;
    } catch (e) {
      debugPrint('Erro ao exportar tarefas: $e');
      return null;
    }
  }

  Future<String?> exportToDeviceStorage() async {
    try {
      final data = await _databaseService.exportToJson();
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Salvar backup das tarefas',
        fileName: 'backup_tarefas_.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result != null) {
        final file = File(result);
        await file.writeAsString(jsonString);
        return result;
      }
      return null;
    } catch (e) {
      debugPrint('Erro ao exportar para armazenamento: $e');
      return null;
    }
  }

  Future<bool> shareBackup() async {
    try {
      final filePath = await exportToJson();
      if (filePath != null) {
        await Share.shareXFiles([XFile(filePath)], text: 'Backup das tarefas');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Erro ao compartilhar backup: $e');
      return false;
    }
  }

  Future<bool> importFromJson() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Selecionar arquivo de backup',
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonString = await file.readAsString();
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        await _databaseService.importFromJson(data);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Erro ao importar: $e');
      return false;
    }
  }

  Future<void> createAutoBackup() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final data = await _databaseService.exportToJson();
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      final file = File(
        '${directory.path}/auto_backup_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint('Erro no backup automático: $e');
    }
  }

  Future<List<File>> getAvailableBackups() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory(directory.path);
      final files = await backupDir
          .list()
          .where((entity) {
            return entity is File &&
                entity.path.contains('backup_tarefas_') &&
                entity.path.endsWith('.json');
          })
          .cast<File>()
          .toList();
      files.sort(
        (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
      );
      return files;
    } catch (e) {
      debugPrint('Erro ao listar backups: $e');
      return [];
    }
  }

  Future<bool> restoreFromBackup(File backupFile) async {
    try {
      final jsonString = await backupFile.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      await _databaseService.importFromJson(data);
      return true;
    } catch (e) {
      debugPrint('Erro ao restaurar backup: $e');
      return false;
    }
  }
}
