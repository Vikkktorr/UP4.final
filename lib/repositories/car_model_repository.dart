import '../models/car_model.dart';
import '../models/entity_query.dart';
import 'entity_repository.dart';

abstract interface class CarModelRepository
    implements EntityRepository<CarModel, EntityQuery> {}
