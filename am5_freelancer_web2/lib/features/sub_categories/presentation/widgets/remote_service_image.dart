import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'remote_service_image_web_stub.dart'
    if (dart.library.js_interop) 'remote_service_image_web.dart'
    as web_image;

/// Renders service artwork from the image URL returned by the services API.
///
/// Flutter Web uses a browser-native `<img>` element so public image hosts do
/// not need to allow cross-origin XHR. Native Flutter platforms decode SVGs
/// with flutter_svg and raster formats with Image.network.
class RemoteServiceImage extends StatefulWidget {
  const RemoteServiceImage({
    super.key,
    required this.url,
    required this.label,
    this.fit = BoxFit.contain,
    this.backgroundColor = const Color(0xFFF0F7FF),
    this.foregroundColor = const Color(0xFF2449A5),
    this.indicatorSize = 25,
    this.fallbackIconSize = 30,
  });

  final String url;
  final String label;
  final BoxFit fit;
  final Color backgroundColor;
  final Color foregroundColor;
  final double indicatorSize;
  final double fallbackIconSize;

  @override
  State<RemoteServiceImage> createState() => _RemoteServiceImageState();
}

class _RemoteServiceImageState extends State<RemoteServiceImage> {
  late bool _loading;
  late bool _failed;
  int _attempt = 0;
  bool _statusCallbackScheduled = false;

  Uri? get _uri {
    final uri = Uri.tryParse(widget.url.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      return null;
    }
    return uri;
  }

  bool get _isSvg => _uri?.path.toLowerCase().endsWith('.svg') ?? false;

  @override
  void initState() {
    super.initState();
    _loading = _uri != null;
    _failed = !_loading;
  }

  @override
  void didUpdateWidget(covariant RemoteServiceImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _loading = _uri != null;
      _failed = !_loading;
      _attempt = 0;
      _statusCallbackScheduled = false;
    }
  }

  void _markLoaded() {
    if (!mounted || (!_loading && !_failed)) return;
    setState(() {
      _loading = false;
      _failed = false;
    });
  }

  void _markFailed() {
    if (!mounted || (_failed && !_loading)) return;
    setState(() {
      _loading = false;
      _failed = true;
    });
  }

  void _scheduleStatus({required bool loaded}) {
    if (_statusCallbackScheduled) return;
    _statusCallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _statusCallbackScheduled = false;
      if (loaded) {
        _markLoaded();
      } else {
        _markFailed();
      }
    });
  }

  void _retry() {
    if (_uri == null) return;
    setState(() {
      _attempt++;
      _loading = true;
      _failed = false;
    });
  }

  Widget _buildNativeImage() {
    final uri = _uri!;
    if (_isSvg) {
      return SvgPicture.network(
        uri.toString(),
        fit: widget.fit,
        alignment: Alignment.center,
        semanticsLabel: widget.label,
        placeholderBuilder: (_) => const SizedBox.expand(),
        imageBuilder: (context, child) {
          _scheduleStatus(loaded: true);
          return child;
        },
        errorBuilder: (context, error, stackTrace) {
          _scheduleStatus(loaded: false);
          return const SizedBox.expand();
        },
      );
    }

    return Image.network(
      uri.toString(),
      fit: widget.fit,
      alignment: Alignment.center,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame != null || wasSynchronouslyLoaded) {
          _scheduleStatus(loaded: true);
        }
        return child;
      },
      errorBuilder: (context, error, stackTrace) {
        _scheduleStatus(loaded: false);
        return const SizedBox.expand();
      },
    );
  }

  Widget _buildFailure() {
    return ColoredBox(
      color: widget.backgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: widget.fallbackIconSize,
              color: widget.foregroundColor,
            ),
            const SizedBox(height: 2),
            TextButton(
              onPressed: _uri == null ? null : _retry,
              style: TextButton.styleFrom(
                minimumSize: const Size(32, 24),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: widget.foregroundColor,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Retry', style: TextStyle(fontSize: 10)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isValid = _uri != null;

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isValid)
            kIsWeb
                ? web_image.buildWebServiceImage(
                    key: ValueKey<int>(_attempt),
                    url: _uri.toString(),
                    label: widget.label,
                    fit: widget.fit,
                    onLoad: _markLoaded,
                    onError: _markFailed,
                  )
                : KeyedSubtree(
                    key: ValueKey<int>(_attempt),
                    child: _buildNativeImage(),
                  )
          else
            _buildFailure(),
          if (_loading)
            ColoredBox(
              color: widget.backgroundColor,
              child: Center(
                child: SizedBox(
                  width: widget.indicatorSize,
                  height: widget.indicatorSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.foregroundColor,
                  ),
                ),
              ),
            ),
          if (_failed && isValid) _buildFailure(),
        ],
      ),
    );
  }
}
