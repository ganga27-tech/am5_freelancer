import 'package:flutter/material.dart';

class ReferEarnHeader extends StatelessWidget {
  const ReferEarnHeader({super.key});

  static const navy = Color(0xFF101D45);
  static const blue = Color(0xFF2449A5);
  static const gold = Color(0xFFFFD778);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [navy, blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              color: gold,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Refer & Earn',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Invite. Refer. Earn Rewards.',
                  style: TextStyle(color: Color(0xFFE1E9FF), fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  'Help customers and vendors discover AM5 ROYAL.',
                  style: TextStyle(
                    color: Color(0xFFE1E9FF),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.redeem_rounded, color: gold, size: 48),
        ],
      ),
    );
  }
}
