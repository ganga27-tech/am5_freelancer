import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../data/services/face_verification_service.dart';
import '../widgets/camera_preview_panel.dart';

class FaceVerificationScreen extends StatefulWidget {
  const FaceVerificationScreen({super.key});

  static const Color navy = Color(0xFF142B6F);
  static const Color gold = Color(0xFFD4AF37);
  static const Color cream = Color(0xFFFFF8E7);

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;

  final FaceVerificationService _verificationService =
      FaceVerificationService();

  Uint8List? _capturedImage;

  bool _isInitializing = false;
  bool _isCapturing = false;
  bool _isSubmitting = false;
  bool _verificationSubmitted = false;
  bool _isDisposed = false;

  String? _errorMessage;
  String _statusMessage = 'Pending';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  // ---------------------------------------------------------------------------
  // INITIALIZE CAMERA
  // ---------------------------------------------------------------------------

  Future<void> _initializeCamera() async {
    if (!mounted || _isDisposed || _isInitializing) return;
    if (_capturedImage != null) return;

    _isInitializing = true;

    final oldController = _cameraController;
    _cameraController = null;

    if (oldController != null) {
      try {
        await oldController.dispose();
      } catch (error) {
        debugPrint('Previous camera disposal error: $error');
      }
    }

    if (!mounted || _isDisposed) {
      _isInitializing = false;
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    CameraController? newController;

    try {
      final cameras = await availableCameras();

      if (!mounted || _isDisposed) return;

      if (cameras.isEmpty) {
        throw Exception('No camera was found.');
      }

      CameraDescription selectedCamera = cameras.first;

      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          selectedCamera = camera;
          break;
        }
      }

      newController = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      _cameraController = newController;

      await newController.initialize();

      if (!mounted || _isDisposed || _cameraController != newController) {
        await newController.dispose();
        return;
      }

      setState(() {
        _errorMessage = null;
      });
    } catch (error) {
      debugPrint('Camera initialization error: $error');

      if (newController != null) {
        if (_cameraController == newController) {
          _cameraController = null;
        }

        try {
          await newController.dispose();
        } catch (disposeError) {
          debugPrint('Camera cleanup error: $disposeError');
        }
      }

      if (mounted && !_isDisposed) {
        setState(() {
          _errorMessage =
              'Unable to open camera. Please allow camera permission '
              'and try again.';
        });
      }
    } finally {
      _isInitializing = false;

      if (mounted && !_isDisposed) {
        setState(() {});
      }
    }
  }

  // ---------------------------------------------------------------------------
  // RELEASE CAMERA
  // ---------------------------------------------------------------------------

  Future<void> _releaseCamera() async {
    final controller = _cameraController;
    _cameraController = null;

    if (controller == null) return;

    try {
      await controller.dispose();
      debugPrint('Camera controller disposed successfully.');
    } catch (error) {
      debugPrint('Camera disposal error: $error');
    }
  }

  // ---------------------------------------------------------------------------
  // APP LIFECYCLE
  // ---------------------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _releaseCamera();
    } else if (state == AppLifecycleState.resumed &&
        mounted &&
        !_isDisposed &&
        _capturedImage == null) {
      _initializeCamera();
    }
  }

  // ---------------------------------------------------------------------------
  // CAPTURE PHOTO
  // ---------------------------------------------------------------------------

  Future<void> _capturePhoto() async {
    final controller = _cameraController;

    if (controller == null ||
        !controller.value.isInitialized ||
        _isCapturing ||
        _isSubmitting ||
        _isInitializing) {
      return;
    }

    setState(() {
      _isCapturing = true;
      _errorMessage = null;
    });

    try {
      final image = await controller.takePicture();
      final bytes = await image.readAsBytes();

      if (bytes.isEmpty) {
        throw Exception('Captured photo is empty.');
      }

      if (!mounted || _isDisposed) return;

      await _releaseCamera();

      if (!mounted || _isDisposed) return;

      setState(() {
        _capturedImage = bytes;
        _isCapturing = false;
        _statusMessage = 'Pending';
      });
    } catch (error) {
      debugPrint('Photo capture error: $error');

      if (!mounted || _isDisposed) return;

      setState(() {
        _isCapturing = false;
        _errorMessage = 'Could not capture photo. Please try again.';
      });
    } finally {
      if (mounted && !_isDisposed && _isCapturing) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // RETAKE PHOTO
  // ---------------------------------------------------------------------------

  Future<void> _retakePhoto() async {
    if (_isSubmitting || _isDisposed) return;

    setState(() {
      _capturedImage = null;
      _verificationSubmitted = false;
      _statusMessage = 'Pending';
      _errorMessage = null;
    });

    await _initializeCamera();
  }

  // ---------------------------------------------------------------------------
  // SUBMIT PHOTO
  // ---------------------------------------------------------------------------

  Future<void> _submitPhoto() async {
    final imageBytes = _capturedImage;

    if (imageBytes == null || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _statusMessage = 'Pending';
    });

    try {
      final result = await _verificationService.submitForVerification(
        imageBytes: imageBytes,
      );

      if (!mounted || _isDisposed) return;

      setState(() {
        _isSubmitting = false;
        _statusMessage = result.status.name.toUpperCase();
        _verificationSubmitted =
            result.status == FaceVerificationStatus.verified;
      });

      _showMessage(result.message);
    } catch (error) {
      debugPrint('Verification submission error: $error');

      if (!mounted || _isDisposed) return;

      setState(() {
        _isSubmitting = false;
        _statusMessage = 'PENDING';
        _errorMessage = 'Unable to submit photo. Please try again later.';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // MESSAGE
  // ---------------------------------------------------------------------------

  void _showMessage(String message) {
    if (!mounted || _isDisposed) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  // ---------------------------------------------------------------------------
  // BACK TO PROFILE
  // ---------------------------------------------------------------------------

  Future<void> _finish() async {
    if (_isSubmitting) return;

    await _releaseCamera();

    if (!mounted || _isDisposed) return;

    Navigator.of(context).pop(_verificationSubmitted);
  }

  // ---------------------------------------------------------------------------
  // DISPOSE
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);

    final controller = _cameraController;
    _cameraController = null;

    if (controller != null) {
      controller.dispose();
    }
    _verificationService.dispose();

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: FaceVerificationScreen.navy,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 28,
        title: const Text(
          'Identity Verification',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE9ECF2)),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 800;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 32 : 16,
                vertical: isDesktop ? 22 : 16,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1050),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isDesktop ? 28 : 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE6E9F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x080D1B3E),
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: isDesktop
                        ? _buildDesktopContent()
                        : _buildMobileContent(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DESKTOP CONTENT
  // ---------------------------------------------------------------------------

  Widget _buildDesktopContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.only(top: 12, right: 28),
            child: _buildIntroduction(),
          ),
        ),
        Container(
          width: 1,
          height: 440,
          color: const Color(0xFFE9ECF2),
          margin: const EdgeInsets.symmetric(horizontal: 8),
        ),
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.only(left: 24),
            child: _buildVerificationContent(compact: true),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // MOBILE CONTENT
  // ---------------------------------------------------------------------------

  Widget _buildMobileContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildIntroduction(),
        const SizedBox(height: 22),
        _buildVerificationContent(compact: false),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // INTRODUCTION
  // ---------------------------------------------------------------------------

  Widget _buildIntroduction() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF1FC),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.face_retouching_natural_outlined,
            color: FaceVerificationScreen.navy,
            size: 30,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Verify your identity',
          style: TextStyle(
            color: FaceVerificationScreen.navy,
            fontSize: 27,
            height: 1.2,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Take a clear photo of your face to continue with '
          'your freelancer profile verification.',
          style: TextStyle(color: Color(0xFF68758A), fontSize: 14, height: 1.7),
        ),
        const SizedBox(height: 24),
        _buildTip(Icons.light_mode_outlined, 'Choose a well-lit place'),
        const SizedBox(height: 14),
        _buildTip(Icons.face_outlined, 'Keep your face inside the guide'),
        const SizedBox(height: 14),
        _buildTip(
          Icons.visibility_outlined,
          'Remove anything covering your face',
        ),
        const SizedBox(height: 26),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFAEB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF0E4BD)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.shield_outlined,
                color: FaceVerificationScreen.navy,
                size: 21,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your photo should be clear and captured '
                  'directly using your camera.',
                  style: TextStyle(
                    color: FaceVerificationScreen.navy,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTip(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: FaceVerificationScreen.navy),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF475467),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // CAMERA AND VERIFICATION CONTENT
  // ---------------------------------------------------------------------------

  Widget _buildVerificationContent({required bool compact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Camera preview',
                style: TextStyle(
                  color: FaceVerificationScreen.navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5D8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: Color(0xFFC29B27), size: 8),
                  SizedBox(width: 6),
                  Text(
                    'Camera',
                    style: TextStyle(
                      color: FaceVerificationScreen.navy,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        CameraPreviewPanel(
          controller: _cameraController,
          capturedImage: _capturedImage,
          isInitializing: _isInitializing,
          isCapturing: _isCapturing,
          errorMessage: _errorMessage,
          onCapture: _capturePhoto,
          onRetake: _retakePhoto,
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],

        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5EAF4)),
          ),
          child: Row(
            children: [
              Icon(
                _statusMessage.toUpperCase() == 'VERIFIED'
                    ? Icons.check_circle_outline_rounded
                    : Icons.info_outline_rounded,
                color: FaceVerificationScreen.navy,
                size: 20,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Status: $_statusMessage',
                  style: const TextStyle(
                    color: FaceVerificationScreen.navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_capturedImage != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitPhoto,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_outlined, size: 19),
              label: Text(
                _isSubmitting ? 'Submitting...' : 'Submit for verification',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: FaceVerificationScreen.navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 42,
            child: OutlinedButton.icon(
              onPressed: _isSubmitting ? null : _retakePhoto,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retake photo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: FaceVerificationScreen.navy,
                side: const BorderSide(color: Color(0xFFD8DEEB)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
          ),
        ] else if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isInitializing ? null : _initializeCamera,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry camera'),
          ),
        ],

        const SizedBox(height: 12),
        const Text(
          'Photo capture alone does not verify your identity. '
          'Backend verification must be connected.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF7A8495), fontSize: 11, height: 1.5),
        ),
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: _isSubmitting ? null : _finish,
            child: const Text('Back to profile'),
          ),
        ),
      ],
    );
  }
}
