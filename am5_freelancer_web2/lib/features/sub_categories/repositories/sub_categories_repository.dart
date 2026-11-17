import '../models/main_category_model.dart';
import '../models/sub_category_model.dart';
import '../services/category_service.dart';

class SubCategoriesRepository {
  final CategoryService _categoryService;

  SubCategoriesRepository({required this._categoryService});

  Future<List<MainCategoryModel>> getMainCategories() async {
    try {
      return await _categoryService.fetchMainCategories();
    } on CategoryServiceException {
      rethrow;
    } catch (_) {
      throw const CategoryServiceException(
        'Unable to load service categories. Please try again.',
      );
    }
  }

  Future<List<SubCategoryModel>> getSubCategories(int categoryId) async {
    if (categoryId <= 0) {
      throw const CategoryServiceException('Invalid category selected.');
    }

    try {
      return await _categoryService.fetchSubCategories(categoryId);
    } on CategoryServiceException {
      rethrow;
    } catch (_) {
      throw const CategoryServiceException(
        'Unable to load subcategories. Please try again.',
      );
    }
  }

  void dispose() {
    _categoryService.dispose();
  }
}
