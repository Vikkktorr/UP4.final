import '../core/pocketbase.dart';
import '../models/car_model.dart';
import '../models/entity_query.dart';
import 'api_repository.dart';
import 'car_model_repository.dart';

/// Модели марок. Отдельного списка у них нет — они показываются и
/// редактируются на карточке марки, а в форме автомобиля сужают выбор.
class ApiCarModelRepository extends ApiRepository<CarModel, EntityQuery>
    implements CarModelRepository {
  ApiCarModelRepository(super.dio, {required super.changes})
    : super(collection: 'car_models', cacheAll: true);

  @override
  CarModel fromJson(Map<String, dynamic> json) => CarModel.fromJson(json);

  @override
  String filterOf(EntityQuery q) => pbAnd([
    pbSearch(['name'], q.search),
    if (q.filter('brand') case final brand?) 'brand = ${pbString(brand)}',
  ]);
}
