import '../core/pocketbase.dart';
import '../models/entity_query.dart';
import '../models/service_item.dart';
import 'api_repository.dart';
import 'service_repository.dart';

class ApiServiceRepository extends ApiRepository<ServiceItem, EntityQuery>
    implements ServiceRepository {
  ApiServiceRepository(super.dio, {required super.changes})
    : super(collection: 'services', cacheAll: true);

  @override
  ServiceItem fromJson(Map<String, dynamic> json) => ServiceItem.fromJson(json);

  @override
  String filterOf(EntityQuery q) => pbAnd([
    pbSearch(['name'], q.search),
    if (q.filter('category') case final category?)
      'category = ${pbString(category)}',
  ]);
}
