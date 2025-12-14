import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MediaService {
  MediaService._internal();
  static final MediaService instance = MediaService._internal();

  static const List<String> _candidates = [
    'https://SEU-NGROK-AQUI',
    'http://192.168.15.6:3000',
    'http://10.0.2.2:3000',
    'http://localhost:3000',
  ];

  String? _activeBaseUrl;
  String get _base => _activeBaseUrl ?? _candidates.first;

  Future<bool> detectBackend() async {
    for (final url in _candidates) {
      try {
        final response = await http
            .get(Uri.parse('$url/health'))
            .timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          _activeBaseUrl = url;
          debugPrint('✅ Backend detectado: $_activeBaseUrl');
          return true;
        }
      } catch (e) {
        debugPrint('⚠️ Backend $url não disponível: $e');
      }
    }
    debugPrint('❌ Nenhum backend disponível');
    return false;
  }

  Future<Map<String, dynamic>?> uploadImage(String imagePath) async {
    try {
      debugPrint('📤 Iniciando upload da imagem: $imagePath');

      if (_activeBaseUrl == null) {
        final available = await detectBackend();
        if (!available) {
          debugPrint('❌ Backend não disponível para upload');
          return null;
        }
      }

      final file = File(imagePath);
      if (!await file.exists()) {
        debugPrint('❌ Arquivo não encontrado: $imagePath');
        return null;
      }

      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);
      final fileName = imagePath.split('/').last;

      final payload = {
        'image': base64Image,
        'filename': fileName,
        'contentType': 'image/jpeg',
      };

      debugPrint(
        '📤 Enviando imagem (${bytes.length} bytes) para $_base/api/media/upload',
      );

      final response = await http
          .post(
            Uri.parse('$_base/api/media/upload'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        debugPrint('✅ Upload concluído: ${result['key']}');
        debugPrint('🔗 URL: ${result['url']}');
        return result;
      } else {
        debugPrint(
          '❌ Erro no upload: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('❌ Exceção durante upload: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> uploadMultipleImages(
    List<String> imagePaths,
  ) async {
    final results = <Map<String, dynamic>>[];

    for (final imagePath in imagePaths) {
      final result = await uploadImage(imagePath);
      if (result != null) {
        results.add(result);
      }
    }

    debugPrint(
      '✅ Upload de ${results.length}/${imagePaths.length} imagens concluído',
    );
    return results;
  }

  Future<List<Map<String, dynamic>>> listImages() async {
    try {
      if (_activeBaseUrl == null) {
        await detectBackend();
      }

      final response = await http
          .get(Uri.parse('$_base/api/media/list'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final images = List<Map<String, dynamic>>.from(result['images'] ?? []);
        debugPrint('✅ ${images.length} imagens encontradas no S3');
        return images;
      } else {
        debugPrint('❌ Erro ao listar imagens: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Exceção ao listar imagens: $e');
      return [];
    }
  }

  Future<String?> getImageUrl(String key) async {
    try {
      if (_activeBaseUrl == null) {
        await detectBackend();
      }

      final response = await http
          .get(Uri.parse('$_base/api/media/$key'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['url'];
      } else {
        return null;
      }
    } catch (e) {
      debugPrint('❌ Erro ao obter URL da imagem: $e');
      return null;
    }
  }
}
