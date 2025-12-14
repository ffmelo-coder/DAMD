import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../screens/camera_screen.dart';
import 'media_service.dart';

class CameraService {
  static final CameraService instance = CameraService._init();
  CameraService._init();

  List<CameraDescription>? _cameras;
  final _imagePicker = ImagePicker();

  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();
      debugPrint(
        '✅ CameraService: ${_cameras?.length ?? 0} câmera(s) encontrada(s)',
      );
    } catch (e) {
      debugPrint('⚠️ Erro ao inicializar câmera: $e');
      _cameras = [];
    }
  }

  bool get hasCameras => _cameras != null && _cameras!.isNotEmpty;

  Future<String?> takePicture(BuildContext context) async {
    if (!hasCameras) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Nenhuma câmera disponível'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }

    final camera = _cameras!.first;
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await controller.initialize();

      if (!context.mounted) return null;

      final imagePath = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => CameraScreen(controller: controller),
          fullscreenDialog: true,
        ),
      );

      return imagePath;
    } catch (e) {
      debugPrint('❌ Erro ao abrir câmera: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir câmera: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }

      return null;
    } finally {
      controller.dispose();
    }
  }

  Future<String?> pickFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );

      if (image != null) {
        return await savePicture(image);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erro ao selecionar da galeria: $e');
      return null;
    }
  }

  Future<List<String>> pickMultipleFromGallery() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();

      final List<String> savedPaths = [];
      for (final image in images) {
        final savedPath = await savePicture(image);
        savedPaths.add(savedPath);
      }

      return savedPaths;
    } catch (e) {
      debugPrint('❌ Erro ao selecionar múltiplas fotos: $e');
      return [];
    }
  }

  Future<String> savePicture(XFile image) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'task_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savePath = path.join(appDir.path, 'images', fileName);

      final imageDir = Directory(path.join(appDir.path, 'images'));
      if (!await imageDir.exists()) {
        await imageDir.create(recursive: true);
      }

      final savedImage = await File(image.path).copy(savePath);
      debugPrint('✅ Foto salva localmente: ${savedImage.path}');

      // Upload será feito após aplicar/escolher filtro

      return savedImage.path;
    } catch (e) {
      debugPrint('❌ Erro ao salvar foto: $e');
      rethrow;
    }
  }

  Future<void> _uploadToS3InBackground(String imagePath) async {
    try {
      final result = await MediaService.instance.uploadImage(imagePath);
      if (result != null) {
        debugPrint('☁️ Foto enviada para cloud: ${result['key']}');
      } else {
        debugPrint(
          '⚠️ Não foi possível enviar foto para cloud (modo offline?)',
        );
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao enviar foto para cloud: $e');
    }
  }

  Future<void> uploadToCloud(String imagePath) async {
    await _uploadToS3InBackground(imagePath);
  }

  Future<bool> deletePhoto(String photoPath) async {
    try {
      final file = File(photoPath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Erro ao deletar foto: $e');
      return false;
    }
  }

  Future<void> deleteMultiplePhotos(List<String> photoPaths) async {
    for (final photoPath in photoPaths) {
      await deletePhoto(photoPath);
    }
  }
}
