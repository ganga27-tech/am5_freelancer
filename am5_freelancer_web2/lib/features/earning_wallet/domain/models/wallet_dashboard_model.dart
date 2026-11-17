class WalletDashboardModel {
  final double walletBalance;
  final double totalEarnings;
  final double pendingRewards;
  final double totalWithdrawn;

  final int totalUsers;
  final int customerInstallations;
  final int vendorInstallations;

  final List<WalletTransaction> transactions;

  const WalletDashboardModel({
    required this.walletBalance,
    required this.totalEarnings,
    required this.pendingRewards,
    required this.totalWithdrawn,
    required this.totalUsers,
    required this.customerInstallations,
    required this.vendorInstallations,
    required this.transactions,
  });

  factory WalletDashboardModel.fromJson(Map<String, dynamic> json) {
    return WalletDashboardModel(
      walletBalance: _toDouble(json['walletBalance']),
      totalEarnings: _toDouble(json['totalEarnings']),
      pendingRewards: _toDouble(json['pendingRewards']),
      totalWithdrawn: _toDouble(json['totalWithdrawn']),
      totalUsers: _toInt(json['totalUsers']),
      customerInstallations: _toInt(json['customerInstallations']),
      vendorInstallations: _toInt(json['vendorInstallations']),
      transactions: _parseTransactions(json['transactions']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<WalletTransaction> _parseTransactions(dynamic value) {
    if (value is! List) return [];

    return value
        .whereType<Map>()
        .map(
          (item) => WalletTransaction.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }
}

class WalletTransaction {
  final String id;
  final String title;
  final String description;
  final double amount;
  final String status;
  final String type;
  final DateTime? createdAt;

  const WalletTransaction({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.status,
    required this.type,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Transaction',
      description: json['description']?.toString() ?? '',
      amount: _parseAmount(json['amount']),
      status: json['status']?.toString() ?? 'pending',
      type: json['type']?.toString() ?? 'earning',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }

  static double _parseAmount(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}
