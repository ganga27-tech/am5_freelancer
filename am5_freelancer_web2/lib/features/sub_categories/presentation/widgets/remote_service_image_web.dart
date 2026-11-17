import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

Widget buildWebServiceImage({
  required Key key,
  required String url,
  required String label,
  required BoxFit fit,
  required VoidCallback onLoad,
  required VoidCallback onError,
}) {
  return HtmlElementView.fromTagName(
    key: key,
    tagName: 'img',
    onElementCreated: (element) {
      final createdImage = element as web.HTMLImageElement;
      createdImage
        ..alt = label
        ..decoding = 'async'
        ..draggable = false
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'block'
        ..style.objectFit = _cssFit(fit)
        ..style.objectPosition = 'center'
        ..style.pointerEvents = 'none';
      createdImage.addEventListener('load', ((web.Event _) => onLoad()).toJS);
      createdImage.addEventListener('error', ((web.Event _) => onError()).toJS);
      createdImage.src = url;
    },
  );
}

String _cssFit(BoxFit fit) => switch (fit) {
  BoxFit.fill => 'fill',
  BoxFit.contain => 'contain',
  BoxFit.cover => 'cover',
  BoxFit.fitWidth => 'cover',
  BoxFit.fitHeight => 'cover',
  BoxFit.none => 'none',
  BoxFit.scaleDown => 'scale-down',
};
