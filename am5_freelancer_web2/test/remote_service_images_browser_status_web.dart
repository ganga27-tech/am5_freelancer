import 'package:web/web.dart' as web;

int loadedServiceImageCount() {
  final images = web.document.querySelectorAll('img[alt]');
  var loaded = 0;

  for (var index = 0; index < images.length; index++) {
    final image = images.item(index) as web.HTMLImageElement?;
    if (image != null && image.alt.isNotEmpty && image.naturalWidth > 0) {
      loaded++;
    }
  }

  return loaded;
}
