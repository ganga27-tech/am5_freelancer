import 'dart:async';

import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// DASHBOARD BANNER MODEL
/// ---------------------------------------------------------------------------

@immutable
class DashboardBanner {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String? mobileImageUrl;
  final String placement;
  final String targetAudience;
  final String actionType;
  final String? actionValue;
  final int priority;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool active;

  const DashboardBanner({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    this.mobileImageUrl,
    required this.placement,
    required this.targetAudience,
    required this.actionType,
    this.actionValue,
    required this.priority,
    this.startDate,
    this.endDate,
    required this.active,
  });

  /// Backward-compatible getter.
  String? get redirectUrl => actionValue;

  factory DashboardBanner.fromJson(Map<String, dynamic> json) {
    String requiredString(String key) {
      final value = json[key];

      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Invalid or missing banner field: $key');
      }

      return value.trim();
    }

    String optionalString(String key) {
      final value = json[key];

      if (value == null) return '';

      if (value is! String) {
        throw FormatException('Invalid banner field: $key');
      }

      return value.trim();
    }

    String? nullableString(String key) {
      final value = json[key];

      if (value == null) return null;

      if (value is! String) {
        throw FormatException('Invalid banner field: $key');
      }

      final result = value.trim();

      return result.isEmpty ? null : result;
    }

    void validateImageUrl(String value, String field) {
      final uri = Uri.tryParse(value);

      if (uri == null ||
          !uri.hasAuthority ||
          uri.host.isEmpty ||
          (uri.scheme != 'https' && uri.scheme != 'http') ||
          uri.userInfo.isNotEmpty) {
        throw FormatException('Invalid banner image URL: $field');
      }
    }

    DateTime? parseDate(String key) {
      final value = nullableString(key);

      if (value == null) return null;

      final date = DateTime.tryParse(value);

      if (date == null) {
        throw FormatException('Invalid banner date: $key');
      }

      return date;
    }

    final id = requiredString('id');
    final imageUrl = requiredString('image_url');

    validateImageUrl(imageUrl, 'image_url');

    final mobileImageUrl = nullableString('mobile_image_url');

    if (mobileImageUrl != null) {
      validateImageUrl(mobileImageUrl, 'mobile_image_url');
    }

    final priorityValue = json['priority'];

    if (priorityValue is! int) {
      throw const FormatException('Invalid banner priority.');
    }

    final activeValue = json['active'];

    if (activeValue is! bool) {
      throw const FormatException('Invalid banner active status.');
    }

    final startDate = parseDate('start_date');
    final endDate = parseDate('end_date');

    if (startDate != null && endDate != null && endDate.isBefore(startDate)) {
      throw const FormatException(
        'Banner end date cannot be before start date.',
      );
    }

    return DashboardBanner(
      id: id,
      title: requiredString('title'),
      description: optionalString('subtitle'),
      imageUrl: imageUrl,
      mobileImageUrl: mobileImageUrl,
      placement: requiredString('placement'),
      targetAudience: requiredString('target_audience'),
      actionType: requiredString('action_type'),
      actionValue: nullableString('action_value'),
      priority: priorityValue,
      startDate: startDate,
      endDate: endDate,
      active: activeValue,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': description,
      'image_url': imageUrl,
      'mobile_image_url': mobileImageUrl,
      'placement': placement,
      'target_audience': targetAudience,
      'action_type': actionType,
      'action_value': actionValue,
      'priority': priority,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'active': active,
    };
  }

  /// Checks whether the banner is eligible for display.
  bool get isCurrentlyActive {
    if (!active) return false;

    final now = DateTime.now();

    if (startDate != null && now.isBefore(startDate!)) {
      return false;
    }

    if (endDate != null && now.isAfter(endDate!)) {
      return false;
    }

    return true;
  }
}

/// ---------------------------------------------------------------------------
/// DASHBOARD BANNER CAROUSEL
/// ---------------------------------------------------------------------------

class DashboardBannerSection extends StatefulWidget {
  final List<DashboardBanner> banners;

  final ValueChanged<DashboardBanner>? onBannerTap;

  final Duration autoSlideDuration;

  final bool enableAutoSlide;

  const DashboardBannerSection({
    super.key,
    required this.banners,
    this.onBannerTap,
    this.autoSlideDuration = const Duration(seconds: 5),
    this.enableAutoSlide = true,
  });

  @override
  State<DashboardBannerSection> createState() => _DashboardBannerSectionState();
}

class _DashboardBannerSectionState extends State<DashboardBannerSection> {
  static const Color _royalBlue = Color(0xFF2449A5);

  final PageController _pageController = PageController();

  Timer? _autoSlideTimer;

  int _currentPage = 0;

  bool _isPaused = false;

  List<DashboardBanner> get _validBanners {
    final now = DateTime.now();

    final banners = widget.banners.where((banner) {
      final uri = Uri.tryParse(banner.imageUrl);

      final validImageUrl =
          uri != null &&
          uri.hasAuthority &&
          uri.host.isNotEmpty &&
          (uri.scheme == 'https' || uri.scheme == 'http') &&
          uri.userInfo.isEmpty;

      if (!validImageUrl || !banner.active) {
        return false;
      }

      if (banner.startDate != null && now.isBefore(banner.startDate!)) {
        return false;
      }

      if (banner.endDate != null && now.isAfter(banner.endDate!)) {
        return false;
      }

      return true;
    }).toList();

    banners.sort((a, b) => b.priority.compareTo(a.priority));

    return List.unmodifiable(banners);
  }

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  @override
  void didUpdateWidget(covariant DashboardBannerSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.banners != widget.banners ||
        oldWidget.enableAutoSlide != widget.enableAutoSlide ||
        oldWidget.autoSlideDuration != widget.autoSlideDuration) {
      _currentPage = 0;
      _isPaused = false;

      _autoSlideTimer?.cancel();

      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }

      _startAutoSlide();
    }
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();

    if (!widget.enableAutoSlide ||
        widget.autoSlideDuration <= Duration.zero ||
        _validBanners.length < 2) {
      return;
    }

    _autoSlideTimer = Timer.periodic(widget.autoSlideDuration, (_) {
      if (!mounted || _isPaused || !_pageController.hasClients) {
        return;
      }

      final banners = _validBanners;

      if (banners.length < 2) return;

      final nextPage = (_currentPage + 1) % banners.length;

      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _goToPage(int index) {
    if (!_pageController.hasClients) return;

    final banners = _validBanners;

    if (index < 0 || index >= banners.length) return;

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    if (!mounted) return;

    setState(() {
      _currentPage = index;
    });
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = _validBanners;

    if (banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final isMobile = width < 600;
        final isTablet = width >= 600 && width < 1024;

        final bannerHeight = isMobile
            ? 165.0
            : isTablet
            ? 215.0
            : 245.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
              child: SizedBox(
                width: double.infinity,
                height: bannerHeight,
                child: MouseRegion(
                  onEnter: (_) {
                    _isPaused = true;
                  },
                  onExit: (_) {
                    _isPaused = false;
                  },
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: banners.length,
                    physics: const PageScrollPhysics(),
                    onPageChanged: _onPageChanged,
                    itemBuilder: (context, index) {
                      final banner = banners[index];

                      return _BannerCard(
                        banner: banner,
                        height: bannerHeight,
                        availableWidth: width,
                        isMobile: isMobile,
                        onTap: widget.onBannerTap == null
                            ? null
                            : () => widget.onBannerTap!(banner),
                      );
                    },
                  ),
                ),
              ),
            ),

            if (banners.length > 1) ...[
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(banners.length, (index) {
                  final isActive = index == _currentPage;

                  return Semantics(
                    button: true,
                    label: 'Show banner ${index + 1}',
                    selected: isActive,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _goToPage(index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 6,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: isActive ? 24 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: isActive
                                ? _royalBlue
                                : const Color(0xFFCBD4E8),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// ---------------------------------------------------------------------------
/// INDIVIDUAL BANNER CARD
/// ---------------------------------------------------------------------------

class _BannerCard extends StatelessWidget {
  final DashboardBanner banner;

  final double height;

  final double availableWidth;

  final bool isMobile;

  final VoidCallback? onTap;

  const _BannerCard({
    required this.banner,
    required this.height,
    required this.availableWidth,
    required this.isMobile,
    this.onTap,
  });

  static const Color _navy = Color(0xFF101D45);
  static const Color _gold = Color(0xFFFFD78A);

  @override
  Widget build(BuildContext context) {
    final hasTitle = banner.title.trim().isNotEmpty;
    final hasDescription = banner.description.trim().isNotEmpty;

    final mobileUrl = banner.mobileImageUrl;

    final selectedImageUrl =
        isMobile && mobileUrl != null && mobileUrl.isNotEmpty
        ? mobileUrl
        : banner.imageUrl;

    final textMaxWidth = availableWidth * (isMobile ? 0.75 : 0.55);

    return Material(
      color: _navy,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              selectedImageUrl,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stackTrace) {
                return const _BannerImageFallback();
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }

                final expectedBytes = loadingProgress.expectedTotalBytes;

                final progress = expectedBytes != null && expectedBytes > 0
                    ? loadingProgress.cumulativeBytesLoaded / expectedBytes
                    : null;

                return ColoredBox(
                  color: _navy,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _gold,
                      value: progress,
                    ),
                  ),
                );
              },
            ),

            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xE6101D45),
                    Color(0x99101D45),
                    Color(0x00101D45),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.all(isMobile ? 18 : 30),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: textMaxWidth,
                    maxHeight: height - (isMobile ? 36 : 60),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasTitle)
                        Text(
                          banner.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 19 : 29,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                          ),
                        ),

                      if (hasTitle && hasDescription) const SizedBox(height: 9),

                      if (hasDescription)
                        Text(
                          banner.description,
                          maxLines: isMobile ? 2 : 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.94),
                            fontSize: isMobile ? 11 : 14,
                            height: 1.5,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            if (onTap != null)
              const Positioned(
                right: 18,
                bottom: 16,
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// IMAGE FALLBACK
/// ---------------------------------------------------------------------------

class _BannerImageFallback extends StatelessWidget {
  const _BannerImageFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF101D45),
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.white70,
          size: 36,
        ),
      ),
    );
  }
}
