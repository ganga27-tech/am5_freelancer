import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:am5_freelancer_web/core/constants/api_constants.dart';

void main() {
  group('API base URL selection', () {
    test('release builds default to the HTTPS production API', () {
      expect(
        ApiConstants.resolveBaseUrl(
          override: '',
          isRelease: true,
          isWeb: false,
          platform: TargetPlatform.android,
        ),
        'https://api.am5royal.com',
      );
    });

    test('Android debug builds use the local backend on port 8001', () {
      expect(
        ApiConstants.resolveBaseUrl(
          override: '',
          isRelease: false,
          isWeb: false,
          platform: TargetPlatform.android,
        ),
        'http://10.0.2.2:8001',
      );
    });

    test('desktop and web debug builds use localhost on port 8001', () {
      expect(
        ApiConstants.resolveBaseUrl(
          override: '',
          isRelease: false,
          isWeb: false,
          platform: TargetPlatform.windows,
        ),
        'http://127.0.0.1:8001',
      );
      expect(
        ApiConstants.resolveBaseUrl(
          override: '',
          isRelease: false,
          isWeb: true,
          platform: TargetPlatform.android,
        ),
        'http://127.0.0.1:8001',
      );
    });

    test('explicit environment overrides are preserved', () {
      expect(
        ApiConstants.resolveBaseUrl(
          override: 'https://staging.example.test/',
          isRelease: true,
          isWeb: true,
          platform: TargetPlatform.windows,
        ),
        'https://staging.example.test/',
      );
    });
  });
}
