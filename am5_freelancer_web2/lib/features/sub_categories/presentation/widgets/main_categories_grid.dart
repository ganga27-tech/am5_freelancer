import 'package:flutter/material.dart';

/// Displays main service categories in a responsive grid.
class MainCategoriesGrid extends StatelessWidget {
  final List<MainCategoryItem> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final double availableWidth;

  const MainCategoriesGrid({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.availableWidth,
  });

  int _getColumnCount() {
    if (availableWidth >= 1200) return 6;
    if (availableWidth >= 950) return 5;
    if (availableWidth >= 700) return 4;
    if (availableWidth >= 480) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _getColumnCount(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 112,
      ),
      itemBuilder: (context, index) {
        final category = categories[index];
        final isSelected = selectedCategory == category.name;

        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onCategorySelected(category.name),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? category.color : const Color(0xFFE0E6EF),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: category.color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(category.icon, size: 23, color: category.color),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected
                          ? category.color
                          : const Color(0xFF243451),
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
}

/// Data required to display a main category.
class MainCategoryItem {
  final String name;
  final IconData icon;
  final Color color;

  const MainCategoryItem(this.name, this.icon, this.color);
}
