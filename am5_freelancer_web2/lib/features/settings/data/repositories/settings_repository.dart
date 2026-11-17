import '../models/notification_preferences.dart';

/// Contract for Settings-related operations.
///
/// Implement this interface when the backend API details are available.
///
/// Keeping API operations outside the UI makes the feature easier
/// to test, maintain and hand over to another developer.
abstract class SettingsRepository {
  /// Retrieve the current notification preferences.
  Future<NotificationPreferences> getNotificationPreferences();

  /// Save notification preferences.
  Future<NotificationPreferences> saveNotificationPreferences(
    NotificationPreferences preferences,
  );

  /// Change the user's password.
  ///
  /// The implementation must use the backend's required request format.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Log out the current user.
  ///
  /// The implementation must follow the app's authentication flow.
  Future<void> logout();
}

/// Placeholder implementation for development before API integration.
///
/// This class intentionally does not pretend to save data remotely.
/// Replace it with a real API-backed implementation on Monday.
class UnconfiguredSettingsRepository implements SettingsRepository {
  const UnconfiguredSettingsRepository();

  @override
  Future<NotificationPreferences> getNotificationPreferences() {
    throw UnimplementedError(
      'Notification preferences API has not been configured.',
    );
  }

  @override
  Future<NotificationPreferences> saveNotificationPreferences(
    NotificationPreferences preferences,
  ) {
    throw UnimplementedError(
      'Save notification preferences API has not been configured.',
    );
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    throw UnimplementedError('Change password API has not been configured.');
  }

  @override
  Future<void> logout() {
    throw UnimplementedError(
      'Logout has not been connected to the authentication flow.',
    );
  }
}
