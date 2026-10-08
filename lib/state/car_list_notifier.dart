import 'package:flutter/foundation.dart';

import '../models/car.dart';
import '../models/car_query.dart';
import '../repositories/car_repository.dart';
import 'entity_list_notifier.dart';

class CarListNotifier extends EntityListNotifier<Car, CarQuery> {
  CarListNotifier(CarRepository repository, {Listenable? changes})
    : super(repository, (car) => car.id, const CarQuery(), changes: changes);
}
