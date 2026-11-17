import 'package:flutter/material.dart';

class ReferVendorCard extends StatelessWidget {
  const ReferVendorCard({
    super.key,
    required this.onRefer,
    this.isLoading = false,
  });

  final VoidCallback onRefer;
  final bool isLoading;

  static const Color pink = Color(0xFFD63372);
  static const Color navy = Color(0xFF101D45);
  static const Color textDark = Color(0xFF17233F);
  static const Color textGrey = Color(0xFF778198);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0C7D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: pink,
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Invite Vendors. Grow Together.',
            style: TextStyle(
              color: textDark,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          const Text(
            'Share your personal invitation and welcome new Vendors to AM5 ROYAL.',
            style: TextStyle(color: textGrey, fontSize: 13, height: 1.7),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : onRefer,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.link_rounded, size: 18),
              label: Text(isLoading ? 'Getting link…' : 'Refer Vendor'),
              style: ElevatedButton.styleFrom(
                backgroundColor: pink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Valid for 15 days',
              style: TextStyle(color: navy, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
