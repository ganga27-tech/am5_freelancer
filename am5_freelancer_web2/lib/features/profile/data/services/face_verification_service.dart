import 'dart:typed_data';

import '../../../../core/network/freelance_api.dart';

enum FaceVerificationStatus { pending, verified, failed }

class FaceVerificationResult {
  const FaceVerificationResult({
    required this.status,
    required this.message,
    this.referenceId,
  });
  final FaceVerificationStatus status;
  final String message;
  final String? referenceId;
}

/// Starts the backend verification session. The backend response includes
/// provider SDK configuration; a verified state is reported only by backend.
class FaceVerificationService {
  FaceVerificationService({FreelanceApi? api})
    : _api = api ?? FreelanceApi(),
      _ownsApi = api == null;
  final FreelanceApi _api;
  final bool _ownsApi;

  Future<FaceVerificationResult> submitForVerification({
    required Uint8List imageBytes,
  }) async {
    if (imageBytes.isEmpty) throw ArgumentError('Captured image is empty.');
    final response = await _api.faceVerificationStart(consent: true);
    final status = (response['status']?.toString() ?? 'PENDING').toLowerCase();
    return FaceVerificationResult(
      status: status == 'verified'
          ? FaceVerificationStatus.verified
          : status == 'failed'
          ? FaceVerificationStatus.failed
          : FaceVerificationStatus.pending,
      message: status == 'verified' ? 'Face verification completed.' : 'Verification session created. Complete the identity provider check to finish verification.',
      referenceId: response['verification_id']?.toString(),
    );
  }

  void dispose() {
    if (_ownsApi) _api.dispose();
  }
}
