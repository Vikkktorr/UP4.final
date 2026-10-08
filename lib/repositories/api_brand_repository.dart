import '../core/pocketbase.dart';
import '../models/brand.dart';
import '../models/entity_query.dart';
import 'api_repository.dart';
import 'brand_repository.dart';

/// Справочник: полный список кэшируется и не перезапрашивается
/// при каждом открытии формы автомобиля.
class ApiBrandRepository extends ApiRepository<Brand, EntityQuery>
    implements BrandRepository {
  ApiBrandRepository(super.dio, {required super.changes})
    : super(collection: 'brands', cacheAll: true);

  @override
  Brand fromJson(Map<String, dynamic> json) => Brand.fromJson(json);

  @override
  String filterOf(EntityQuery q) => pbAnd([
    pbSearch(['name', 'country'], q.search),
    if (q.filter('country') case final country?)
      'country = ${pbString(country)}',
  ]);
}
