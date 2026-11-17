import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerAppCard extends StatelessWidget {
  const CustomerAppCard({super.key});

  static const Color navy = Color(0xFF101D45);
  static const Color royalBlue = Color(0xFF2449A5);
  static const Color textDark = Color(0xFF17233F);
  static const Color textGrey = Color(0xFF778198);

  Future<void> _openLink(BuildContext context, String url) async {
    final uri = Uri.parse(url);

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!opened && context.mounted) {
        _showMessage(context, 'Unable to open the link.');
      }
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, 'Unable to open the link.');
      }
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: navy,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 370),
            child: Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 82,
                    width: 82,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEAF0FF), Color(0xFFDCE7FF)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.shopping_bag_rounded,
                      color: royalBlue,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Customer App',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textDark,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Something exciting is on the way!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: royalBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'We are getting the AM5 ROYAL Customer App ready for you. Stay tuned!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textGrey,
                      fontSize: 13,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: royalBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: const Text(
                        'Got It!',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
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

  Widget _socialButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required String url,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () => _openLink(context, url),
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
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
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F7EE),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: Color(0xFF20845C),
                  size: 25,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _showComingSoon(context),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5DF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF0DFB9)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.share_rounded,
                        color: Color(0xFFAD791D),
                        size: 14,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Refer',
                        style: TextStyle(
                          color: Color(0xFF8E6419),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Customer App',
            style: TextStyle(
              color: textDark,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Bring more customer\nand earn rewards.',
            maxLines: 2,
            style: TextStyle(color: textGrey, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 7),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _showComingSoon(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: royalBlue,
                side: const BorderSide(color: Color(0xFFDCE4F5)),
                padding: const EdgeInsets.symmetric(vertical: 9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              child: const Text(
                'Open Customer App',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const Spacer(),
          const Center(
            child: Text(
              'Follow Us',
              style: TextStyle(
                color: textDark,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              _socialButton(
                context: context,
                icon: Icons.facebook_rounded,
                label: 'Facebook',
                color: const Color(0xFF1877F2),
                url: 'https://www.facebook.com/am5royalvendors/',
              ),
              const SizedBox(width: 8),
              _socialButton(
                context: context,
                icon: Icons.camera_alt_rounded,
                label: 'Instagram',
                color: const Color(0xFFC13584),
                url: 'https://www.instagram.com/am5royalvendors/',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
