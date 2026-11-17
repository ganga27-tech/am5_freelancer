import 'package:flutter/material.dart';

import '../../data/models/reward_model.dart';
import '../../data/repositories/rewards_repository.dart';
import '../../data/services/rewards_api_service.dart';
import '../../../../core/widgets/section_hero_banner.dart';

class RewardsOverviewScreen extends StatefulWidget {
  const RewardsOverviewScreen({super.key});

  @override
  State<RewardsOverviewScreen> createState() => _RewardsOverviewScreenState();
}

class _RewardsOverviewScreenState extends State<RewardsOverviewScreen> {
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _filters = [
    'All',
    'Approved',
    'Pending',
    'Processing',
    'Paid',
  ];

  String _selectedFilter = 'All';
  String _searchQuery = '';

  bool _isLoading = false;
  String? _errorMessage;

  List<RewardModel> _rewards = [];
  Map<String, dynamic>? _summary;

  RewardsRepository? _repository;

  @override
  void initState() {
    super.initState();

    _initializeRepository();
    _loadRewards();
  }

  void _initializeRepository() {
    _repository = RewardsRepository(apiService: RewardsApiService());
  }

  // Normalize text for consistent searching and status comparison.
  String _normalize(String? value) {
    return (value ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> _loadRewards() async {
    if (!mounted || _isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repository = _repository;

      if (repository == null) {
        throw Exception('Rewards service is not configured.');
      }

      final results = await Future.wait([
        repository.getRewards(),
        repository.getSummary(),
      ]);
      final result = results[0] as List<RewardModel>;
      final summary = results[1] as Map<String, dynamic>;

      if (!mounted) return;

      setState(() {
        _rewards = List<RewardModel>.of(result);
        _summary = summary;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;

        _errorMessage = error is RewardsApiException
            ? error.message
            : 'Unable to load rewards. Please try again.';
      });
    }
  }

  // Search across title, type, description and status.
  List<RewardModel> get _filteredRewards {
    final query = _normalize(_searchQuery);

    final results = _rewards.where((reward) {
      final title = _normalize(reward.title);
      final type = _normalize(reward.type);
      final description = _normalize(reward.description);
      final status = _normalize(reward.status);

      final matchesSearch =
          query.isEmpty ||
          title.contains(query) ||
          type.contains(query) ||
          description.contains(query) ||
          status.contains(query);

      final selectedStatus = _normalize(_selectedFilter);

      final matchesFilter = selectedStatus == 'all' || status == selectedStatus;

      return matchesSearch && matchesFilter;
    }).toList();

    // Newest rewards first.
    results.sort((a, b) {
      final aDate = a.createdAt;
      final bDate = b.createdAt;

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return bDate.compareTo(aDate);
    });

    return results;
  }

  double? _summaryAmount(String key) {
    final value = _summary?[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String _currency(double? amount) {
    if (amount == null) return '—';
    return '₹${amount.toStringAsFixed(2)}';
  }

  void _clearSearch() {
    _searchController.clear();

    setState(() {
      _searchQuery = '';
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _repository?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //backgroundColor: const Color(0xFFF4F6FC),
      backgroundColor: const Color(0xFFFFF8ED),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadRewards,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 650;

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(isMobile ? 16 : 28),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 22),
                  _buildSummaryCards(constraints.maxWidth),
                  const SizedBox(height: 28),
                  _buildHistoryHeader(),
                  const SizedBox(height: 16),
                  _buildSearchAndFilters(),
                  const SizedBox(height: 16),
                  _buildHistoryContent(),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SectionHeroBanner(
      title: 'Rewards & Cashback',
      subtitle: 'Track your earned rewards and cashback.',
      icon: Icons.card_giftcard_rounded,
      imageAsset: 'assets/images/benefits/gifts_rewards.png',
      trailing: IconButton(
        tooltip: 'Refresh rewards',
        onPressed: _isLoading ? null : _loadRewards,
        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildSummaryCards(double availableWidth) {
    final isMobile = availableWidth < 650;

    final crossAxisCount = availableWidth >= 1100
        ? 4
        : availableWidth >= 650
        ? 2
        : 1;

    final cardWidth = crossAxisCount == 1
        ? availableWidth
        : (availableWidth - (crossAxisCount - 1) * 14 - 56) / crossAxisCount;

    final cards = [
      _SummaryData(
        title: 'Total Rewards',
        amount: _currency(_summaryAmount('total_rewards')),
        icon: Icons.workspace_premium_rounded,
        color: const Color(0xFF2449A5),
        background: const Color(0xFFE9EEFF),
      ),
      _SummaryData(
        title: 'Approved Rewards',
        amount: _currency(_summaryAmount('approved_rewards')),
        icon: Icons.verified_rounded,
        color: const Color(0xFF16845B),
        background: const Color(0xFFE1F6EC),
      ),
      _SummaryData(
        title: 'Pending Rewards',
        amount: _currency(_summaryAmount('pending_rewards')),
        icon: Icons.hourglass_top_rounded,
        color: const Color(0xFFB7791F),
        background: const Color(0xFFFFF2D8),
      ),
      _SummaryData(
        title: 'Cashback Rewards',
        amount: _currency(_summaryAmount('cashback_rewards')),
        icon: Icons.currency_rupee_rounded,
        color: const Color(0xFF7650B8),
        background: const Color(0xFFF0E8FF),
      ),
    ];

    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: cards.map((card) {
        return SizedBox(width: cardWidth, child: _summaryCard(card, isMobile));
      }).toList(),
    );
  }

  Widget _summaryCard(_SummaryData data, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EAF4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080E2358),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: data.background,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(data.icon, color: data.color, size: 24),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    color: Color(0xFF778198),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 7),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    data.amount,
                    style: const TextStyle(
                      color: Color(0xFF14254F),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rewards History',
          style: TextStyle(
            color: Color(0xFF14254F),
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'View rewards earned from your activities.',
          style: TextStyle(color: Color(0xFF778198), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          decoration: InputDecoration(
            hintText: 'Search rewards...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    tooltip: 'Clear search',
                    onPressed: _clearSearch,
                    icon: const Icon(Icons.close_rounded),
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF2449A5),
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filters.map((filter) {
              final selected = _selectedFilter == filter;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(filter),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _selectedFilter = filter;
                    });
                  },
                  selectedColor: const Color(0xFF2449A5),
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF596780),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  side: BorderSide(
                    color: selected
                        ? const Color(0xFF2449A5)
                        : const Color(0xFFE2E8F2),
                  ),
                  showCheckmark: false,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryContent() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 55),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF2449A5)),
        ),
      );
    }

    if (_errorMessage != null) {
      return _messageCard(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load rewards',
        message: _errorMessage!,
        actionLabel: 'Try Again',
        onAction: _loadRewards,
      );
    }

    final rewards = _filteredRewards;

    if (rewards.isEmpty) {
      final hasNoData = _rewards.isEmpty;

      return _messageCard(
        icon: hasNoData
            ? Icons.card_giftcard_outlined
            : Icons.search_off_rounded,
        title: hasNoData ? 'No Rewards Yet' : 'No Matching Rewards',
        message: hasNoData
            ? 'Your earned rewards will appear here.'
            : 'Try another search term or status filter.',
        actionLabel: hasNoData ? 'Refresh' : 'Clear Search',
        onAction: hasNoData ? _loadRewards : _clearSearch,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EAF4)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rewards.length; i++) ...[
            _rewardRow(rewards[i]),
            if (i < rewards.length - 1)
              const Divider(
                height: 1,
                indent: 18,
                endIndent: 18,
                color: Color(0xFFEFF2F8),
              ),
          ],
        ],
      ),
    );
  }

  Widget _rewardRow(RewardModel reward) {
    final statusColor = _statusColor(reward.status);
    final icon = _rewardIcon(reward.type);

    return Padding(
      padding: const EdgeInsets.all(17),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE9EEFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF2449A5), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.title,
                  style: const TextStyle(
                    color: Color(0xFF19284D),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  reward.description.trim().isNotEmpty
                      ? reward.description
                      : reward.type,
                  style: const TextStyle(
                    color: Color(0xFF778198),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _formatDate(reward.createdAt),
                      style: const TextStyle(
                        color: Color(0xFF8B94A7),
                        fontSize: 11,
                      ),
                    ),
                    _statusBadge(reward.status, statusColor),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _currency(reward.amount),
            style: const TextStyle(
              color: Color(0xFF14254F),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status, Color color) {
    final normalizedStatus = status.trim();

    final label = normalizedStatus.isEmpty
        ? 'Unknown'
        : normalizedStatus[0].toUpperCase() +
              normalizedStatus.substring(1).toLowerCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _messageCard({
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EAF4)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: const Color(0xFF9AA5BA)),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF19284D),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF778198), fontSize: 13),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2449A5),
                foregroundColor: Colors.white,
              ),
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (_normalize(status)) {
      case 'approved':
      case 'paid':
        return const Color(0xFF16845B);

      case 'pending':
        return const Color(0xFFB7791F);

      case 'processing':
        return const Color(0xFF2449A5);

      case 'rejected':
      case 'failed':
        return const Color(0xFFC03945);

      default:
        return const Color(0xFF778198);
    }
  }

  IconData _rewardIcon(String type) {
    switch (_normalize(type)) {
      case 'referral':
        return Icons.people_alt_rounded;

      case 'installation':
        return Icons.phone_android_rounded;

      case 'booking':
        return Icons.home_repair_service_rounded;

      case 'cashback':
        return Icons.currency_rupee_rounded;

      default:
        return Icons.card_giftcard_rounded;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Date unavailable';

    final localDate = date.toLocal();

    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final year = localDate.year;

    return '$day/$month/$year';
  }
}

class _SummaryData {
  final String title;
  final String amount;
  final IconData icon;
  final Color color;
  final Color background;

  const _SummaryData({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
    required this.background,
  });
}
