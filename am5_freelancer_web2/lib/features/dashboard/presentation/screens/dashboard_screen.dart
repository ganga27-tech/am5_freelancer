import 'package:flutter/material.dart';

import '../../../../app/routes.dart';
import '../widgets/dashboard_sidebar.dart';
import '../widgets/customer_app_card.dart';
import '../widgets/vendor_app_card.dart';
import '../widgets/freelancer_benefits.dart';
import '../widgets/demo_video_section.dart';
import '../widgets/dashboard_banner_section.dart';
import '../../models/dashboard_menu_item.dart';
import '../../../sub_categories/presentation/screens/sub_categories_screen.dart';
import '../../../refer_earn/presentation/screens/refer_earn_screen.dart';
import '../../../profile/presentation/screens/freelancer_profile_screen.dart';
import '../../../app_installation/presentation/screens/app_installation_screen.dart';
import '../../../rewards_commission/presentation/screens/rewards_overview_screen.dart';
import '../../../earning_wallet/presentation/screens/earning_wallet_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../data/dashboard_banner_service.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/freelance_api.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/network/session_events.dart';

String formatDashboardWelcomeName(Map<String, dynamic> profile) {
  final fullName = profile['full_name']?.toString().trim() ?? '';
  final firstName = profile['first_name']?.toString().trim() ?? '';
  final lastName = profile['last_name']?.toString().trim() ?? '';
  final sourceName = fullName.isNotEmpty
      ? fullName
      : [firstName, lastName].where((part) => part.isNotEmpty).join(' ');
  if (sourceName.isEmpty) return 'Freelancer';

  return sourceName
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map((part) {
        final runes = part.runes.toList();
        if (runes.isEmpty) return '';
        final initial = String.fromCharCode(runes.first).toUpperCase();
        final remainder = String.fromCharCodes(runes.skip(1)).toLowerCase();
        return '$initial$remainder';
      })
      .join(' ');
}

class DashboardScreen extends StatefulWidget {
  final String initialMenu;

  const DashboardScreen({super.key, this.initialMenu = 'Home'});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const Color navy = Color(0xFF101D45);
  static const Color textDark = Color(0xFF17233F);
  static const Color textGrey = Color(0xFF778198);

  static const Color background = Color(0xFFFFF8ED);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late String selectedMenu;
  late final DashboardBannerService _bannerService;

  List<DashboardBanner> _banners = [];

  bool _isBannersLoading = true;
  String? _bannerError;

  bool showDesktopSidebar = true;
  bool hasUnreadNotifications = false;
  List<Map<String, dynamic>> _notifications = const [];
  String? _notificationError;
  bool _notificationsLoading = false;
  final FreelanceApi _freelanceApi = FreelanceApi();
  Map<String, dynamic>? _homeSummary;
  bool _summaryLoading = true;
  String? _summaryError;

  // Maps menu labels to their registered application routes.
  static const Map<String, String> _menuRoutes = {
    'Home': AppRoutes.dashboard,
    'Dashboard': AppRoutes.dashboard,
    'Services': AppRoutes.services,
    'Sub Categories': AppRoutes.services,
    'Refer & Earn': AppRoutes.referEarn,
    'App Installation & Activation': AppRoutes.appInstallationActivation,
    'Earnings & Wallet': AppRoutes.earningsWallet,
    'Rewards & Cashback': AppRoutes.rewardsCashback,
    'Profile': AppRoutes.profile,
    'Settings': AppRoutes.settings,
  };

  @override
  void initState() {
    super.initState();

    selectedMenu = _normalizeMenu(widget.initialMenu);

    _bannerService = DashboardBannerService();

    _loadBanners();
    _loadNotifications();
    _loadHomeSummary();
    _requireSession();
    SessionEvents.expired.addListener(_onSessionExpired);
  }

  void _onSessionExpired() {
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  Future<void> _requireSession() async {
    bool hasSession = false;
    try {
      hasSession = await SecureStorageService().hasAccessToken();
    } catch (_) {
      hasSession = false;
    }
    if (!mounted || hasSession) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  Future<void> _loadBanners() async {
    if (!mounted) return;

    setState(() {
      _isBannersLoading = true;
      _bannerError = null;
    });

    try {
      final banners = await _bannerService.fetchHomeBanners();

      if (!mounted) return;

      setState(() {
        _banners = banners;
        _isBannersLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _bannerError = 'Unable to load banners. Please try again.';
        _isBannersLoading = false;
      });

      debugPrint('Dashboard banner loading failed: $error');
    }
  }

  Future<void> _loadHomeSummary() async {
    if (!mounted) return;
    setState(() {
      _summaryLoading = true;
      _summaryError = null;
    });
    try {
      final values = await Future.wait([
        _freelanceApi.profile(),
        _freelanceApi.walletSummary(),
        _freelanceApi.rewardsSummary(),
        _freelanceApi.referralSummary(),
        _freelanceApi.installationStatistics(),
      ]);
      if (!mounted) return;
      setState(() {
        _homeSummary = {
          'profile': values[0],
          'wallet': values[1],
          'rewards': values[2],
          'referrals': values[3],
          'installations': values[4],
        };
        _summaryLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _summaryError = error.message;
        _summaryLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _summaryError = 'Unable to load your account summary.';
        _summaryLoading = false;
      });
    }
  }

  @override
  void dispose() {
    SessionEvents.expired.removeListener(_onSessionExpired);
    _bannerService.dispose();
    _freelanceApi.dispose();
    super.dispose();
  }

  String _normalizeMenu(String menu) {
    switch (menu) {
      case 'Dashboard':
        return 'Home';
      case 'Sub Categories':
        return 'Services';
      default:
        final validMenus = DashboardMenuItem.items
            .map((item) => item.title)
            .toSet();

        return validMenus.contains(menu) ? menu : 'Home';
    }
  }

  // DASHBOARD MENU NAVIGATION
  void _openMenu(String title) {
    if (!mounted) return;

    final String? route = _menuRoutes[title];

    if (route == null) return;

    final String normalizedTitle = _normalizeMenu(title);

    // Close the mobile drawer before navigating.
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }

    // Do not create another route for the currently selected section.
    if (normalizedTitle == selectedMenu) return;

    // Navigate to a separate named URL.
    Navigator.of(context).pushReplacementNamed(route);
  }

  // NOTIFICATIONS
  Future<void> _openNotifications() async {
    await _loadNotifications();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Notifications'),
          content: SizedBox(
            width: 420,
            child: _notificationsLoading
                ? const Center(child: CircularProgressIndicator())
                : _notificationError != null
                ? Text(_notificationError!)
                : _notifications.isEmpty
                ? const Text('You have no notifications.')
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final item in _notifications)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              item['isRead'] == true
                                  ? Icons.notifications_none
                                  : Icons.notifications_active_outlined,
                            ),
                            title: Text(
                              item['title']?.toString() ?? 'Notification',
                            ),
                            subtitle: Text(item['body']?.toString() ?? ''),
                            onTap: () async {
                              final id = item['notificationId']?.toString();
                              if (id == null || item['isRead'] == true) return;
                              try {
                                await _freelanceApi.markNotificationRead(id);
                                setState(() {
                                  item['isRead'] = true;
                                  hasUnreadNotifications = _notifications.any(
                                    (n) => n['isRead'] != true,
                                  );
                                });
                                setDialogState(() {});
                              } on ApiException catch (error) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error.message)),
                                  );
                                }
                              }
                            },
                          ),
                      ],
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: _notifications.isEmpty
                  ? null
                  : () async {
                      try {
                        await _freelanceApi.markAllNotificationsRead();
                        setState(() {
                          for (final item in _notifications) {
                            item['isRead'] = true;
                          }
                          hasUnreadNotifications = false;
                        });
                        setDialogState(() {});
                      } on ApiException catch (error) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.message)),
                          );
                        }
                      }
                    },
              child: const Text('Mark all read'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadNotifications() async {
    if (mounted) {
      setState(() {
        _notificationsLoading = true;
        _notificationError = null;
      });
    }
    try {
      final page = await _freelanceApi.notifications(limit: 20);
      if (!mounted) return;
      final items = page['items'];
      setState(() {
        _notifications = items is List
            ? items
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
            : [];
        hasUnreadNotifications =
            page['unreadCount'] is num && (page['unreadCount'] as num) > 0;
        _notificationsLoading = false;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _notificationError = error.message;
          _notificationsLoading = false;
        });
      }
    }
  }

  // SEARCH
  Future<void> _openSearch() async {
    final selected = await showSearch<String?>(
      context: context,
      delegate: _MenuSearchDelegate(),
    );

    if (!mounted || selected == null) return;

    _openMenu(selected);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 900;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: background,

          drawer: isMobile
              ? Drawer(
                  width: 265,
                  backgroundColor: navy,
                  child: DashboardSidebar(
                    selectedMenu: selectedMenu,
                    onMenuSelected: _openMenu,
                  ),
                )
              : null,

          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: navy,
            foregroundColor: Colors.white,
            elevation: 0,
            toolbarHeight: 76,
            title: Row(
              children: [
                IconButton(
                  tooltip: 'Toggle navigation',
                  onPressed: () {
                    if (isMobile) {
                      _scaffoldKey.currentState?.openDrawer();
                    } else {
                      setState(() {
                        showDesktopSidebar = !showDesktopSidebar;
                      });
                    }
                  },
                  icon: const Icon(Icons.menu_rounded, size: 29),
                ),

                Expanded(
                  child: Text(
                    selectedMenu,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),

                IconButton(
                  tooltip: 'Search sections',
                  onPressed: _openSearch,
                  icon: const Icon(Icons.search_rounded),
                ),

                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Notifications',
                      onPressed: _openNotifications,
                      icon: const Icon(Icons.notifications_none_rounded),
                    ),
                    if (hasUnreadNotifications)
                      const Positioned(
                        top: 12,
                        right: 12,
                        child: CircleAvatar(
                          radius: 4,
                          backgroundColor: Color(0xFFFFC857),
                        ),
                      ),
                  ],
                ),

                IconButton(
                  tooltip: 'Profile',
                  onPressed: () => _openMenu('Profile'),
                  icon: const Icon(Icons.account_circle_rounded),
                ),
              ],
            ),

            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(2),
              child: Container(
                height: 2,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFB88A36),
                      Color(0xFFFFE2A0),
                      Color(0xFFB88A36),
                    ],
                  ),
                ),
              ),
            ),
          ),

          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isMobile && showDesktopSidebar)
                SizedBox(
                  width: 265,
                  child: DashboardSidebar(
                    selectedMenu: selectedMenu,
                    onMenuSelected: _openMenu,
                  ),
                ),

              Expanded(
                child: Container(
                  color: background,
                  child: _buildSelectedScreen(isMobile),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // SELECTED SECTION
  Widget _buildSelectedScreen(bool isMobile) {
    switch (selectedMenu) {
      case 'Home':
        return _buildDashboard(isMobile);

      case 'Services':
        return const SubCategoriesScreen();

      case 'Refer & Earn':
        return const ReferEarnScreen();

      case 'Profile':
        return const FreelancerProfileScreen();

      case 'App Installation & Activation':
        return const AppInstallationScreen();

      case 'Rewards & Cashback':
        return const RewardsOverviewScreen();

      case 'Earnings & Wallet':
        return const EarningWalletScreen();

      case 'Settings':
        return const SettingsScreen();

      default:
        return _buildDashboard(isMobile);
    }
  }

  Widget _buildBannerContent() {
    if (_isBannersLoading) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_bannerError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            const Text('Unable to load banners.'),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: _loadBanners, child: const Text('Retry')),
          ],
        ),
      );
    }

    return DashboardBannerSection(banners: _banners);
  }

  // HOME DASHBOARD
  Widget _buildDashboard(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBannerContent(),
          const SizedBox(height: 16),
          _buildAccountSummary(isMobile),

          const SizedBox(height: 28),

          _sectionHeading(
            'Your Apps & Rewards',
            'Access your apps and explore your benefits.',
          ),

          const SizedBox(height: 20),

          _buildAppCards(isMobile),

          const SizedBox(height: 28),

          const FreelancerBenefits(),

          const SizedBox(height: 32),

          _sectionHeading(
            'Demo Videos',
            'Watch quick walkthroughs to understand how AM5 ROYAL works.',
          ),

          const SizedBox(height: 20),

          const DemoVideoSection(),
        ],
      ),
    );
  }

  Widget _buildAccountSummary(bool isMobile) {
    final summary = _homeSummary;
    final profile = summary?['profile'] as Map<String, dynamic>?;
    final wallet = summary?['wallet'] as Map<String, dynamic>?;
    final rewards = summary?['rewards'] as Map<String, dynamic>?;
    final referrals = summary?['referrals'] as Map<String, dynamic>?;
    final installations = summary?['installations'] as Map<String, dynamic>?;
    final cards = <(String, String)>[
      ('Available wallet', _homeMoney(wallet?['available_balance'])),
      ('Rewards and cashback', _homeMoney(rewards?['approved_rewards'])),
      ('Referral points', '${referrals?['available_points'] ?? '—'}'),
      (
        'Recorded installs',
        _homeCountTotal(
          installations?['customer_installs'],
          installations?['vendor_installs'],
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                profile == null
                    ? 'Your account summary'
                    : 'Welcome, ${formatDashboardWelcomeName(profile)}',
                style: const TextStyle(
                  color: textDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Refresh account summary',
              onPressed: _summaryLoading ? null : _loadHomeSummary,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        if (_summaryLoading) const LinearProgressIndicator(),
        if (_summaryError != null)
          MaterialBanner(
            content: Text(_summaryError!),
            leading: const Icon(Icons.cloud_off_outlined),
            actions: [
              TextButton(
                onPressed: _summaryLoading ? null : _loadHomeSummary,
                child: const Text('Retry'),
              ),
            ],
          )
        else if (!_summaryLoading && summary == null)
          const Text('Account summary is not available.')
        else if (summary != null)
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = isMobile ? 1 : 2;
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final card in cards)
                    SizedBox(
                      width: width,
                      child: Card(
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                card.$1,
                                style: const TextStyle(color: textGrey),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                card.$2,
                                style: const TextStyle(
                                  color: textDark,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  String _homeMoney(dynamic value) {
    if (value is! num) return '—';
    return '₹${value.toStringAsFixed(2)}';
  }

  String _homeCountTotal(dynamic first, dynamic second) {
    if (first is! num || second is! num) return '—';
    return '${first.toInt() + second.toInt()}';
  }

  Widget _sectionHeading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: textDark,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 7),

        Text(
          subtitle,
          style: const TextStyle(color: textGrey, fontSize: 13, height: 1.5),
        ),
      ],
    );
  }

  // CUSTOMER APP, VENDOR APP AND REWARDS
  Widget _buildAppCards(bool isMobile) {
    final cards = <Widget>[
      const CustomerAppCard(),
      const VendorAppCard(),

      _buildAppCard(
        title: 'Rewards',
        subtitle: 'Explore rewards and cashback.',
        icon: Icons.card_giftcard_rounded,
        iconColor: const Color(0xFF20845C),
        iconBackground: const Color(0xFFE5F7EE),
        buttonText: 'View Rewards',
        onTap: () => _openMenu('Rewards & Cashback'),
      ),
    ];

    if (isMobile) {
      return Column(
        children: [
          for (int i = 0; i < cards.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == cards.length - 1 ? 0 : 15),
              child: cards[i],
            ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < cards.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == cards.length - 1 ? 0 : 16),
              child: cards[i],
            ),
          ),
      ],
    );
  }

  // REWARDS CARD
  Widget _buildAppCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 260,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE2E9F7)),
        boxShadow: [
          BoxShadow(
            color: navy.withValues(alpha: 0.055),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 25),
          ),

          const SizedBox(height: 13),

          Text(
            title,
            style: const TextStyle(
              color: textDark,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: textGrey, fontSize: 12, height: 1.5),
          ),

          const Spacer(),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(onPressed: onTap, child: Text(buttonText)),
          ),
        ],
      ),
    );
  }
}

// DASHBOARD MENU SEARCH
class _MenuSearchDelegate extends SearchDelegate<String?> {
  static const Color royalBlue = Color(0xFF2449A5);

  @override
  String get searchFieldLabel => 'Search dashboard sections';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
        icon: const Icon(Icons.close_rounded),
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back_rounded),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildItems(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildItems(context);
  }

  Widget _buildItems(BuildContext context) {
    final searchQuery = query.trim().toLowerCase();

    final items = DashboardMenuItem.items
        .where((item) => item.title.toLowerCase().contains(searchQuery))
        .toList();

    if (items.isEmpty) {
      return const Center(child: Text('No matching sections found.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 7),
      itemBuilder: (context, index) {
        final item = items[index];

        return ListTile(
          tileColor: Colors.white,
          leading: Icon(item.icon, color: royalBlue),
          title: Text(item.title),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 15),
          onTap: () => close(context, item.title),
        );
      },
    );
  }
}
