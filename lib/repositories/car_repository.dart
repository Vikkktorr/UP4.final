import '../models/car.dart';
import '../models/car_query.dart';
import 'entity_repository.dart';

abstract interface class CarRepository
    implements EntityRepository<Car, CarQuery> {}
