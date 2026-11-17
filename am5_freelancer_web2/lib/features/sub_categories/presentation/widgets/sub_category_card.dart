import 'package:flutter/material.dart';

import '../../../../models/generated_link_model.dart';
import '../../models/sub_category_model.dart';
import 'remote_service_image.dart';

class SubCategoryCard extends StatelessWidget {
  final SubCategoryModel category;
  final VoidCallback onGenerateLink;
  final VoidCallback? onOpenVendor;
  final GeneratedLinkModel? referralLink;
  final Future<void> Function(GeneratedLinkModel link)? onCopyReferralLink;
  final Future<void> Function(GeneratedLinkModel link)? onWhatsAppShare;

  const SubCategoryCard({
    super.key,
    required this.category,
    required this.onGenerateLink,
    this.onOpenVendor,
    this.referralLink,
    this.onCopyReferralLink,
    this.onWhatsAppShare,
  });

  static const Color navy = Color(0xFF101D45);
  static const Color royalBlue = Color(0xFF2449A5);
  static const Color successGreen = Color(0xFF218653);
  static const Color borderColor = Color(0xFFE5EAF2);
  static const Color imageBackground = Color(0xFFF0F7FF);

  @override
  Widget build(BuildContext context) {
    final canGenerateLink =
        category.activeStatus && category.referralEligibility;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onOpenVendor,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: navy.withValues(alpha: 0.035),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Tooltip(
                    message: onOpenVendor == null
                        ? category.name
                        : 'Open ${category.name} in the Vendor app',
                    child: Material(
                      color: imageBackground,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: onOpenVendor,
                        borderRadius: BorderRadius.circular(12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: RemoteServiceImage(
                            url: category.imageUrl,
                            label: category.name,
                            fit: BoxFit.contain,
                            backgroundColor: imageBackground,
                            foregroundColor: royalBlue,
                            indicatorSize: 25,
                            fallbackIconSize: 38,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 11),

                SizedBox(
                  height: 38,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: InkWell(
                      onTap: onOpenVendor,
                      borderRadius: BorderRadius.circular(4),
                      child: Text(
                        category.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: navy,
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 9),

                SizedBox(
                  height: 37,
                  child: ElevatedButton.icon(
                    onPressed: canGenerateLink ? onGenerateLink : null,
                    icon: const Icon(Icons.link_rounded, size: 16),
                    label: Text(
                      canGenerateLink ? 'Generate Link' : 'Unavailable',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: royalBlue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      disabledForegroundColor: Colors.grey.shade600,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (referralLink != null) ...[
                  const SizedBox(height: 9),
                  _buildReferralLinkDetails(referralLink!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReferralLinkDetails(GeneratedLinkModel link) {
    final expired = link.expiresAt != null &&
        !link.expiresAt!.toUtc().isAfter(DateTime.now().toUtc());
    final createdAt = link.createdAt?.toUtc().add(const Duration(hours: 5, minutes: 30));
    final expiresAt = link.expiresAt?.toUtc().add(const Duration(hours: 5, minutes: 30));
    String formatDate(DateTime? value) {
      if (value == null) return 'Unavailable';
      final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
      final minute = value.minute.toString().padLeft(2, '0');
      final day = value.day.toString().padLeft(2, '0');
      final month = value.month.toString().padLeft(2, '0');
      return '$day/$month/${value.year} $hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'} IST';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FC),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Referral Code: ${link.referralCode}', style: const TextStyle(color: navy, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Referral Tracking URL', style: TextStyle(color: navy, fontSize: 10, fontWeight: FontWeight.w700)),
          SelectableText(link.url, style: const TextStyle(color: royalBlue, fontSize: 10)),
          const SizedBox(height: 4),
          Text('Service: ${link.targetServiceName ?? category.name}', style: const TextStyle(color: navy, fontSize: 10)),
          Text('Validity: ${link.validityDays} days', style: const TextStyle(color: navy, fontSize: 10)),
          Text('Created: ${formatDate(createdAt)}', style: const TextStyle(color: navy, fontSize: 10)),
          Text('Expires: ${formatDate(expiresAt)}', style: const TextStyle(color: navy, fontSize: 10)),
          if (link.reusedExisting)
            const Text('Existing active link reused; original expiry retained.', style: TextStyle(color: navy, fontSize: 10)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: expired || onCopyReferralLink == null
                      ? null
                      : () => onCopyReferralLink!(link),
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: const Text('Copy Link', style: TextStyle(fontSize: 10)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: royalBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 34),
                    side: const BorderSide(color: royalBlue),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: expired || onWhatsAppShare == null
                      ? null
                      : () => onWhatsAppShare!(link),
                  icon: const Icon(Icons.chat_rounded, size: 14),
                  label: const Text('WhatsApp Share', style: TextStyle(fontSize: 10)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: successGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 34),
                    side: const BorderSide(color: successGreen),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
