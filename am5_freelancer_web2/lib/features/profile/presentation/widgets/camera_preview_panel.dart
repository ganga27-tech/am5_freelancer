import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraPreviewPanel extends StatelessWidget {
  const CameraPreviewPanel({
    super.key,
    required this.controller,
    required this.capturedImage,
    required this.isInitializing,
    required this.isCapturing,
    required this.errorMessage,
    required this.onCapture,
    required this.onRetake,
  });

  final CameraController? controller;
  final Uint8List? capturedImage;
  final bool isInitializing;
  final bool isCapturing;
  final String? errorMessage;
  final VoidCallback onCapture;
  final VoidCallback onRetake;

  static const Color navy = Color(0xFF142B6F);
  static const Color gold = Color(0xFFD4AF37);
  static const Color borderColor = Color(0xFFE5E9F2);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Desktop: compact camera.
        // Mobile: use the available width.
        final double previewWidth = constraints.maxWidth >= 440
            ? 400
            : constraints.maxWidth;

        final double previewHeight = previewWidth * 0.75;

        return Center(
          child: SizedBox(
            width: previewWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCameraContainer(height: previewHeight),
                const SizedBox(height: 14),
                if (errorMessage != null)
                  _buildErrorMessage()
                else if (capturedImage != null)
                  _buildRetakeButton()
                else
                  _buildCaptureButton(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCameraContainer({required double height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF101828),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: _buildPreview(),
      ),
    );
  }

  Widget _buildPreview() {
    if (isInitializing) {
      return const Center(
        child: CircularProgressIndicator(color: gold, strokeWidth: 3),
      );
    }

    if (errorMessage != null && capturedImage == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.no_photography_outlined,
              color: Colors.white70,
              size: 42,
            ),
            SizedBox(height: 10),
            Text(
              'Camera unavailable',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (capturedImage != null) {
      return Image.memory(
        capturedImage!,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: Colors.white,
              size: 42,
            ),
          );
        },
      );
    }

    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return const Center(
        child: Text(
          'Preparing camera...',
          style: TextStyle(color: Colors.white, fontSize: 13),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Live camera feed.
        CameraPreview(cameraController),

        // Face positioning guide.
        Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double guideWidth = (constraints.maxWidth * 0.48).clamp(
                130.0,
                185.0,
              );

              final double guideHeight = (constraints.maxHeight * 0.76).clamp(
                180.0,
                235.0,
              );

              return Container(
                width: guideWidth,
                height: guideHeight,
                decoration: BoxDecoration(
                  border: Border.all(color: gold, width: 2),
                  borderRadius: BorderRadius.circular(120),
                ),
              );
            },
          ),
        ),

        // Camera guidance.
        Positioned(
          left: 10,
          right: 10,
          bottom: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Text(
              'Position your face inside the guide',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCaptureButton() {
    return SizedBox(
      height: 46,
      child: ElevatedButton.icon(
        onPressed:
            controller != null &&
                controller!.value.isInitialized &&
                !isCapturing &&
                !isInitializing
            ? onCapture
            : null,
        icon: isCapturing
            ? const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.camera_alt_outlined, size: 19),
        label: Text(
          isCapturing ? 'Capturing photo...' : 'Capture photo',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF9AA6C5),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildRetakeButton() {
    return SizedBox(
      height: 46,
      child: OutlinedButton.icon(
        onPressed: isCapturing ? null : onRetake,
        icon: const Icon(Icons.refresh_rounded, size: 19),
        label: const Text(
          'Retake photo',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: navy,
          side: const BorderSide(color: borderColor, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFD6D2)),
      ),
      child: Text(
        errorMessage!,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFFB42318),
          fontSize: 12,
          height: 1.5,
        ),
      ),
    );
  }
}
