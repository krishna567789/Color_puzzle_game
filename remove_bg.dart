import 'dart:io';
import 'package:image/image.dart';

void removeBackground(String inputPath, String outputPath) {
  final bytes = File(inputPath).readAsBytesSync();
  final image = decodeImage(bytes);
  if (image == null) return;

  final newImage = Image(width: image.width, height: image.height, numChannels: 4);

  for (final p in image) {
    final r = p.r;
    final g = p.g;
    final b = p.b;

    // Brightness as max(r, g, b)
    final brightness = [r, g, b].reduce((a, b) => a > b ? a : b);

    if (brightness == 0) {
      newImage.setPixelRgba(p.x, p.y, 0, 0, 0, 0);
    } else {
      final alpha = brightness;
      final nr = (r * 255 ~/ brightness).clamp(0, 255);
      final ng = (g * 255 ~/ brightness).clamp(0, 255);
      final nb = (b * 255 ~/ brightness).clamp(0, 255);
      newImage.setPixelRgba(p.x, p.y, nr, ng, nb, alpha);
    }
  }
  
  // Resize to 256x256
  final resized = copyResize(newImage, width: 256, height: 256);
  
  File(outputPath).writeAsBytesSync(encodePng(resized));
  print('Saved $outputPath');
}

void main() {
  removeBackground('/Users/sigmaitsoftwaredesignerspvtltd/.gemini/antigravity-ide/brain/394ff0ff-423d-418f-88de-3dbde0e9d7a3/3d_star_1787662617405.jpg', 'assets/icon/star_3d.png');
  removeBackground('/Users/sigmaitsoftwaredesignerspvtltd/.gemini/antigravity-ide/brain/394ff0ff-423d-418f-88de-3dbde0e9d7a3/3d_trophy_1787662634376.jpg', 'assets/icon/trophy_3d.png');
}
