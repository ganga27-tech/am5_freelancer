import 'package:flutter/material.dart';

class CustomerHowItWorks extends StatelessWidget {
  const CustomerHowItWorks({super.key});

  static const Color navy = Color(0xFF10265A);
  static const Color blue = Color(0xFF2457CC);
  static const Color muted = Color(0xFF65779B);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD7E6FF)),
        boxShadow: [
          BoxShadow(
            color: blue.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_buildHero(), _buildSteps()],
      ),
    );
  }

  // Attractive customer banner
  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF163B91), Color(0xFF3479F6), Color(0xFF7DB7FF)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                ),
                child: const Icon(
                  Icons.home_repair_service_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  'AM5 ROYAL  •  CUSTOMER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFFFFD46F),
                size: 23,
              ),
            ],
          ),

          const SizedBox(height: 22),

          const Text(
            'Home Services,\nMade Easy!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 27,
              height: 1.12,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 9),

          const Text(
            'Share convenience with friends and family '
            'through AM5 ROYAL.',
            style: TextStyle(
              color: Color(0xFFEAF3FF),
              fontSize: 12,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 20),

          // Human-style illustration without external assets
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(19),
              boxShadow: [
                BoxShadow(
                  color: navy.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 88,
                  height: 96,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 82,
                        height: 82,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFFDCEAFF), Color(0xFFF2F7FF)],
                          ),
                        ),
                      ),

                      const Positioned(
                        top: 0,
                        right: 2,
                        child: Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFB83D),
                          size: 23,
                        ),
                      ),

                      const Positioned(
                        bottom: 0,
                        child: Icon(
                          Icons.person_rounded,
                          size: 82,
                          color: Color(0xFF2457CC),
                        ),
                      ),

                      Positioned(
                        right: 0,
                        bottom: 2,
                        child: Container(
                          width: 31,
                          height: 31,
                          decoration: BoxDecoration(
                            color: const Color(0xFF13A66B),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 13),

                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share the convenience',
                        style: TextStyle(
                          color: navy,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 7),
                      Text(
                        'Help people you know discover '
                        'available home services.',
                        style: TextStyle(
                          color: muted,
                          fontSize: 11,
                          height: 1.6,
                        ),
                      ),
                      SizedBox(height: 9),
                      Row(
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            color: Color(0xFF13A66B),
                            size: 15,
                          ),
                          SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'Simple • Convenient • Trusted',
                              style: TextStyle(
                                color: Color(0xFF36705C),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Three clear steps
  Widget _buildSteps() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'HOW IT WORKS',
            style: TextStyle(
              color: navy,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),

          const SizedBox(height: 5),

          const Text(
            'Getting started is simple',
            style: TextStyle(color: muted, fontSize: 11, height: 1.5),
          ),

          const SizedBox(height: 20),

          _step(
            number: '01',
            icon: Icons.share_rounded,
            color: const Color(0xFF2457CC),
            background: const Color(0xFFEAF1FF),
            title: 'Introduce AM5 ROYAL',
            description: 'Share the platform with friends and family.',
          ),

          _connector(),

          _step(
            number: '02',
            icon: Icons.search_rounded,
            color: const Color(0xFF8750D8),
            background: const Color(0xFFF1E9FF),
            title: 'Explore services',
            description: 'They can discover services and booking options.',
          ),

          _connector(),

          _step(
            number: '03',
            icon: Icons.card_giftcard_rounded,
            color: const Color(0xFF15966B),
            background: const Color(0xFFE1F8ED),
            title: 'Referral rewards',
            description: 'Eligible rewards follow the programme rules.',
          ),

          const SizedBox(height: 22),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2457CC), Color(0xFF397CF4)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: blue.withValues(alpha: 0.20),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_alt_rounded, color: Colors.white, size: 19),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'REFER A CUSTOMER',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 17,
                ),
              ],
            ),
          ),

          const SizedBox(height: 13),

          const Center(
            child: Text(
              'Share good service with people you know.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: muted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _connector() {
    return Padding(
      padding: const EdgeInsets.only(left: 18),
      child: Container(
        width: 2,
        height: 16,
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: const Color(0xFFD9E5FB),
      ),
    );
  }

  Widget _step({
    required String number,
    required IconData icon,
    required Color color,
    required Color background,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color, size: 20),
        ),

        const SizedBox(width: 11),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 11,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 5),

        Text(
          number,
          style: TextStyle(
            color: color.withValues(alpha: 0.75),
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
