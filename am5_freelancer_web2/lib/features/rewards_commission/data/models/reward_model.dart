class RewardModel {
  final String id;
  final String title;
  final String type;
  final String description;
  final double amount;
  final String status;
  final DateTime? createdAt;

  const RewardModel({
    required this.id,
    required this.title,
    required this.type,
    required this.description,
    required this.amount,
    required this.status,
    this.createdAt,
  });

  factory RewardModel.fromJson(Map<String, dynamic> json) {
    return RewardModel(
      id: (json['reward_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Reward').toString(),
      type: (json['reward_type'] ?? json['type'] ?? 'Reward').toString(),
      description: (json['description'] ?? json['reference_id'] ?? '')
          .toString(),
      amount: _toDouble(json['amount']),
      status: (json['status'] ?? 'pending').toString().toLowerCase(),
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
