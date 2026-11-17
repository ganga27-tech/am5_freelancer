import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/main_category_model.dart';
import '../../models/sub_category_model.dart';
import '../../../../core/constants/api_constants.dart';
import '../../services/category_service.dart';
import '../../services/link_generation_service.dart';
import '../../services/vendor_navigation_service.dart';
import '../../../../models/generated_link_model.dart';
import '../widgets/remote_service_image.dart';
import '../widgets/sub_category_card.dart';

class SubCategoriesScreen extends StatefulWidget {
  const SubCategoriesScreen({
    super.key,
    this.categoryService,
    this.linkGenerationServiceFactory,
  });

  @visibleForTesting
  final CategoryService? categoryService;

  @visibleForTesting
  final LinkGenerationService Function()? linkGenerationServiceFactory;

  @override
  State<SubCategoriesScreen> createState() => _SubCategoriesScreenState();
}

class _SubCategoriesScreenState extends State<SubCategoriesScreen> {
  static const Color navy = Color(0xFF101D45);
  static const Color royalBlue = Color(0xFF2449A5);
  static const Color pageBackground = Color(0xFFFFF8ED);
  static const Color borderColor = Color(0xFFE5EAF2);
  static const Color mutedText = Color(0xFF718096);
  static const Color successGreen = Color(0xFF218653);

  late final CategoryService _categoryService;
  final TextEditingController _searchController = TextEditingController();

  List<MainCategoryModel> mainCategories = [];
  List<SubCategoryModel> subCategories = [];

  MainCategoryModel? selectedMainCategory;

  String searchQuery = '';

  bool isLoadingCategories = true;
  bool isLoadingSubCategories = false;
  bool hasCategoryError = false;
  bool hasSubCategoryError = false;
  bool homeServicesCategoryUnavailable = false;
  final Set<int> _openingVendorServiceIds = <int>{};
  final Map<int, GeneratedLinkModel> _serviceReferralLinks =
      <int, GeneratedLinkModel>{};
  bool _openingHomeServices = false;

  @override
  void initState() {
    super.initState();
    _categoryService = widget.categoryService ?? CategoryService();
    _loadMainCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _categoryService.dispose();
    super.dispose();
  }

  LinkGenerationService _createLinkGenerationService() =>
      widget.linkGenerationServiceFactory?.call() ?? LinkGenerationService();

  Future<void> _loadMainCategories() async {
    if (!mounted) return;

    setState(() {
      isLoadingCategories = true;
      hasCategoryError = false;
    });

    try {
      final result = await _categoryService.fetchMainCategories();

      if (!mounted) return;

      final previouslySelectedId = selectedMainCategory?.id;
      MainCategoryModel? previouslySelectedCategory;
      MainCategoryModel? homeServicesCategory;
      for (final category in result) {
        if (category.id == previouslySelectedId) {
          previouslySelectedCategory = category;
        }
        if (VendorNavigationService.isHomeServicesCategory(category)) {
          homeServicesCategory = category;
        }
      }
      final initialSelection =
          previouslySelectedCategory ?? homeServicesCategory;

      setState(() {
        mainCategories = result;
        isLoadingCategories = false;
        selectedMainCategory = initialSelection;
        homeServicesCategoryUnavailable = initialSelection == null;
      });

      if (selectedMainCategory != null) {
        await _loadSubCategories(selectedMainCategory!.id);
      }
    } on CategoryServiceException catch (e) {
      if (!mounted) return;

      setState(() {
        isLoadingCategories = false;
        hasCategoryError = true;
      });

      _showMessage(e.message);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isLoadingCategories = false;
        hasCategoryError = true;
      });

      _showMessage('Unable to load categories.');
    }
  }

  Future<void> _loadSubCategories(int categoryId) async {
    if (categoryId <= 0 || !mounted) return;

    setState(() {
      isLoadingSubCategories = true;
      hasSubCategoryError = false;
      subCategories = [];
      searchQuery = '';
      _searchController.clear();
    });

    try {
      final result = await _categoryService.fetchSubCategories(categoryId);

      if (!mounted) return;

      // Ignore an old response if the user selected another category.
      if (selectedMainCategory?.id != categoryId) return;

      setState(() {
        subCategories = result;
        isLoadingSubCategories = false;
      });
    } on CategoryServiceException catch (e) {
      if (!mounted) return;

      if (selectedMainCategory?.id != categoryId) return;

      setState(() {
        isLoadingSubCategories = false;
        hasSubCategoryError = true;
      });

      _showMessage(e.message);
    } catch (_) {
      if (!mounted) return;

      if (selectedMainCategory?.id != categoryId) return;

      setState(() {
        isLoadingSubCategories = false;
        hasSubCategoryError = true;
      });

      _showMessage('Unable to load services.');
    }
  }

  List<SubCategoryModel> get filteredSubCategories {
    final query = searchQuery.trim().toLowerCase();

    if (query.isEmpty) return subCategories;

    return subCategories.where((category) {
      return category.name.toLowerCase().contains(query) ||
          category.slug.toLowerCase().contains(query);
    }).toList();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  Uri? _validatedServiceUri(
    String url, {
    required Uri expectedDestination,
    String? expectedCode,
  }) {
    final uri = Uri.tryParse(url.trim());

    final trackingPath = expectedCode == null
        ? null
        : '/api/v1/referrals/service/click/${Uri.encodeComponent(expectedCode)}';
    final configuredApiUri = Uri.tryParse(ApiConstants.baseUrl);
    final configuredApiOrigin = configuredApiUri?.origin;
    final isProductionApiOrigin = uri?.origin == 'https://api.am5royal.com';
    final isConfiguredApiOrigin =
        configuredApiOrigin != null && uri?.origin == configuredApiOrigin;
    final isLocalApiOrigin =
        configuredApiUri?.scheme == 'http' &&
        uri?.scheme == 'http' &&
        uri?.port == configuredApiUri?.port &&
        const {'127.0.0.1', 'localhost', '10.0.2.2'}.contains(uri?.host);
    if (uri != null &&
        trackingPath != null &&
        (isProductionApiOrigin || isConfiguredApiOrigin || isLocalApiOrigin) &&
        uri.path == trackingPath &&
        uri.query.isEmpty &&
        uri.fragment.isEmpty &&
        uri.userInfo.isEmpty) {
      return uri;
    }

    if (uri == null ||
        !VendorNavigationService.isAllowedReferredServiceUri(uri) ||
        uri.origin != expectedDestination.origin ||
        uri.path != expectedDestination.path ||
        (expectedCode != null && uri.queryParameters['ref'] != expectedCode)) {
      return null;
    }

    return uri;
  }

  bool _isExpired(GeneratedLinkModel link) {
    final expiry = link.expiresAt;
    return expiry != null && !expiry.toUtc().isAfter(DateTime.now().toUtc());
  }

  String _formatIst(DateTime? value) {
    if (value == null) return 'Unavailable';
    final ist = value.toUtc().add(const Duration(hours: 5, minutes: 30));
    final hour = ist.hour % 12 == 0 ? 12 : ist.hour % 12;
    final minute = ist.minute.toString().padLeft(2, '0');
    final day = ist.day.toString().padLeft(2, '0');
    final month = ist.month.toString().padLeft(2, '0');
    final period = ist.hour >= 12 ? 'PM' : 'AM';
    return '$day/$month/${ist.year} $hour:$minute $period IST';
  }

  String _remainingValidity(GeneratedLinkModel link) {
    final expiry = link.expiresAt;
    if (expiry == null) return 'Unavailable';
    final remaining = expiry.toUtc().difference(DateTime.now().toUtc());
    if (remaining <= Duration.zero) return 'Expired';
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    return days > 0 ? '$days days, $hours hours' : '$hours hours';
  }

  Widget _buildReferralMetadata(GeneratedLinkModel link) {
    final status = _isExpired(link) ? 'Expired' : 'Active';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status: $status',
            style: const TextStyle(color: navy, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            'Created: ${_formatIst(link.createdAt)}',
            style: const TextStyle(color: mutedText, fontSize: 12),
          ),
          Text(
            'Expires: ${_formatIst(link.expiresAt)}',
            style: const TextStyle(color: mutedText, fontSize: 12),
          ),
          Text(
            'Validity: ${link.validityDays} days',
            style: const TextStyle(color: mutedText, fontSize: 12),
          ),
          if (link.reusedExisting)
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Text(
                'Existing link reused. Its original expiry was not changed.',
                style: TextStyle(color: mutedText, fontSize: 12),
              ),
            ),
          Text(
            'Remaining: ${_remainingValidity(link)}',
            style: const TextStyle(color: mutedText, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _copyServiceReferralLink(
    GeneratedLinkModel link,
  ) async {
    if (_isExpired(link)) {
      _showMessage('This referral link has expired. Generate a new link.');
      return;
    }
    try {
      await Clipboard.setData(ClipboardData(text: link.url));
      _showMessage('Referral link copied.');
    } catch (_) {
      _showMessage('Unable to copy referral link.');
    }
  }

  Future<void> _shareServiceReferralLink(
    SubCategoryModel service,
    GeneratedLinkModel link,
  ) async {
    if (_isExpired(link)) {
      _showMessage('This referral link has expired. Generate a new link.');
      return;
    }
    final whatsappUri = Uri.https('wa.me', '/', {
      'text': '${service.name}\n${link.url}',
    });
    try {
      final opened = await launchUrl(
        whatsappUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) _showMessage('Unable to open WhatsApp.');
    } catch (_) {
      _showMessage('Unable to open WhatsApp.');
    }
  }

  Future<void> _selectMainCategory(MainCategoryModel category) async {
    if (VendorNavigationService.isHomeServicesCategory(category)) {
      await _openVendorHomeServices();
      return;
    }
    setState(() {
      selectedMainCategory = category;
      homeServicesCategoryUnavailable = false;
    });

    await _loadSubCategories(category.id);
  }

  Future<void> _openVendorHomeServices() async {
    if (_openingHomeServices) {
      return;
    }
    _openingHomeServices = true;
    final uri = VendorNavigationService.homeServicesLanding();
    if (!VendorNavigationService.isAllowedHomeServicesLandingUri(uri)) {
      debugPrint(
        '[vendor-navigation] rejected unverified Home Services destination',
      );
      _openingHomeServices = false;
      if (mounted) {
        _showMessage('Home Services Vendor destination is unavailable.');
      }
      return;
    }
    debugPrint(
      '[vendor-navigation] opening verified Home Services destination: $uri',
    );
    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_self',
      );
      if (!opened && mounted) {
        _showMessage('Unable to open Vendor Home Services.');
      }
    } catch (error) {
      debugPrint(
        '[vendor-navigation] Home Services launch failed (${error.runtimeType})',
      );
      if (mounted) {
        _showMessage('Unable to open Vendor Home Services.');
      }
    } finally {
      _openingHomeServices = false;
    }
  }

  Future<void> _openVendorService(SubCategoryModel service) async {
    if (!_openingVendorServiceIds.add(service.id)) return;

    final mainCategory = selectedMainCategory;
    final destination = mainCategory == null
        ? null
        : VendorNavigationService.homeService(mainCategory, service);

    debugPrint(
      '[vendor-navigation] service_id=${service.id} '
      'service_name="${service.name}" '
      'expected_path="${destination?.path ?? 'unmapped'}"',
    );

    if (destination == null ||
        !VendorNavigationService.isAllowedServiceUri(destination)) {
      debugPrint(
        '[vendor-navigation] rejected unverified service destination '
        'service_id=${service.id}',
      );
      _openingVendorServiceIds.remove(service.id);
      if (mounted) {
        _showMessage(
          'This service does not have a verified Vendor destination.',
        );
      }
      return;
    }

    try {
      final opened = await launchUrl(
        destination,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (!opened) {
        debugPrint(
          '[vendor-navigation] launch was not accepted '
          'service_id=${service.id} launcher_path="${destination.path}"',
        );
        if (mounted) {
          _showMessage('Unable to open the selected Vendor service.');
        }
      }
    } catch (error) {
      debugPrint(
        '[vendor-navigation] launch failed service_id=${service.id} '
        '(${error.runtimeType})',
      );
      if (mounted) {
        _showMessage('Unable to open the selected Vendor service.');
      }
    } finally {
      _openingVendorServiceIds.remove(service.id);
    }
  }

  Future<void> _showGenerateLinkDialog(SubCategoryModel category) async {
    if (!category.referralEligibility) {
      _showMessage('Referral is not available for this service.');
      return;
    }

    int selectedDays = 7;
    const referralType = 'service';

    bool isGenerating = false;
    bool isCopying = false;
    bool isSharing = false;
    bool isOpening = false;
    bool isCopied = false;

    GeneratedLinkModel? generatedLink;

    final linkService = _createLinkGenerationService();

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: !isGenerating,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              final mainCategory = selectedMainCategory;
              final destination = mainCategory == null
                  ? null
                  : VendorNavigationService.homeService(mainCategory, category);
              final uri = generatedLink == null
                  ? null
                  : Uri.tryParse(generatedLink!.url);

              Future<void> generateLink() async {
                if (isGenerating) return;

                setDialogState(() {
                  isGenerating = true;
                  isCopied = false;
                  generatedLink = null;
                });

                try {
                  final selectedDestination = destination;
                  if (selectedDestination == null ||
                      !VendorNavigationService.isAllowedServiceUri(
                        selectedDestination,
                      )) {
                    throw const FormatException(
                      'The selected service has no verified Vendor destination.',
                    );
                  }

                  final result = await linkService.generateLink(
                    referralType: referralType,
                    targetSubServiceId: category.id,
                    validityDays: selectedDays,
                    targetServiceUrl: selectedDestination.toString(),
                  );

                  if (!mounted || !dialogContext.mounted) return;

                  if (result.referralType != referralType ||
                      result.targetServiceCategoryId !=
                          VendorNavigationService.homeServicesCategoryId ||
                      result.targetServiceId != category.id) {
                    throw const FormatException(
                      'The referral response does not match the selected service.',
                    );
                  }

                  final referredDestination =
                      VendorNavigationService.withReferralCode(
                        selectedDestination,
                        result.referralCode,
                      );
                  if (referredDestination == null) {
                    throw const FormatException(
                      'Unable to prepare the selected Vendor referral URL.',
                    );
                  }

                  final generatedUri = _validatedServiceUri(
                    result.url,
                    expectedDestination: selectedDestination,
                    expectedCode: result.referralCode,
                  );

                  if (generatedUri == null ||
                      referredDestination.path != selectedDestination.path) {
                    throw const FormatException(
                      'The backend referral URL does not match the selected Vendor destination.',
                    );
                  }

                  setState(() {
                    _serviceReferralLinks[category.id] = result;
                  });
                  Navigator.of(dialogContext).pop();
                  var opened = false;
                  try {
                    opened = await launchUrl(
                      referredDestination,
                      mode: LaunchMode.platformDefault,
                      webOnlyWindowName: '_self',
                    );
                  } catch (_) {
                    opened = false;
                  }
                  if (!opened && mounted) {
                    _showMessage(
                      'Referral was saved, but the Vendor service could not be opened. Copy the link from the service card.',
                    );
                  }
                } on LinkGenerationException catch (e) {
                  if (!dialogContext.mounted) return;

                  setDialogState(() {
                    isGenerating = false;
                  });

                  _showMessage(e.message);
                } catch (_) {
                  if (!dialogContext.mounted) return;

                  setDialogState(() {
                    isGenerating = false;
                  });

                  _showMessage('Unable to generate referral link.');
                }
              }

              return Dialog(
                backgroundColor: Colors.white,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF0FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.link_rounded,
                                  color: royalBlue,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Generate Referral Link',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: navy,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Create a service referral link',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: mutedText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: isGenerating
                                    ? null
                                    : () => Navigator.pop(dialogContext),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            category.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: navy,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Referral Type',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: navy,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Service referral for ${category.name}',
                            style: TextStyle(fontSize: 13, color: mutedText),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Link Validity',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: navy,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [7, 15].map((days) {
                              final selected = selectedDays == days;

                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: days == 7 ? 10 : 0,
                                  ),
                                  child: OutlinedButton(
                                    onPressed: isGenerating
                                        ? null
                                        : () {
                                            setDialogState(() {
                                              selectedDays = days;
                                              generatedLink = null;
                                              isCopied = false;
                                            });
                                          },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: royalBlue,
                                      backgroundColor: selected
                                          ? const Color(0xFFEAF0FF)
                                          : Colors.white,
                                      side: BorderSide(
                                        color: selected
                                            ? royalBlue
                                            : borderColor,
                                      ),
                                    ),
                                    child: Text('$days Days'),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton(
                              onPressed: isGenerating ? null : generateLink,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: royalBlue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: isGenerating
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Generate Link',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                          if (generatedLink != null && uri != null) ...[
                            const SizedBox(height: 16),
                            _buildReferralMetadata(generatedLink!),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F7FC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: borderColor),
                              ),
                              child: SelectableText(
                                uri.toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: navy,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            Row(
                              children: [
                                // COPY LINK
                                Expanded(
                                  child: SizedBox(
                                    height: 46,
                                    child: OutlinedButton.icon(
                                      onPressed:
                                          generatedLink == null || isCopying
                                          ? null
                                          : () async {
                                              setDialogState(() {
                                                isCopying = true;
                                              });

                                              try {
                                                await Clipboard.setData(
                                                  ClipboardData(
                                                    text: uri.toString(),
                                                  ),
                                                );
                                                try {
                                                  await linkService
                                                      .recordAction(
                                                        referralId:
                                                            generatedLink!
                                                                .referralId,
                                                        eventType: 'copy',
                                                      );
                                                } catch (_) {
                                                  // Copy remains usable if tracking is temporarily unavailable.
                                                }

                                                if (!dialogContext.mounted) {
                                                  return;
                                                }

                                                setDialogState(() {
                                                  isCopied = true;
                                                });

                                                _showMessage(
                                                  'Link copied successfully.',
                                                );
                                              } catch (_) {
                                                _showMessage(
                                                  'Unable to copy link.',
                                                );
                                              } finally {
                                                if (dialogContext.mounted) {
                                                  setDialogState(() {
                                                    isCopying = false;
                                                  });
                                                }
                                              }
                                            },
                                      icon: Icon(
                                        isCopied
                                            ? Icons.check_circle_rounded
                                            : Icons.copy_rounded,
                                        size: 17,
                                      ),
                                      label: Text(
                                        isCopying
                                            ? 'Copying...'
                                            : isCopied
                                            ? 'Copied!'
                                            : 'Copy Link',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: isCopied
                                            ? successGreen
                                            : royalBlue,
                                        side: BorderSide(
                                          color: isCopied
                                              ? successGreen
                                              : royalBlue,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 10),

                                // SHARE LINK
                                Expanded(
                                  child: SizedBox(
                                    height: 46,
                                    child: OutlinedButton.icon(
                                      onPressed:
                                          generatedLink == null ||
                                              isSharing ||
                                              _isExpired(generatedLink!)
                                          ? null
                                          : () async {
                                              setDialogState(() {
                                                isSharing = true;
                                              });

                                              try {
                                                if (_isExpired(
                                                  generatedLink!,
                                                )) {
                                                  _showMessage(
                                                    'This referral link has expired.',
                                                  );
                                                  return;
                                                }
                                                try {
                                                  await linkService
                                                      .recordAction(
                                                        referralId:
                                                            generatedLink!
                                                                .referralId,
                                                        eventType:
                                                            'share_initiated',
                                                      );
                                                } catch (_) {
                                                  // The event records opening the share sheet, not delivery.
                                                }
                                                await SharePlus.instance.share(
                                                  ShareParams(
                                                    text:
                                                        '${category.name}\n${uri.toString()}',
                                                    subject:
                                                        '${category.name} - AM5 ROYAL',
                                                  ),
                                                );
                                              } catch (_) {
                                                _showMessage(
                                                  'Unable to share link.',
                                                );
                                              } finally {
                                                if (dialogContext.mounted) {
                                                  setDialogState(() {
                                                    isSharing = false;
                                                  });
                                                }
                                              }
                                            },
                                      icon: const Icon(
                                        Icons.share_rounded,
                                        size: 17,
                                      ),
                                      label: Text(
                                        isSharing ? 'Sharing...' : 'Share Link',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: royalBlue,
                                        side: const BorderSide(
                                          color: royalBlue,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: ElevatedButton(
                                onPressed: isOpening
                                    ? null
                                    : () async {
                                        setDialogState(() {
                                          isOpening = true;
                                        });

                                        try {
                                          final link = generatedLink;
                                          if (link == null ||
                                              _isExpired(link)) {
                                            _showMessage(
                                              'This referral link has expired.',
                                            );
                                            return;
                                          }
                                          final validation = await linkService
                                              .validateReferralCode(
                                                link.referralCode,
                                              );
                                          if (validation['valid'] != true) {
                                            final state = validation['status']
                                                ?.toString();
                                            _showMessage(
                                              state == 'expired'
                                                  ? 'This referral link has expired.'
                                                  : 'This referral link is invalid.',
                                            );
                                            return;
                                          }
                                          final opened = await launchUrl(
                                            uri,
                                            mode: LaunchMode.platformDefault,
                                          );

                                          if (!dialogContext.mounted) {
                                            return;
                                          }

                                          setDialogState(() {
                                            isOpening = false;
                                          });

                                          if (!opened) {
                                            _showMessage(
                                              'Unable to open referral link.',
                                            );
                                          }
                                        } catch (_) {
                                          if (!dialogContext.mounted) {
                                            return;
                                          }

                                          setDialogState(() {
                                            isOpening = false;
                                          });

                                          _showMessage(
                                            'Unable to open referral link.',
                                          );
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: royalBlue,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  isOpening
                                      ? 'Opening...'
                                      : 'Open Referral Page',
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Center(
                            child: TextButton(
                              onPressed: isGenerating
                                  ? null
                                  : () => Navigator.pop(dialogContext),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  color: mutedText,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      linkService.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: width >= 1200
                    ? 32
                    : width >= 600
                    ? 22
                    : 14,
                vertical: 20,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildSectionTitle(
                        title: 'Main Services',
                        subtitle: 'Choose a category to explore services',
                      ),
                      const SizedBox(height: 14),
                      _buildMainCategories(width),
                      const SizedBox(height: 28),
                      _buildServicesHeader(),
                      const SizedBox(height: 16),
                      _buildSearchField(),
                      const SizedBox(height: 18),
                      _buildSubCategoryGrid(width),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 23),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2449A5), Color(0xFF142B6F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Services',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Browse categories and explore available services.',
            style: TextStyle(
              color: Color(0xFFDCE5FF),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: navy,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: mutedText, fontSize: 12)),
      ],
    );
  }

  Widget _buildMainCategories(double width) {
    if (isLoadingCategories) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: CircularProgressIndicator(color: royalBlue),
        ),
      );
    }

    if (hasCategoryError) {
      return _buildRetryCard(
        message: 'Unable to load categories.',
        onRetry: _loadMainCategories,
      );
    }

    if (mainCategories.isEmpty) {
      return _buildEmptyCard('No active categories available.');
    }

    final columns = width >= 1200
        ? 6
        : width >= 950
        ? 5
        : width >= 700
        ? 4
        : width >= 480
        ? 3
        : 2;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: mainCategories.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 112,
      ),
      itemBuilder: (context, index) {
        final category = mainCategories[index];

        final isSelected = selectedMainCategory?.id == category.id;

        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _selectMainCategory(category),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? royalBlue : borderColor,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: RemoteServiceImage(
                      url: category.categoryImageUrl,
                      label: category.name,
                      fit: BoxFit.contain,
                      backgroundColor: Colors.white,
                      foregroundColor: royalBlue,
                      indicatorSize: 20,
                      fallbackIconSize: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? royalBlue : navy,
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildServicesHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                selectedMainCategory?.name ?? 'Services',
                style: const TextStyle(
                  color: navy,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${filteredSubCategories.length} services available',
                style: const TextStyle(color: mutedText, fontSize: 12),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFE4F7ED),
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, color: successGreen, size: 14),
              SizedBox(width: 5),
              Text(
                'Available',
                style: TextStyle(
                  color: successGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          searchQuery = value;
        });
      },
      decoration: InputDecoration(
        hintText: 'Search services...',
        hintStyle: const TextStyle(fontSize: 13, color: mutedText),
        prefixIcon: const Icon(Icons.search_rounded, color: royalBlue),
        suffixIcon: searchQuery.isNotEmpty
            ? IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    searchQuery = '';
                  });
                },
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: royalBlue, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildSubCategoryGrid(double width) {
    if (homeServicesCategoryUnavailable) {
      return _buildRetryCard(
        message: 'Home Services is unavailable in the service catalog.',
        onRetry: _loadMainCategories,
      );
    }

    if (isLoadingSubCategories) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(36),
          child: CircularProgressIndicator(color: royalBlue),
        ),
      );
    }

    if (hasSubCategoryError) {
      return _buildRetryCard(
        message: 'Unable to load services.',
        onRetry: () {
          final id = selectedMainCategory?.id;
          if (id != null) {
            _loadSubCategories(id);
          }
        },
      );
    }

    final categories = filteredSubCategories;

    if (categories.isEmpty) {
      return _buildEmptyCard(
        searchQuery.isNotEmpty
            ? 'No services match your search.'
            : 'No active services available in this category.',
      );
    }

    final columns = width >= 900
        ? 4
        : width >= 520
        ? 2
        : 1;
    final hasReferralDetails = categories.any(
      (category) => _serviceReferralLinks.containsKey(category.id),
    );

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        mainAxisExtent: hasReferralDetails ? 460 : 222,
      ),
      itemBuilder: (context, index) {
        final category = categories[index];

        return SubCategoryCard(
          category: category,
          referralLink: _serviceReferralLinks[category.id],
          onCopyReferralLink: _copyServiceReferralLink,
          onWhatsAppShare: (link) =>
              _shareServiceReferralLink(category, link),
          onGenerateLink: () => _showGenerateLinkDialog(category),
          onOpenVendor: category.activeStatus
              ? () => _openVendorService(category)
              : null,
        );
      },
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 42, color: mutedText),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: navy,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetryCard({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 40, color: mutedText),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: navy, fontSize: 13),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
