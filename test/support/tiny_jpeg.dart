import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// A real, decodable JPEG of [width]×[height] (storyboard sheets are packed
/// from real pictures).
Uint8List tinyJpeg({int width = 16, int height = 9, int shade = 128}) {
  final image = img.Image(width: width, height: height)
    ..clear(img.ColorRgb8(shade, shade ~/ 2, 0));
  return img.encodeJpg(image, quality: 60);
}
