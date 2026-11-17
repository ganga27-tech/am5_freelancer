import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/freelance_api.dart';
import '../../../../core/widgets/section_hero_banner.dart';

class EarningWalletScreen extends StatefulWidget {
  const EarningWalletScreen({super.key, @visibleForTesting this.api});

  @visibleForTesting
  final FreelanceApi? api;

  static const Color navy = Color(0xFF101D45);
  static const Color blue = Color(0xFF2449A5);
  static const Color gold = Color(0xFFFFC857);
  static const Color background = Color(0xFFFFF8ED);
  static const Color text = Color(0xFF17233F);
  static const Color grey = Color(0xFF778198);
  static const Color border = Color(0xFFE2E9F7);
  static const Color green = Color(0xFF16866B);

  @override
  State<EarningWalletScreen> createState() => _EarningWalletScreenState();
}

class _EarningWalletScreenState extends State<EarningWalletScreen> {
  double? availableBalance;
  double? totalEarnings;
  double? pendingRewards;
  double? processingBalance;
  double? totalWithdrawn;
  int? _totalInstallations;
  int? _eligibleInstallations;
  int? _processingInstallationRewards;
  int? _completedInstallationRewards;
  String? _installationError;
  bool _walletLoading = true;
  String? _walletError;
  List<Map<String, dynamic>> _transactions = const [];
  late final FreelanceApi _api = widget.api ?? FreelanceApi();

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  @override
  void dispose() {
    if (widget.api == null) _api.dispose();
    super.dispose();
  }

  Future<void> _loadWallet() async {
    setState(() {
      _walletLoading = true;
      _walletError = null;
    });
    try {
      final summary = await _api.walletSummary();
      final transactions = await _api.walletTransactions(limit: 10);
      final payload = transactions['items'];
      if (!mounted) return;
      setState(() {
        availableBalance = _number(summary['available_balance']);
        totalEarnings = _number(summary['total_earnings']);
        pendingRewards = _number(summary['pending_balance']);
        processingBalance = _number(summary['processing_balance']);
        totalWithdrawn = _number(summary['total_withdrawn']);
        _transactions = payload is List
            ? payload
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
            : const [];
        _walletLoading = false;
      });
      await _loadInstallationSummary();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _walletLoading = false;
        _walletError = error.message;
      });
    }
  }

  Future<void> _loadInstallationSummary() async {
    try {
      final statistics = await _api.installationStatistics();
      final statuses = await _api.installationStatus();
      final rows = statuses.whereType<Map>().toList(growable: false);
      final processing = rows.where((row) {
        final status = row['status']?.toString().toLowerCase();
        return status == 'pending' || status == 'processing';
      }).length;
      final completed = rows.where((row) {
        final status = row['status']?.toString().toLowerCase();
        return status == 'paid' || status == 'claimed';
      }).length;
      if (!mounted) return;
      setState(() {
        _totalInstallations =
            _int(statistics['customer_installs']) +
            _int(statistics['vendor_installs']);
        _eligibleInstallations =
            _int(statistics['customer_eligible']) +
            _int(statistics['vendor_eligible']);
        _processingInstallationRewards = processing;
        _completedInstallationRewards = completed;
        _installationError = null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _installationError = error.message);
    }
  }

  int _int(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  double? _number(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');

  String money(double? value) {
    if (value == null) return '—';
    return '₹${value.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: EarningWalletScreen.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 700;

          return SingleChildScrollView(
            padding: EdgeInsets.all(mobile ? 16 : 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_walletError != null)
                  MaterialBanner(
                    content: Text(_walletError!),
                    leading: const Icon(Icons.cloud_off_outlined),
                    actions: [
                      TextButton(
                        onPressed: _loadWallet,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                if (_walletLoading) const LinearProgressIndicator(),
                SectionHeroBanner(
                  title: 'Earnings & Wallet',
                  subtitle: 'Track your earnings, rewards and wallet activity.',
                  icon: Icons.account_balance_wallet_rounded,
                  imageAsset: 'assets/images/benefits/online_earning.png',
                ),

                const SizedBox(height: 24),

                _buildBalanceCard(mobile),

                const SizedBox(height: 28),

                _sectionHeading(
                  'Earnings Overview',
                  'A summary of your rewards and payouts.',
                ),

                const SizedBox(height: 16),

                _buildSummaryGrid(),

                const SizedBox(height: 28),

                _sectionHeading(
                  'Installation Overview',
                  'Track your installation referral activity.',
                ),

                const SizedBox(height: 16),

                if (_installationError != null)
                  MaterialBanner(
                    content: Text(_installationError!),
                    leading: const Icon(Icons.cloud_off_outlined),
                    actions: [
                      TextButton(
                        onPressed: _loadInstallationSummary,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),

                _buildInstallationGrid(),

                const SizedBox(height: 28),

                _buildTransactionsCard(),

                const SizedBox(height: 20),

                _buildInfoCard(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionHeading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: EarningWalletScreen.text,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: EarningWalletScreen.grey),
        ),
      ],
    );
  }

  // ---------------------------------------------------------
  // AVAILABLE BALANCE CARD
  // ---------------------------------------------------------

  Widget _buildBalanceCard(bool mobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(mobile ? 22 : 30),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [EarningWalletScreen.navy, EarningWalletScreen.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: EarningWalletScreen.navy.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Available Balance',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: EarningWalletScreen.gold,
                  size: 25,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            money(availableBalance),
            style: TextStyle(
              color: Colors.white,
              fontSize: mobile ? 32 : 38,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Your confirmed withdrawable earnings',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: mobile ? double.infinity : 190,
            child: ElevatedButton.icon(
              onPressed: _walletLoading ? null : _openWithdrawForm,
              icon: const Icon(Icons.account_balance_rounded),
              label: const Text('Withdraw Funds'),
              style: ElevatedButton.styleFrom(
                backgroundColor: EarningWalletScreen.gold,
                foregroundColor: EarningWalletScreen.navy,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // EARNINGS OVERVIEW
  // Desktop/web: 3 cards in one row.
  // Small screens: responsive layout.
  // ---------------------------------------------------------

  Widget _buildSummaryGrid() {
    final cards = [
      _SummaryData(
        title: 'Total Earnings',
        value: money(totalEarnings),
        subtitle: 'Lifetime earnings',
        icon: Icons.trending_up_rounded,
        color: const Color(0xFF3159B7),
        iconBg: const Color(0xFFEAF0FF),
      ),
      _SummaryData(
        title: 'Pending Balance',
        value: money(pendingRewards),
        subtitle: 'Pending wallet funds',
        icon: Icons.hourglass_top_rounded,
        color: const Color(0xFFB7791F),
        iconBg: const Color(0xFFFFF4D8),
      ),
      _SummaryData(
        title: 'Processing Balance',
        value: money(processingBalance),
        subtitle: 'Payouts in progress',
        icon: Icons.sync_rounded,
        color: const Color(0xFF7650B8),
        iconBg: const Color(0xFFF0E8FF),
      ),
      _SummaryData(
        title: 'Total Withdrawn',
        value: money(totalWithdrawn),
        subtitle: 'Completed payouts',
        icon: Icons.payments_rounded,
        color: const Color(0xFF16866B),
        iconBg: const Color(0xFFE3F7F0),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 500 ? 3 : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 120,
          ),
          itemBuilder: (context, index) {
            return _SummaryCard(data: cards[index]);
          },
        );
      },
    );
  }

  // ---------------------------------------------------------
  // INSTALLATION OVERVIEW
  // Each card has a different icon colour.
  // ---------------------------------------------------------

  Widget _buildInstallationGrid() {
    final items = [
      _InstallationData(
        title: 'Total Installations',
        value: _installationError == null
            ? '${_totalInstallations ?? '—'}'
            : '—',
        icon: Icons.home_repair_service_rounded,
        iconColor: const Color(0xFF3159B7),
        iconBg: const Color(0xFFEAF0FF),
      ),
      _InstallationData(
        title: 'Eligible Installations',
        value: _installationError == null
            ? '${_eligibleInstallations ?? '—'}'
            : '—',
        icon: Icons.card_giftcard_rounded,
        iconColor: const Color(0xFF16866B),
        iconBg: const Color(0xFFE1F7EE),
      ),
      _InstallationData(
        title: 'Processing Rewards',
        value: _installationError == null
            ? '${_processingInstallationRewards ?? '—'}'
            : '—',
        icon: Icons.pending_actions_rounded,
        iconColor: const Color(0xFFD28A16),
        iconBg: const Color(0xFFFFF2D8),
      ),
      _InstallationData(
        title: 'Completed Rewards',
        value: _installationError == null
            ? '${_completedInstallationRewards ?? '—'}'
            : '—',
        icon: Icons.verified_rounded,
        iconColor: const Color(0xFF8150C9),
        iconBg: const Color(0xFFF0E8FF),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 550
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: 108,
          ),
          itemBuilder: (context, index) {
            return _InstallationCard(data: items[index]);
          },
        );
      },
    );
  }

  // ---------------------------------------------------------
  // RECENT TRANSACTIONS
  // ---------------------------------------------------------

  Widget _buildTransactionsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: EarningWalletScreen.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Transactions',
            style: TextStyle(
              color: EarningWalletScreen.text,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Your latest wallet activity.',
            style: TextStyle(color: EarningWalletScreen.grey, fontSize: 13),
          ),

          const SizedBox(height: 24),

          if (_transactions.isEmpty && !_walletLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEAF0FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        size: 34,
                        color: EarningWalletScreen.blue,
                      ),
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      'No transactions to display',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: EarningWalletScreen.text,
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      'Your transaction history will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: EarningWalletScreen.grey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          for (final transaction in _transactions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFEAF0FF),
                child: Icon(
                  transaction['type'] == 'debit'
                      ? Icons.south_west
                      : Icons.north_east,
                  color: EarningWalletScreen.blue,
                ),
              ),
              title: Text(
                transaction['description']?.toString() ??
                    transaction['category']?.toString() ??
                    'Wallet transaction',
              ),
              subtitle: Text(
                '${transaction['status'] ?? ''} • ${transaction['date'] ?? ''}'
                '${transaction['reference_id'] == null || transaction['reference_id'].toString().isEmpty ? '' : '\nReference: ${transaction['reference_id']}'}',
              ),
              trailing: Text(
                '₹${_number(transaction['amount'])?.toStringAsFixed(2) ?? '0.00'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // WALLET INFORMATION
  // ---------------------------------------------------------

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E3FF)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: EarningWalletScreen.blue,
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About Your Wallet',
                  style: TextStyle(
                    color: EarningWalletScreen.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Earnings, rewards and withdrawal status are subject '
                  'to verification and the platform payout policy.',
                  style: TextStyle(
                    color: EarningWalletScreen.text,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // WITHDRAW FORM
  // ---------------------------------------------------------

  void _openWithdrawForm() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _WithdrawDialog(
          availableBalance: availableBalance,
          walletVerified:
              !_walletLoading &&
              _walletError == null &&
              availableBalance != null,
          onLoadBankDetails: _api.bankDetails,
          onSaveBankDetails: _api.updateBankDetails,
          onRequestPayout: _api.requestPayout,
          onPayoutSubmitted: _loadWallet,
        );
      },
    );
  }
}

// =============================================================
// SUMMARY CARD MODEL
// =============================================================

class _SummaryData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color iconBg;

  const _SummaryData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.iconBg,
  });
}

// =============================================================
// SUMMARY CARD WIDGET
// =============================================================

class _SummaryCard extends StatelessWidget {
  final _SummaryData data;

  const _SummaryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EarningWalletScreen.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: data.iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: data.color, size: 21),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: EarningWalletScreen.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 7),

                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    data.value,
                    style: const TextStyle(
                      color: EarningWalletScreen.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  data.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: EarningWalletScreen.grey,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// INSTALLATION CARD MODEL
// =============================================================

class _InstallationData {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;

  const _InstallationData({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });
}

// =============================================================
// INSTALLATION CARD WIDGET
// =============================================================

class _InstallationCard extends StatelessWidget {
  final _InstallationData data;

  const _InstallationCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: EarningWalletScreen.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: data.iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: data.iconColor, size: 23),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: EarningWalletScreen.grey,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),

                const SizedBox(height: 7),

                Text(
                  data.value,
                  style: const TextStyle(
                    color: EarningWalletScreen.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// WITHDRAW FORM
// =============================================================

class _WithdrawDialog extends StatefulWidget {
  final double? availableBalance;
  final bool walletVerified;
  final Future<Map<String, dynamic>> Function() onLoadBankDetails;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)
  onSaveBankDetails;
  final Future<Map<String, dynamic>> Function(double) onRequestPayout;
  final Future<void> Function() onPayoutSubmitted;

  const _WithdrawDialog({
    required this.availableBalance,
    required this.walletVerified,
    required this.onLoadBankDetails,
    required this.onSaveBankDetails,
    required this.onRequestPayout,
    required this.onPayoutSubmitted,
  });

  @override
  State<_WithdrawDialog> createState() => _WithdrawDialogState();
}

class _WithdrawDialogState extends State<_WithdrawDialog> {
  static const double _minimumPayout = 500;

  final _bankFormKey = GlobalKey<FormState>();
  final _payoutFormKey = GlobalKey<FormState>();
  final _holderController = TextEditingController();
  final _bankController = TextEditingController();
  final _accountController = TextEditingController();
  final _confirmAccountController = TextEditingController();
  final _ifscController = TextEditingController();
  final _amountController = TextEditingController();

  Map<String, dynamic>? _bankDetails;
  String? _bankLoadError;
  String? _bankSaveError;
  String? _payoutError;
  bool _loadingBankDetails = true;
  bool _editingBankDetails = true;
  bool _savingBankDetails = false;
  bool _submittingPayout = false;
  bool _obscureAccount = true;

  bool get _hasSavedBankDetails {
    final masked = _bankDetails?['masked_account_number']?.toString().trim();
    final ifsc = _bankDetails?['ifsc']?.toString().trim();
    return masked != null &&
        masked.isNotEmpty &&
        ifsc != null &&
        ifsc.isNotEmpty;
  }

  bool get _payoutEligible =>
      widget.walletVerified &&
      widget.availableBalance != null &&
      widget.availableBalance! >= _minimumPayout &&
      _hasSavedBankDetails &&
      !_editingBankDetails;

  @override
  void initState() {
    super.initState();
    _loadBankDetails();
  }

  @override
  void dispose() {
    _holderController.dispose();
    _bankController.dispose();
    _accountController.dispose();
    _confirmAccountController.dispose();
    _ifscController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadBankDetails() async {
    setState(() {
      _loadingBankDetails = true;
      _bankLoadError = null;
      _bankSaveError = null;
    });
    try {
      final details = await widget.onLoadBankDetails();
      if (!mounted) return;
      _bankDetails = details;
      _holderController.text = details['account_holder']?.toString() ?? '';
      _bankController.text = details['bank_name']?.toString() ?? '';
      _ifscController.text = details['ifsc']?.toString() ?? '';
      _accountController.clear();
      _confirmAccountController.clear();
      setState(() {
        _editingBankDetails = !_hasSavedBankDetails;
        _loadingBankDetails = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _bankLoadError = error.message;
        _loadingBankDetails = false;
        _editingBankDetails = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bankLoadError = 'Could not load saved bank details.';
        _loadingBankDetails = false;
        _editingBankDetails = true;
      });
    }
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  String? _validateAccountNumber(String? value) {
    final required = _required(value, 'Account number');
    if (required != null) return required;
    if (!RegExp(r'^\d{8,20}$').hasMatch(value!.trim())) {
      return 'Enter 8 to 20 digits';
    }
    return null;
  }

  String? _validateIfsc(String? value) {
    final required = _required(value, 'IFSC code');
    if (required != null) return required;
    if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$')
        .hasMatch(value!.trim().toUpperCase())) {
      return 'Enter a valid 11-character IFSC code';
    }
    return null;
  }

  Future<void> _saveBankDetails() async {
    if (_savingBankDetails || !_bankFormKey.currentState!.validate()) return;
    setState(() {
      _savingBankDetails = true;
      _bankSaveError = null;
    });
    try {
      final details = await widget.onSaveBankDetails({
        'account_holder_name': _holderController.text.trim(),
        'account_number': _accountController.text.trim(),
        'ifsc_code': _ifscController.text.trim().toUpperCase(),
        'bank_name': _bankController.text.trim(),
      });
      if (!mounted) return;
      _bankDetails = details;
      _accountController.clear();
      _confirmAccountController.clear();
      setState(() {
        _savingBankDetails = false;
        _editingBankDetails = !_hasSavedBankDetails;
      });
      final status = details['verification_status']?.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == null || status.isEmpty
                ? 'Bank details saved by the server.'
                : 'Bank details saved. Verification status: $status.',
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _savingBankDetails = false;
        _bankSaveError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _savingBankDetails = false;
        _bankSaveError = 'Bank details could not be saved.';
      });
    }
  }

  double? _validatedAmount() {
    if (!_payoutEligible || !_payoutFormKey.currentState!.validate()) {
      return null;
    }
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null) return null;
    if (amount < _minimumPayout) {
      setState(() => _payoutError = 'Minimum withdrawal amount is ₹500.00.');
      return null;
    }
    if (amount > widget.availableBalance!) {
      setState(() => _payoutError = 'Amount exceeds your available balance.');
      return null;
    }
    return amount;
  }

  Future<void> _requestPayout() async {
    if (_submittingPayout) return;
    final amount = _validatedAmount();
    if (amount == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (confirmationContext) => AlertDialog(
        title: const Text('Confirm withdrawal request'),
        content: Text(
          'Request ₹${amount.toStringAsFixed(2)} to '
          '${_bankDetails?['bank_name'] ?? 'your saved bank account'} '
          '(${_bankDetails?['masked_account_number'] ?? 'account on file'}). '
          'Submitting this request moves funds to processing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmationContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(confirmationContext, true),
            child: const Text('Confirm request'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _submittingPayout = true;
      _payoutError = null;
    });
    try {
      final payout = await widget.onRequestPayout(amount);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      await widget.onPayoutSubmitted();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Payout request ${payout['payout_id'] ?? ''} submitted. '
            'Status: ${payout['status'] ?? 'pending'}.',
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _submittingPayout = false;
          _payoutError = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _submittingPayout = false;
          _payoutError = 'Payout request could not be submitted.';
        });
      }
    }
  }

  String _money(double? value) =>
      value == null ? 'Unavailable' : '₹${value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Withdraw Funds',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: EarningWalletScreen.navy,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _submittingPayout
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Text(
                'Available balance: ${_money(widget.availableBalance)}',
                style: const TextStyle(color: EarningWalletScreen.grey),
              ),
              const SizedBox(height: 18),
              if (_loadingBankDetails)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                if (_bankLoadError != null) ...[
                  _messageBox(_bankLoadError!, isError: true),
                  TextButton.icon(
                    onPressed: _loadBankDetails,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry loading bank details'),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_editingBankDetails)
                  _buildBankForm()
                else
                  _buildSavedBankDetails(),
                const SizedBox(height: 18),
                _buildPayoutArea(),
                if (_bankSaveError != null) ...[
                  const SizedBox(height: 10),
                  _messageBox(_bankSaveError!, isError: true),
                ],
                if (_payoutError != null) ...[
                  const SizedBox(height: 10),
                  _messageBox(_payoutError!, isError: true),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBankForm() {
    return Form(
      key: _bankFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _hasSavedBankDetails ? 'Edit bank details' : 'Add bank details',
            style: const TextStyle(
              color: EarningWalletScreen.navy,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          if (_hasSavedBankDetails)
            const Text(
              'For security, the saved account number is masked. Enter the new account number to replace it.',
              style: TextStyle(color: EarningWalletScreen.grey, fontSize: 12),
            ),
          if (_hasSavedBankDetails) const SizedBox(height: 12),
          _field(
            controller: _holderController,
            label: 'Account Holder Name',
            icon: Icons.person_outline_rounded,
            validator: (value) {
              final required = _required(value, 'Account holder name');
              if (required != null) return required;
              if (value!.trim().length < 2) {
                return 'Enter at least 2 characters';
              }
              return null;
            },
          ),
          _field(
            controller: _bankController,
            label: 'Bank Name',
            icon: Icons.account_balance_outlined,
            validator: (value) {
              final required = _required(value, 'Bank name');
              if (required != null) return required;
              if (value!.trim().length < 2) {
                return 'Enter at least 2 characters';
              }
              return null;
            },
          ),
          _field(
            controller: _accountController,
            label: 'Account Number',
            icon: Icons.credit_card_rounded,
            keyboardType: TextInputType.number,
            obscureText: _obscureAccount,
            suffix: IconButton(
              tooltip: _obscureAccount
                  ? 'Show account number'
                  : 'Hide account number',
              onPressed: () =>
                  setState(() => _obscureAccount = !_obscureAccount),
              icon: Icon(
                _obscureAccount
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
            validator: _validateAccountNumber,
          ),
          _field(
            controller: _confirmAccountController,
            label: 'Confirm Account Number',
            icon: Icons.verified_user_outlined,
            keyboardType: TextInputType.number,
            validator: (value) {
              final required = _required(value, 'Confirm account number');
              if (required != null) return required;
              if (value!.trim() != _accountController.text.trim()) {
                return 'Account numbers do not match';
              }
              return null;
            },
          ),
          _field(
            controller: _ifscController,
            label: 'IFSC Code',
            icon: Icons.location_on_outlined,
            textCapitalization: TextCapitalization.characters,
            validator: _validateIfsc,
          ),
          const Text(
            'The backend accepts account holder name, bank name, account number and IFSC code. Branch name and UPI ID are not supported.',
            style: TextStyle(color: EarningWalletScreen.grey, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (_hasSavedBankDetails)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _savingBankDetails
                        ? null
                        : () => setState(() {
                            _editingBankDetails = false;
                            _bankSaveError = null;
                          }),
                    child: const Text('Cancel edit'),
                  ),
                ),
              if (_hasSavedBankDetails) const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _savingBankDetails ? null : _saveBankDetails,
                  child: _savingBankDetails
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save bank details'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSavedBankDetails() {
    final status =
        _bankDetails?['verification_status']?.toString() ?? 'UNKNOWN';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: EarningWalletScreen.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Bank account on file',
                  style: TextStyle(
                    color: EarningWalletScreen.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: _submittingPayout ? null : _beginEditingBankDetails,
                child: const Text('Edit'),
              ),
            ],
          ),
          Text('Account holder: ${_bankDetails?['account_holder'] ?? '—'}'),
          Text('Bank: ${_bankDetails?['bank_name'] ?? '—'}'),
          Text('Account: ${_bankDetails?['masked_account_number'] ?? '—'}'),
          Text('IFSC: ${_bankDetails?['ifsc'] ?? '—'}'),
          Text('Verification status: $status'),
        ],
      ),
    );
  }

  void _beginEditingBankDetails() {
    _holderController.text = _bankDetails?['account_holder']?.toString() ?? '';
    _bankController.text = _bankDetails?['bank_name']?.toString() ?? '';
    _ifscController.text = _bankDetails?['ifsc']?.toString() ?? '';
    _accountController.clear();
    _confirmAccountController.clear();
    setState(() {
      _editingBankDetails = true;
      _bankSaveError = null;
      _payoutError = null;
    });
  }

  Widget _buildPayoutArea() {
    if (!widget.walletVerified || widget.availableBalance == null) {
      return _messageBox(
        'Wallet eligibility could not be verified. You can keep or edit bank details, but a payout request is unavailable.',
        isError: true,
      );
    }
    if (widget.availableBalance! < _minimumPayout) {
      return _messageBox(
        'Minimum withdrawal amount is ₹500.00. Your available balance is ${_money(widget.availableBalance)}. You may keep or edit bank details; no payout can be requested yet.',
      );
    }
    if (_editingBankDetails || !_hasSavedBankDetails) {
      return _messageBox(
        'Save bank details before requesting a payout. Saving bank details does not request a withdrawal.',
      );
    }

    return Form(
      key: _payoutFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(
            controller: _amountController,
            label: 'Withdrawal Amount (₹)',
            icon: Icons.currency_rupee_rounded,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              final required = _required(value, 'Withdrawal amount');
              if (required != null) return required;
              final amount = double.tryParse(value!.trim());
              if (amount == null || amount <= 0) return 'Enter a valid amount';
              if (amount < _minimumPayout) {
                return 'Minimum withdrawal is ₹500.00';
              }
              if (amount > widget.availableBalance!) {
                return 'Amount exceeds your available balance';
              }
              return null;
            },
          ),
          Text(
            'Minimum withdrawal: ₹500.00 · Available: ${_money(widget.availableBalance)}',
            style: const TextStyle(
              color: EarningWalletScreen.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _submittingPayout ? null : _requestPayout,
            child: _submittingPayout
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Request payout'),
          ),
          const SizedBox(height: 8),
          const Text(
            'The next step asks for confirmation. A confirmed request is real and moves funds from available to processing.',
            style: TextStyle(color: EarningWalletScreen.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _messageBox(String message, {bool isError = false}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: isError ? const Color(0xFFFFF0F0) : const Color(0xFFFFF5D9),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      message,
      style: TextStyle(
        color: isError ? const Color(0xFF9B1C1C) : const Color(0xFF785A1B),
        fontSize: 12,
        height: 1.5,
      ),
    ),
  );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        obscureText: obscureText,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: EarningWalletScreen.blue, size: 21),
          suffixIcon: suffix,
          filled: true,
          fillColor: const Color(0xFFF8FAFF),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: EarningWalletScreen.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: EarningWalletScreen.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: EarningWalletScreen.blue,
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
        ),
      ),
    );
  }
}
