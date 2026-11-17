import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class VendorAppCard extends StatefulWidget {
  const VendorAppCard({super.key});

  @override
  State<VendorAppCard> createState() => _VendorAppCardState();
}

class _VendorAppCardState extends State<VendorAppCard> {
  static const Color navy = Color(0xFF101D45);
  static const Color royalBlue = Color(0xFF2449A5);
  static const Color textDark = Color(0xFF17233F);
  static const Color textGrey = Color(0xFF778198);

  static const String vendorAppLink =
      'https://play.google.com/store/apps/details?id=com.am5royal.am5royal';

  static const String facebookLink =
      'https://www.facebook.com/am5royalvendors/';

  static const String instagramLink =
      'https://www.instagram.com/am5royalvendors/';

  static const String shareMessage =
      'Join AM5 ROYAL Vendor App! Invite vendors, explore opportunities, '
      'and grow with us.\n\nDownload the app:\n'
      'https://play.google.com/store/apps/details?id=com.am5royal.am5royal';

  final LayerLink _referLink = LayerLink();

  OverlayEntry? _shareOverlay;
  bool _isCopied = false;

  @override
  void dispose() {
    _removeSharePopup();
    super.dispose();
  }

  // ---------------- COPY LINK ----------------

  Future<void> _copyLink() async {
    try {
      await Clipboard.setData(const ClipboardData(text: vendorAppLink));

      if (!mounted) return;

      setState(() {
        _isCopied = true;
      });

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isCopied = false;
          });
        }
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to copy link. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ---------------- OPEN LINKS ----------------

  Future<void> _openLink(String url) async {
    try {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        _showMessage('Unable to open this link.');
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Unable to open this link.');
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ---------------- SHARE ACTIONS ----------------

  Future<void> _shareMore() async {
    try {
      await SharePlus.instance.share(
        ShareParams(text: shareMessage, subject: 'AM5 ROYAL Vendor App'),
      );
    } catch (_) {
      if (mounted) {
        _showMessage('Unable to open sharing options.');
      }
    }
  }

  Future<void> _shareWhatsApp() async {
    final url = 'https://wa.me/?text=${Uri.encodeComponent(shareMessage)}';

    await _openLink(url);
  }

  Future<void> _shareOutlook() async {
    final uri = Uri(
      scheme: 'mailto',
      queryParameters: {
        'subject': 'AM5 ROYAL Vendor App',
        'body': shareMessage,
      },
    );

    await _openLink(uri.toString());
  }

  Future<void> _shareTeams() async {
    final url =
        'https://teams.microsoft.com/share'
        '?href=${Uri.encodeComponent(vendorAppLink)}'
        '&msgText=${Uri.encodeComponent('Join AM5 ROYAL Vendor App!')}';

    await _openLink(url);
  }

  Future<void> _shareFacebook() async {
    final url =
        'https://www.facebook.com/sharer/sharer.php'
        '?u=${Uri.encodeComponent(vendorAppLink)}';

    await _openLink(url);
  }

  Future<void> _shareTelegram() async {
    final url =
        'https://t.me/share/url'
        '?url=${Uri.encodeComponent(vendorAppLink)}'
        '&text=${Uri.encodeComponent('Join AM5 ROYAL Vendor App!')}';

    await _openLink(url);
  }

  // ---------------- SHARE POPUP ----------------

  void _toggleSharePopup() {
    if (_shareOverlay != null) {
      _removeSharePopup();
      return;
    }

    final overlay = Overlay.of(context);

    _shareOverlay = OverlayEntry(
      builder: (overlayContext) {
        return Positioned.fill(
          child: Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _removeSharePopup,
                child: const SizedBox.expand(),
              ),
              CompositedTransformFollower(
                link: _referLink,
                showWhenUnlinked: false,
                targetAnchor: Alignment.bottomRight,
                followerAnchor: Alignment.topRight,
                offset: const Offset(0, 8),
                child: Material(
                  color: Colors.transparent,
                  child: SizedBox(width: 280, child: _buildSharePopup()),
                ),
              ),
            ],
          ),
        );
      },
    );

    overlay.insert(_shareOverlay!);
  }

  void _removeSharePopup() {
    _shareOverlay?.remove();
    _shareOverlay = null;
  }

  Widget _buildSharePopup() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E7F2)),
        boxShadow: [
          BoxShadow(
            color: navy.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Share Vendor App',
                  style: TextStyle(
                    color: textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              InkWell(
                onTap: _removeSharePopup,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(Icons.close_rounded, size: 18, color: textGrey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _shareOption(
                  icon: Icons.chat_rounded,
                  label: 'WhatsApp',
                  color: const Color(0xFF25A65A),
                  onTap: _shareWhatsApp,
                ),
              ),
              Expanded(
                child: _shareOption(
                  icon: Icons.email_outlined,
                  label: 'Outlook',
                  color: const Color(0xFF0078D4),
                  onTap: _shareOutlook,
                ),
              ),
              Expanded(
                child: _shareOption(
                  icon: Icons.groups_rounded,
                  label: 'Teams',
                  color: const Color(0xFF6264A7),
                  onTap: _shareTeams,
                ),
              ),
              Expanded(
                child: _shareOption(
                  icon: Icons.facebook_rounded,
                  label: 'Facebook',
                  color: const Color(0xFF1877F2),
                  onTap: _shareFacebook,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: _shareOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Instagram',
                  color: const Color(0xFFC13584),
                  onTap: _shareMore,
                ),
              ),
              Expanded(
                child: _shareOption(
                  icon: Icons.send_rounded,
                  label: 'Telegram',
                  color: const Color(0xFF229ED9),
                  onTap: _shareTelegram,
                ),
              ),
              Expanded(
                child: _shareOption(
                  icon: Icons.more_horiz_rounded,
                  label: 'More',
                  color: royalBlue,
                  onTap: _shareMore,
                ),
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shareOption({
    required IconData icon,
    required String label,
    required Color color,
    required Future<void> Function() onTap,
  }) {
    return InkWell(
      onTap: () async {
        _removeSharePopup();
        await onTap();
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: textDark,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- FOLLOW US BUTTONS ----------------

  Widget _socialButton({
    required IconData icon,
    required String label,
    required Color color,
    required String url,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () => _openLink(url),
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
                  maxLines: 1,
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

  // ---------------- VENDOR CARD ----------------

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
          // Vendor icon and Refer button
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0FF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  color: royalBlue,
                  size: 25,
                ),
              ),
              const Spacer(),
              CompositedTransformTarget(
                link: _referLink,
                child: InkWell(
                  onTap: _toggleSharePopup,
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
              ),
            ],
          ),

          const SizedBox(height: 8),

          const Text(
            'Vendor App',
            style: TextStyle(
              color: textDark,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            'Invite vendors and earn more rewards.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: textGrey, fontSize: 12, height: 1.35),
          ),

          const SizedBox(height: 7),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _openLink(vendorAppLink),
              style: OutlinedButton.styleFrom(
                foregroundColor: royalBlue,
                side: const BorderSide(color: Color(0xFFDCE4F5)),
                padding: const EdgeInsets.symmetric(vertical: 9),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              child: const Text(
                'Open Vendor App',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ),

          const SizedBox(height: 3),

          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: _copyLink,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isCopied
                          ? Icons.check_circle_rounded
                          : Icons.copy_rounded,
                      size: 14,
                      color: _isCopied ? const Color(0xFF20845C) : royalBlue,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _isCopied ? 'Copied!' : 'Copy link',
                      style: TextStyle(
                        color: _isCopied ? const Color(0xFF20845C) : royalBlue,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
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
                icon: Icons.facebook_rounded,
                label: 'Facebook',
                color: const Color(0xFF1877F2),
                url: facebookLink,
              ),
              const SizedBox(width: 8),
              _socialButton(
                icon: Icons.camera_alt_rounded,
                label: 'Instagram',
                color: const Color(0xFFC13584),
                url: instagramLink,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
