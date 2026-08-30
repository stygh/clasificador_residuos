import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

abstract final class ImageUtils {
  static const int maxDimension = 1024;
  static const int jpegQuality = 85;

  static Future<File> optimize(File source) async {
    final Uint8List originalBytes = await source.readAsBytes();
    if (originalBytes.isEmpty) {
      throw const FormatException('La imagen está vacía.');
    }

    final Uint8List optimizedBytes = await compute(
      _resizeAndEncodeJpeg,
      originalBytes,
    );

    final Directory tempDirectory = await getTemporaryDirectory();
    final String filename =
        'residuo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final File output = File('${tempDirectory.path}/$filename');
    await output.writeAsBytes(optimizedBytes, flush: true);
    return output;
  }
}

Uint8List _resizeAndEncodeJpeg(Uint8List bytes) {
  final img.Image? decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('El archivo no contiene una imagen válida.');
  }

  final img.Image oriented = img.bakeOrientation(decoded);
  final bool landscape = oriented.width >= oriented.height;
  final bool needsResize = landscape
      ? oriented.width > ImageUtils.maxDimension
      : oriented.height > ImageUtils.maxDimension;

  final img.Image resized = needsResize
      ? img.copyResize(
          oriented,
          width: landscape ? ImageUtils.maxDimension : null,
          height: landscape ? null : ImageUtils.maxDimension,
          interpolation: img.Interpolation.average,
        )
      : oriented;

  return Uint8List.fromList(
    img.encodeJpg(resized, quality: ImageUtils.jpegQuality),
  );
}
