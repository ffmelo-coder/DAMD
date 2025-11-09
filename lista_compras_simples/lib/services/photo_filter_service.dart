import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

enum PhotoFilter {
  none,
  grayscale,
  sepia,
  invert,
  brightness,
  contrast,
  blur,
  sharpen,
}

class PhotoFilterService {
  static final PhotoFilterService instance = PhotoFilterService._init();
  PhotoFilterService._init();

  Future<String> applyFilter(String imagePath, PhotoFilter filter) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      img.Image? image = img.decodeImage(bytes);

      if (image == null) return imagePath;

      switch (filter) {
        case PhotoFilter.none:
          break;
        case PhotoFilter.grayscale:
          image = img.grayscale(image);
          break;
        case PhotoFilter.sepia:
          image = _applySepia(image);
          break;
        case PhotoFilter.invert:
          image = img.invert(image);
          break;
        case PhotoFilter.brightness:
          image = img.adjustColor(image, brightness: 1.2);
          break;
        case PhotoFilter.contrast:
          image = img.adjustColor(image, contrast: 1.3);
          break;
        case PhotoFilter.blur:
          image = img.gaussianBlur(image, radius: 3);
          break;
        case PhotoFilter.sharpen:
          image = img.convolution(
            image,
            filter: [0, -1, 0, -1, 5, -1, 0, -1, 0],
          );
          break;
      }

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'filtered_$timestamp.jpg';
      final filePath = path.join(directory.path, fileName);

      final filteredFile = File(filePath);
      await filteredFile.writeAsBytes(img.encodeJpg(image, quality: 85));

      return filePath;
    } catch (e) {
      print('❌ Erro ao aplicar filtro: $e');
      return imagePath;
    }
  }

  img.Image _applySepia(img.Image image) {
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();

        final tr = ((r * 0.393) + (g * 0.769) + (b * 0.189))
            .clamp(0, 255)
            .toInt();
        final tg = ((r * 0.349) + (g * 0.686) + (b * 0.168))
            .clamp(0, 255)
            .toInt();
        final tb = ((r * 0.272) + (g * 0.534) + (b * 0.131))
            .clamp(0, 255)
            .toInt();

        image.setPixelRgba(x, y, tr, tg, tb, pixel.a.toInt());
      }
    }
    return image;
  }

  Future<Uint8List?> getFilterPreview(
    String imagePath,
    PhotoFilter filter,
  ) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      img.Image? image = img.decodeImage(bytes);

      if (image == null) return null;

      image = img.copyResize(image, width: 200);

      switch (filter) {
        case PhotoFilter.none:
          break;
        case PhotoFilter.grayscale:
          image = img.grayscale(image);
          break;
        case PhotoFilter.sepia:
          image = _applySepia(image);
          break;
        case PhotoFilter.invert:
          image = img.invert(image);
          break;
        case PhotoFilter.brightness:
          image = img.adjustColor(image, brightness: 1.2);
          break;
        case PhotoFilter.contrast:
          image = img.adjustColor(image, contrast: 1.3);
          break;
        case PhotoFilter.blur:
          image = img.gaussianBlur(image, radius: 3);
          break;
        case PhotoFilter.sharpen:
          image = img.convolution(
            image,
            filter: [0, -1, 0, -1, 5, -1, 0, -1, 0],
          );
          break;
      }

      return Uint8List.fromList(img.encodeJpg(image, quality: 80));
    } catch (e) {
      return null;
    }
  }

  String getFilterName(PhotoFilter filter) {
    switch (filter) {
      case PhotoFilter.none:
        return 'Original';
      case PhotoFilter.grayscale:
        return 'Preto e Branco';
      case PhotoFilter.sepia:
        return 'Sépia';
      case PhotoFilter.invert:
        return 'Inverter';
      case PhotoFilter.brightness:
        return 'Brilho';
      case PhotoFilter.contrast:
        return 'Contraste';
      case PhotoFilter.blur:
        return 'Desfoque';
      case PhotoFilter.sharpen:
        return 'Nitidez';
    }
  }
}
