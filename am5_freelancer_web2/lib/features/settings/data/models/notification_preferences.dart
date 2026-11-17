/// Notification preferences for the AM5 ROYAL Freelancer account.
///
/// This model contains user preferences only.
/// It does not make API requests or save data by itself.
class NotificationPreferences {
  const NotificationPreferences({
    required this.earningsAndRewards,
    required this.referralUpdates,
    required this.withdrawalStatus,
  });

  final bool earningsAndRewards;
  final bool referralUpdates;
  final bool withdrawalStatus;

  NotificationPreferences copyWith({
    bool? earningsAndRewards,
    bool? referralUpdates,
    bool? withdrawalStatus,
  }) {
    return NotificationPreferences(
      earningsAndRewards: earningsAndRewards ?? this.earningsAndRewards,
      referralUpdates: referralUpdates ?? this.referralUpdates,
      withdrawalStatus: withdrawalStatus ?? this.withdrawalStatus,
    );
  }

  /// Convert preferences to a JSON-compatible map.
  ///
  /// Confirm the exact field names with the backend developer.
  Map<String, dynamic> toJson() {
    return {
      'earningsAndRewards': earningsAndRewards,
      'referralUpdates': referralUpdates,
      'withdrawalStatus': withdrawalStatus,
    };
  }

  /// Create preferences from a JSON map.
  ///
  /// Confirm the response format with the backend developer.
  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      earningsAndRewards: json['earningsAndRewards'] as bool? ?? true,
      referralUpdates: json['referralUpdates'] as bool? ?? true,
      withdrawalStatus: json['withdrawalStatus'] as bool? ?? true,
    );
  }
}
