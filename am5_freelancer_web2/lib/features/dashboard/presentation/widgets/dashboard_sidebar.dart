import 'package:flutter/material.dart';

import '../../models/dashboard_menu_item.dart';

class DashboardSidebar extends StatelessWidget {
  final String selectedMenu;
  final ValueChanged<String> onMenuSelected;

  const DashboardSidebar({
    super.key,
    required this.selectedMenu,
    required this.onMenuSelected,
  });

  static const Color navy = Color(0xFF10265D);
  static const Color royalBlue = Color(0xFF2449A5);
  static const Color gold = Color(0xFFD8AD57);

  @override
  Widget build(BuildContext context) {
    // Hide the old Demo menu option.
    final menuItems = DashboardMenuItem.items
        .where((item) => item.title.toLowerCase() != 'demo')
        .toList();

    return Container(
      width: 265,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF10265D), Color(0xFF193779), Color(0xFF2449A5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBrand(),

            const Padding(
              padding: EdgeInsets.fromLTRB(20, 5, 16, 15),
              child: Divider(color: Color(0x35FFFFFF), height: 1),
            ),

            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                itemCount: menuItems.length,
                separatorBuilder: (_, _) => const SizedBox(height: 5),
                itemBuilder: (context, index) {
                  final item = menuItems[index];
                  final bool isSelected = selectedMenu == item.title;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: isSelected ? gold : Colors.transparent,
                        width: 1.2,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(13),
                        onTap: () => onMenuSelected(item.title),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.icon,
                                size: 21,
                                color: isSelected
                                    ? royalBlue
                                    : Colors.white.withValues(alpha: 0.92),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isSelected ? navy : Colors.white,
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 21,
                                  color: gold,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0x30FFFFFF))),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_rounded, color: gold, size: 19),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'AM5 ROYAL',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrand() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 16, 23),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: gold,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: navy,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'AM5 ROYAL',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
