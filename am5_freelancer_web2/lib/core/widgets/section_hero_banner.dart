import 'package:flutter/material.dart';

/// Responsive AM5 ROYAL section artwork with a safe local-image fallback.
class SectionHeroBanner extends StatelessWidget {
  const SectionHeroBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.imageAsset,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? imageAsset;
  final Widget? trailing;

  static const Color _navy = Color(0xFF101D45);
  static const Color _blue = Color(0xFF2449A5);
  static const Color _gold = Color(0xFFFFC857);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final imageSize = compact ? 62.0 : 82.0;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 16 : 22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_navy, _blue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'AM5 ROYAL',
                      style: TextStyle(
                        color: _gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 19 : 23,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: compact ? 11 : 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              const SizedBox(width: 10),
              _Artwork(imageAsset: imageAsset, icon: icon, size: imageSize),
            ],
          ),
        );
      },
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({
    required this.imageAsset,
    required this.icon,
    required this.size,
  });

  final String? imageAsset;
  final IconData icon;
  final double size;

  static const Color _gold = Color(0xFFFFC857);

  @override
  Widget build(BuildContext context) {
    final asset = imageAsset;
    final fallback = Icon(icon, color: _gold, size: size * 0.58);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: asset == null
          ? fallback
          : ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                asset,
                width: size,
                height: size,
                fit: BoxFit.contain,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) return child;
                  return SizedBox(
                    width: size,
                    height: size,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
            ),
    );
  }
}
