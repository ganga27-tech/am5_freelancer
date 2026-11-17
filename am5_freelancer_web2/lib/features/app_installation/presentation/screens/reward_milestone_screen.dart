import 'package:flutter/material.dart';

import '../../data/rewards_data.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/freelance_api.dart';

class RewardMilestoneScreen extends StatefulWidget {
  const RewardMilestoneScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isInstallation,
    required this.appType,
  });

  final String title;
  final String subtitle;
  final bool isInstallation;
  final String appType;

  @override
  State<RewardMilestoneScreen> createState() => _RewardMilestoneScreenState();
}

class _RewardMilestoneScreenState extends State<RewardMilestoneScreen> {
  static const Color navy = Color(0xFF101D45);
  static const Color royalBlue = Color(0xFF2449A5);
  static const Color gold = Color(0xFFFFC857);

  late int selectedMilestone;
  final FreelanceApi _api = FreelanceApi();
  late List<RewardInfo> _rewards;
  Map<String, dynamic>? _statistics;
  List<Map<String, dynamic>> _tracking = const [];
  String? _activityError;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _rewards = const [];
    _loadRewards();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _loadRewards() async {
    _activityError = null;
    _statistics = null;
    _tracking = const [];
    try {
      final data = widget.isInstallation
          ? await _api.installationRules(widget.appType)
          : await _api.installationEligibility(widget.appType);
      try {
        final results = await Future.wait([
          _api.installationStatistics(),
          _api.installationTracking(appType: widget.appType),
        ]);
        final trackingItems = results[1]['items'];
        _statistics = results[0];
        _tracking = trackingItems is List
            ? trackingItems
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList(growable: false)
            : const [];
      } on ApiException catch (error) {
        _activityError = error.message;
      }
      final raw = data['milestones'];
      if (raw is! List) {
        throw const ApiException('The rewards response is incomplete.');
      }
      final rewards = <RewardInfo>[];
      for (final value in raw.whereType<Map>()) {
        final item = Map<String, dynamic>.from(value);
        final target = int.tryParse(
          (item['target_count'] ?? item['target'])?.toString() ?? '',
        );
        if (target == null || target <= 0) continue;
        final amount = item['reward_amount'];
        final voucher = item['voucher_title']?.toString() ?? '';
        rewards.add(
          RewardInfo(
            milestone: target,
            cashReward: amount is num && amount > 0
                ? '₹${_formatAmount(amount)}'
                : '',
            cashbackVoucher: voucher,
            additionalNote: widget.isInstallation
                ? item['conditions']?.toString() ?? ''
                : 'Progress ${item['current_eligible_count'] ?? 0}/$target • ${item['reward_status'] ?? ''}',
          ),
        );
      }
      if (rewards.isEmpty) {
        throw const ApiException(
          'No installation reward milestones are available yet.',
        );
      }
      if (!mounted) return;
      setState(() {
        _rewards = rewards;
        selectedMilestone = rewards.first.milestone;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  String _formatAmount(num amount) => amount % 1 == 0
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final reward = _rewards.isEmpty
        ? null
        : _rewards.firstWhere(
            (item) => item.milestone == selectedMilestone,
            orElse: () => _rewards.first,
          );

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FC),
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _loading = true;
                          _error = null;
                        });
                        _loadRewards();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : _rewards.isEmpty || reward == null
          ? const Center(child: Text('No reward milestones are available.'))
          : Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE8F0FF), Color(0xFFF3F6FC), Colors.white],
                ),
              ),
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 32,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // HEADER
                                const Center(
                                  child: Icon(
                                    Icons.workspace_premium_rounded,
                                    color: royalBlue,
                                    size: 34,
                                  ),
                                ),

                                const SizedBox(height: 8),

                                Text(
                                  widget.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: navy,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                Text(
                                  widget.subtitle,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF778198),
                                    fontSize: 12,
                                    height: 1.5,
                                  ),
                                ),

                                const SizedBox(height: 18),

                                // MILESTONE SELECTOR
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(17),
                                    border: Border.all(
                                      color: const Color(0xFFE0E7F3),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: navy.withValues(alpha: 0.04),
                                        blurRadius: 14,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Select Milestone',
                                        style: TextStyle(
                                          color: navy,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),

                                      const SizedBox(height: 10),

                                      DropdownButtonFormField<int>(
                                        initialValue: selectedMilestone,
                                        isExpanded: true,
                                        decoration: InputDecoration(
                                          hintText: 'Choose a milestone',
                                          filled: true,
                                          fillColor: const Color(0xFFF3F6FC),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 12,
                                              ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFE0E7F3),
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFE0E7F3),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: const BorderSide(
                                              color: royalBlue,
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: royalBlue,
                                        ),
                                        items: _rewards.map((item) {
                                          return DropdownMenuItem<int>(
                                            value: item.milestone,
                                            child: Text(
                                              _milestoneLabel(item.milestone),
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: navy,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          if (value == null) return;

                                          setState(() {
                                            selectedMilestone = value;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // REWARD DETAILS CARD
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: const Color(0xFFE0E7F3),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: navy.withValues(alpha: 0.05),
                                        blurRadius: 16,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.card_giftcard_rounded,
                                            color: gold,
                                            size: 23,
                                          ),
                                          SizedBox(width: 9),
                                          Text(
                                            'Your Rewards',
                                            style: TextStyle(
                                              color: navy,
                                              fontSize: 17,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 18),

                                      if (reward.cashReward.isNotEmpty)
                                        _RewardRow(
                                          icon: Icons.currency_rupee_rounded,
                                          label: 'Cash Reward',
                                          value: reward.cashReward,
                                        ),

                                      if (reward.gift.isNotEmpty)
                                        _RewardRow(
                                          icon: Icons.redeem_rounded,
                                          label: 'Gift / Benefit',
                                          value: reward.gift,
                                        ),

                                      if (reward.cashbackVoucher.isNotEmpty)
                                        _RewardRow(
                                          icon: Icons.local_offer_outlined,
                                          label: 'Cashback',
                                          value: reward.cashbackVoucher,
                                        ),

                                      if (reward.additionalNote.isNotEmpty)
                                        _RewardRow(
                                          icon: Icons.info_outline_rounded,
                                          label: 'Additional Benefit',
                                          value: reward.additionalNote,
                                        ),

                                      const Divider(
                                        height: 22,
                                        color: Color(0xFFE8EDF5),
                                      ),
                                      _ProgressSummary(
                                        appType: widget.appType,
                                        statistics: _statistics,
                                        tracking: _tracking,
                                        error: _activityError,
                                      ),

                                    ],
                                  ),
                                ),

                                const SizedBox(height: 12),

                                const Text(
                                  'AM5 ROYAL  •  Work. Refer. Grow.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF8A95A9),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }

  String _milestoneLabel(int milestone) {
    if (widget.isInstallation) {
      if (milestone == 25000) {
        return '25,000+ Installations';
      }

      return '$milestone Installations';
    }

    if (milestone == 2000) {
      return '2,000+ Activations';
    }

    return '$milestone Activations';
  }
}

// REUSABLE REWARD ROW
class _RewardRow extends StatelessWidget {
  const _RewardRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEDF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF2449A5), size: 19),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF778198),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF101D45),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
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

class _ProgressSummary extends StatelessWidget {
  const _ProgressSummary({
    required this.appType,
    required this.statistics,
    required this.tracking,
    required this.error,
  });

  final String appType;
  final Map<String, dynamic>? statistics;
  final List<Map<String, dynamic>> tracking;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final prefix = appType == 'vendor' ? 'vendor' : 'customer';
    final installs = statistics?['${prefix}_installs'];
    final activations = statistics?['${prefix}_activations'];
    final eligible = statistics?['${prefix}_eligible'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Your recorded progress',
          style: TextStyle(
            color: Color(0xFF101D45),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (error != null)
          Text(error!, style: const TextStyle(color: Color(0xFF9B2C2C)))
        else if (statistics == null)
          const Text('Progress is not available yet.')
        else
          Text(
            'Installs: ${installs ?? 0}  •  Activations: ${activations ?? 0}  •  Eligible: ${eligible ?? 0}',
            style: const TextStyle(color: Color(0xFF536585), height: 1.5),
          ),
        const SizedBox(height: 12),
        const Text(
          'Recent attributed records',
          style: TextStyle(
            color: Color(0xFF101D45),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        if (error != null)
          const Text('Tracking records could not be loaded.')
        else if (tracking.isEmpty)
          const Text('No attributed installation records are available.')
        else
          for (final record in tracking.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                'Install: ${record['install_date'] ?? '—'}  •  Activation: ${record['activation_date'] ?? '—'}  •  Status: ${record['eligibility_status'] ?? '—'}',
                style: const TextStyle(
                  color: Color(0xFF536585),
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
      ],
    );
  }
}
