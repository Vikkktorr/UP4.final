import '../core/pocketbase.dart';
import '../models/car.dart';
import '../models/car_query.dart';
import 'api_repository.dart';
import 'car_repository.dart';

class ApiCarRepository extends ApiRepository<Car, CarQuery>
    implements CarRepository {
  ApiCarRepository(super.dio, {required super.changes})
    : super(collection: 'cars');

  @override
  Car fromJson(Map<String, dynamic> json) => Car.fromJson(json);

  /// Поиск, фильтры, сортировка и страницы выполняются на сервере:
  /// клиент хранит только текущую страницу. Фильтр по марке идёт через
  /// связь: у автомобиля модель, у модели марка.
  @override
  String filterOf(CarQuery q) => pbAnd([
    pbSearch(['plate', 'vin'], q.search),
    if (q.brandId != null) 'model.brand = ${pbString(q.brandId!)}',
    if (q.fuel != null) 'fuel = ${pbString(q.fuel!.code)}',
    if (q.yearFrom != null) 'year >= ${q.yearFrom}',
    if (q.yearTo != null) 'year <= ${q.yearTo}',
    if (q.clientId != null) 'client = ${pbString(q.clientId!)}',
    if (q.mechanicId != null) 'mechanics ~ ${pbString(q.mechanicId!)}',
  ]);

  @override
  String sortFieldOf(String field) => switch (field) {
    'brand' => 'model.brand.name',
    _ => field,
  };
}
