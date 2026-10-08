import '../core/pocketbase.dart';
import '../models/entity_query.dart';
import '../models/service_category.dart';
import 'api_repository.dart';
import 'category_repository.dart';

class ApiCategoryRepository extends ApiRepository<ServiceCategory, EntityQuery>
    implements CategoryRepository {
  ApiCategoryRepository(super.dio, {required super.changes})
    : super(collection: 'service_categories', cacheAll: true);

  @override
  ServiceCategory fromJson(Map<String, dynamic> json) =>
      ServiceCategory.fromJson(json);

  @override
  String filterOf(EntityQuery q) => pbSearch(['name'], q.search);
}
