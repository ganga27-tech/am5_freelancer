import 'package:flutter/material.dart';

class ReferCustomerCard extends StatelessWidget {
  const ReferCustomerCard({super.key});

  static const blue = Color(0xFF2449A5);
  static const textDark = Color(0xFF17233F);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD7E5FC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _icon(),
          const SizedBox(height: 18),
          const Text(
            'Refer Customer',
            style: TextStyle(
              color: textDark,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          const Text(
            'Customer App is coming soon. Customer referrals will be available after launch.',
            style: TextStyle(
              color: Color(0xFF778198),
              fontSize: 13,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.schedule_rounded, size: 18),
              label: const Text('Coming Soon'),
              style: ElevatedButton.styleFrom(
                backgroundColor: blue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFD9E2F3),
                disabledForegroundColor: const Color(0xFF44516A),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _icon() {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: blue,
        borderRadius: BorderRadius.circular(17),
      ),
      child: const Icon(
        Icons.people_alt_rounded,
        color: Colors.white,
        size: 30,
      ),
    );
  }
}
