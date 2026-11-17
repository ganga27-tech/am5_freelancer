import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/freelance_api.dart';
import '../widgets/customer_how_it_works.dart';
import '../widgets/refer_customer_card.dart';
import '../widgets/refer_earn_header.dart';
import '../widgets/refer_vendor_card.dart';
import '../widgets/referral_points_card.dart';
import '../widgets/vendor_how_it_works.dart';
import '../vendor_referral_url.dart';

class ReferEarnScreen extends StatefulWidget {
  const ReferEarnScreen({
    super.key,
    @visibleForTesting this.api,
    @visibleForTesting this.shareLink,
    @visibleForTesting this.openVendorLink,
  });

  @visibleForTesting
  final FreelanceApi? api;
  @visibleForTesting
  final Future<void> Function(String url)? shareLink;
  @visibleForTesting
  final Future<bool> Function(Uri uri)? openVendorLink;
  static const Color backgroundColor = Color(0xFFFFF8ED);
  static const Color textDark = Color(0xFF17233F);
  static const Color textGrey = Color(0xFF778198);
  static const double mobileBreakpoint = 650;
  static const double maxContentWidth = 1500;
  @override
  State<ReferEarnScreen> createState() => _ReferEarnScreenState();
}

class _ReferEarnScreenState extends State<ReferEarnScreen> {
  late final FreelanceApi _api = widget.api ?? FreelanceApi();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _progress;
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _vendorLinks = [];
  List<Map<String, dynamic>> _serviceLinks = [];
  List<Map<String, dynamic>> _history = [];
  bool _vendorReferralPending = false;

  @override
  void initState() {
    super.initState();
    _loadReferralData();
  }

  @override
  void dispose() {
    if (widget.api == null) _api.dispose();
    super.dispose();
  }

  int? _int(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value');
  double? _double(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value');
  List<Map<String, dynamic>> _items(Map<String, dynamic> data) {
    final list = data['items'];
    return list is List
        ? list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : [];
  }

  Future<void> _loadReferralData({bool showLoading = true}) async {
    if (mounted) {
      setState(() {
        if (showLoading) _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        _api.referralLevelProgress(),
        _api.referralSummary(),
        _api.referralLinks(limit: 100, type: 'vendor'),
        _api.referralLinks(limit: 100, type: 'service'),
        _api.referralPointHistory(limit: 20),
      ]);
      if (!mounted) return;
      setState(() {
        _progress = results[0];
        _summary = results[1];
        // Keep an additional response-side guard so a backend that ignores
        // the filter can never put Service history in the Vendor section.
        _vendorLinks = _items(results[2])
            .where(
              (row) =>
                  row['referral_type']?.toString().toLowerCase() == 'vendor',
            )
            .toList();
        _serviceLinks = _items(results[3])
            .where(
              (row) =>
                  row['referral_type']?.toString().toLowerCase() == 'service',
            )
            .toList();
        _history = _items(results[4]);
        _loading = false;
      });
    } on ApiException {
      if (mounted) {
        setState(() {
          _error =
              'We could not load your referral information. Please try again.';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load referral information.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _trackReferralAction(
    dynamic referralId,
    String eventType,
  ) async {
    final id = referralId?.toString().trim() ?? '';
    if (id.isEmpty) return;
    try {
      await _api.recordReferralAction(referralId: id, eventType: eventType);
    } catch (_) {
      // Copy/share remains available if analytics is temporarily unavailable.
    }
  }

  Future<void> _createLink(String type) async {
    if (type.toLowerCase() == 'customer') {
      _notice(
        'Customer App is coming soon. Customer referrals will be available after launch.',
      );
      return;
    }
    if (type.toLowerCase() != 'vendor') return;
    if (_vendorReferralPending) return;
    setState(() => _vendorReferralPending = true);

    const requestedValidityDays = 15;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Invite a Vendor'),
        content: const Text(
          'Generate a Vendor link. If you already have an active link, '
          'it will be reused until it expires.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      if (mounted) setState(() => _vendorReferralPending = false);
      return;
    }

    try {
      final link = await _api.createReferralLink(
        type: 'vendor',
        validityDays: requestedValidityDays,
      );
      final referralCode = link['referral_code']?.toString() ?? '';
      final url = link['url']?.toString() ?? '';
      final uri = Uri.tryParse(url);
      final expiresAt = DateTime.tryParse(link['expires_at']?.toString() ?? '');
      final status = link['status']?.toString().toLowerCase();
      final reusedExisting = link['reused_existing'] == true;
      final validityDays = _int(link['validity_days']) ?? 15;

      if (status != 'active' ||
          (expiresAt != null && !expiresAt.isAfter(DateTime.now()))) {
        if (mounted) {
          _notice(
            'This invitation is invalid or expired. Please create a new invitation.',
          );
        }
        return;
      }

      if (referralCode.isEmpty ||
          uri == null ||
          !VendorReferralUrl.matchesTracking(
            uri: uri,
            referralCode: referralCode,
          ) ||
          expiresAt == null) {
        if (mounted) {
          _notice(
            'We could not prepare a valid Vendor invitation. Please try again.',
          );
        }
        return;
      }

      await _loadReferralData(showLoading: false);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(
            reusedExisting
                ? 'Your existing Vendor link is ready.'
                : 'Your Vendor link is ready.',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Vendor App Referral Link'),
              const SizedBox(height: 8),
              SelectableText(
                url,
                style: const TextStyle(
                  color: Color(0xFF2449A5),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text('Referral code: $referralCode'),
              const SizedBox(height: 4),
              Text(reusedExisting ? 'Existing link reused.' : 'New link created.'),
              const SizedBox(height: 4),
              Text('Valid for $validityDays days.'),
              const SizedBox(height: 4),
              Text('Valid until: ${_formatExpiry(expiresAt)}'),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: url));
                await _trackReferralAction(link['referral_id'], 'copy');
                if (dialog.mounted) Navigator.pop(dialog);
                if (mounted) _notice('Vendor referral link copied.');
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy Link'),
            ),
            TextButton.icon(
              onPressed: () async {
                await _trackReferralAction(
                  link['referral_id'],
                  'share_initiated',
                );
                try {
                  final shareLink = widget.shareLink;
                  if (shareLink != null) {
                    await shareLink(
                      'AM5 ROYAL Vendor App invitation:\n$url',
                    );
                  } else {
                    await SharePlus.instance.share(
                      ShareParams(
                        text:
                            'AM5 ROYAL Vendor App invitation:\n$url',
                        subject: 'AM5 ROYAL Vendor referral',
                      ),
                    );
                  }
                } catch (_) {
                  if (dialog.mounted) Navigator.pop(dialog);
                  if (mounted) _notice('Unable to open sharing options.');
                  return;
                }
                if (dialog.mounted) Navigator.pop(dialog);
              },
              icon: const Icon(Icons.share_rounded),
              label: const Text('Share Link'),
            ),
            TextButton.icon(
              onPressed: () async {
                try {
                  final openVendorLink = widget.openVendorLink;
                  final opened = openVendorLink != null
                      ? await openVendorLink(uri)
                      : await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                          webOnlyWindowName: kIsWeb ? '_blank' : null,
                        );
                  if (!opened && mounted) {
                    _notice('Unable to open the Play Store listing.');
                  }
                } catch (_) {
                  if (mounted) {
                    _notice('Unable to open the Play Store listing.');
                  }
                }
                if (dialog.mounted) Navigator.pop(dialog);
              },
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open Play Store'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } on ApiException {
      if (mounted) {
        _notice(
          'We could not create your Vendor invitation right now. Please try again.',
        );
      }
    } catch (_) {
      if (mounted) _notice('The Vendor referral link could not be created.');
    } finally {
      if (mounted) setState(() => _vendorReferralPending = false);
    }
  }

  String _formatExpiry(DateTime value) {
    final local = value.toLocal();
    final date =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    return '$date $time (local time)';
  }

  String _status(Map<String, dynamic> row) {
    final expiry = DateTime.tryParse(row['expires_at']?.toString() ?? '')
        ?.toLocal();
    if ((row['status']?.toString().toLowerCase() ?? '') != 'active' ||
        (expiry != null && !expiry.isAfter(DateTime.now()))) {
      return 'Expired';
    }
    if (expiry == null) return 'Active';
    final left = expiry.difference(DateTime.now());
    final daysLeft = (left.inSeconds / Duration.secondsPerDay).ceil();
    return 'Active · $daysLeft ${daysLeft == 1 ? 'day' : 'days'} left';
  }

  void _notice(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );

  @override
  Widget build(BuildContext context) {
    final p = _progress ?? const <String, dynamic>{};
    final s = _summary ?? const <String, dynamic>{};
    return Scaffold(
      backgroundColor: ReferEarnScreen.backgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mobile =
                constraints.maxWidth < ReferEarnScreen.mobileBreakpoint;
            return SingleChildScrollView(
              padding: EdgeInsets.all(mobile ? 14 : 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: ReferEarnScreen.maxContentWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const ReferEarnHeader(),
                      const SizedBox(height: 28),
                      _sectionTitle(
                        'Start Referring',
                        'Choose who you want to refer to AM5 ROYAL.',
                      ),
                      const SizedBox(height: 16),
                      _pair(
                        mobile,
                        const ReferCustomerCard(),
                        ReferVendorCard(
                          onRefer: () => _createLink('vendor'),
                          isLoading: _vendorReferralPending,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _sectionTitle(
                        'How It Works',
                        'Learn how customer and vendor referrals work.',
                      ),
                      const SizedBox(height: 16),
                      _pair(
                        mobile,
                        const CustomerHowItWorks(),
                        const VendorHowItWorks(),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: _sectionTitle(
                              'Your Rewards',
                              'Points, balances, and tier progress from your account.',
                            ),
                          ),
                          IconButton(
                            onPressed: _loading ? null : _loadReferralData,
                            tooltip: 'Refresh',
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_error != null)
                        _errorView(_error!)
                      else ...[
                        ReferralPointsCard(
                          points: _int(p['current_points']),
                          levelName: p['current_level']?.toString(),
                          nextLevelName: p['next_level']?.toString(),
                          pointsToNextLevel: _int(
                            p['points_required_to_next_level'],
                          ),
                          progressPercentage: _double(p['progress_percentage']),
                          isLoading: _loading,
                        ),
                        const SizedBox(height: 14),
                        _summaryCard(s),
                        const SizedBox(height: 22),
                        _sectionTitle(
                          'Your Vendor Referrals',
                          'Invite Vendors to install AM5 ROYAL from Google Play using your referral link.',
                        ),
                        const SizedBox(height: 12),
                        if (_loading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_vendorLinks.isEmpty)
                          _empty('No Vendor referrals yet.')
                        else
                          ..._vendorLinks.map(
                            (row) => _linkCard(row, vendor: true),
                          ),
                        const SizedBox(height: 22),
                        _sectionTitle(
                          'Your Service Referrals',
                          'Track referrals for the services you shared.',
                        ),
                        const SizedBox(height: 12),
                        if (_loading)
                          const SizedBox.shrink()
                        else if (_serviceLinks.isEmpty)
                          _empty('No Service referrals yet.')
                        else
                          ..._serviceLinks.map(
                            (row) => _linkCard(row, vendor: false),
                          ),
                        const SizedBox(height: 26),
                        _sectionTitle(
                          'Points History',
                          'See the points earned through your referral activity.',
                        ),
                        const SizedBox(height: 12),
                        if (_loading)
                          const SizedBox.shrink()
                        else if (_history.isEmpty)
                          _empty('No referral point history yet.')
                        else
                          ..._history.map(_historyCard),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: ReferEarnScreen.textDark,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          height: 1.3,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        subtitle,
        style: const TextStyle(
          color: ReferEarnScreen.textGrey,
          fontSize: 13,
          height: 1.5,
        ),
      ),
    ],
  );
  Widget _pair(bool mobile, Widget first, Widget second) => mobile
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [first, const SizedBox(height: 16), second],
        )
      : IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: first),
              const SizedBox(width: 24),
              Expanded(child: second),
            ],
          ),
        );
  Widget _errorView(String value) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value),
          TextButton.icon(
            onPressed: _loadReferralData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
  Widget _empty(String value) => Card(
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Text(
        value,
        style: const TextStyle(color: ReferEarnScreen.textGrey),
      ),
    ),
  );
  Widget _summaryCard(Map<String, dynamic> data) => Card(
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: _loading
          ? const LinearProgressIndicator()
          : Wrap(
              spacing: 20,
              runSpacing: 12,
              children:
                  <String, String>{
                        'Total points': '${data['total_points'] ?? '—'}',
                        'Available': '${data['available_points'] ?? '—'}',
                        'Pending': '${data['pending_points'] ?? '—'}',
                        'Redeemed': '${data['redeemed_points'] ?? '—'}',
                        'Currency equivalent':
                            data['currency_equivalent'] == null
                            ? '—'
                            : '₹${data['currency_equivalent']}',
                      }.entries
                      .map(
                        (e) => SizedBox(
                          width: 150,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.key,
                                style: const TextStyle(
                                  color: ReferEarnScreen.textGrey,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                e.value,
                                style: const TextStyle(
                                  color: ReferEarnScreen.textDark,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
            ),
    ),
  );
  Widget _linkCard(Map<String, dynamic> row, {required bool vendor}) {
    final code = row['referral_code']?.toString() ?? '';
    final storedUrl = row['url']?.toString() ?? '';
    final url = storedUrl.isNotEmpty
        ? storedUrl
        : vendor && code.isNotEmpty
        ? VendorReferralUrl.buildTracking(referralCode: code).toString()
        : storedUrl;
    final uri = Uri.tryParse(url);
    final expiry = DateTime.tryParse(row['expires_at']?.toString() ?? '');
    final destination = uri == null
        ? 'Destination unavailable'
        : '${uri.host}${uri.path}';
    final shortCode = code.length > 12
        ? '${code.substring(0, 6)}…${code.substring(code.length - 4)}'
        : code;
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  vendor
                      ? 'Vendor referral'
                      : (row['target_service_name']
                                    ?.toString()
                                    .trim()
                                    .isNotEmpty ==
                                true
                            ? row['target_service_name'].toString()
                            : 'Service referral'),
                  style: const TextStyle(
                    color: ReferEarnScreen.textDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                Chip(
                  label: Text(_status(row)),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              'Code: ${shortCode.isEmpty ? '—' : shortCode}',
              style: const TextStyle(color: ReferEarnScreen.textDark),
            ),
            if (code.isNotEmpty && shortCode != code)
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  await _trackReferralAction(row['referral_id'], 'copy');
                  if (mounted) _notice('Full referral code copied.');
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy full code'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'Destination: $destination',
              style: const TextStyle(
                color: ReferEarnScreen.textGrey,
                fontSize: 12,
              ),
            ),
            if (url.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SelectableText(
                  url,
                  style: const TextStyle(
                    color: Color(0xFF2449A5),
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              _expiryLabel(expiry),
              style: const TextStyle(
                color: ReferEarnScreen.textGrey,
                fontSize: 12,
              ),
            ),
            if (url.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: url));
                        await _trackReferralAction(row['referral_id'], 'copy');
                        if (mounted) _notice('Referral link copied.');
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copy Link'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await _trackReferralAction(
                          row['referral_id'],
                          'share_initiated',
                        );
                        try {
                          if (widget.shareLink != null) {
                            await widget.shareLink!(url);
                          } else {
                            await SharePlus.instance.share(
                              ShareParams(text: url),
                            );
                          }
                        } catch (_) {
                          if (mounted) {
                            _notice('Unable to open sharing options.');
                          }
                        }
                      },
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('Share Link'),
                    ),
                    if (vendor)
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            final playStoreUri =
                                Uri.tryParse(url) ??
                                VendorReferralUrl.playStoreListing;
                            final opened = widget.openVendorLink != null
                                ? await widget.openVendorLink!(playStoreUri)
                                : await launchUrl(
                                    playStoreUri,
                                    mode: LaunchMode.platformDefault,
                                    webOnlyWindowName: kIsWeb ? '_blank' : null,
                                  );
                            if (!opened && mounted) {
                              _notice('Unable to open the Play Store listing.');
                            }
                          } catch (_) {
                            if (mounted) {
                              _notice('Unable to open the Play Store listing.');
                            }
                          }
                        },
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Open Play Store'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _expiryLabel(DateTime? expiry) {
    if (expiry == null) return 'Expiry unavailable';
    final now = DateTime.now();
    final remaining = expiry.difference(now);
    final days = (remaining.inSeconds / Duration.secondsPerDay).ceil();
    final left = days <= 0
        ? 'Expired'
        : '$days ${days == 1 ? 'day' : 'days'} left';
    return '$left · Expires ${_formatExpiry(expiry)}';
  }

  Widget _historyCard(Map<String, dynamic> row) => Card(
    color: Colors.white,
    child: ListTile(
      title: Text(row['event_description']?.toString() ?? 'Referral activity'),
      subtitle: Text(
        '${row['status'] ?? '—'} · ${row['created_at'] ?? '—'}${row['amount'] == null ? '' : ' · ₹${row['amount']}'}',
      ),
      trailing: Text(
        '${row['points'] ?? 0} pts',
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: ReferEarnScreen.textDark,
        ),
      ),
    ),
  );
}
