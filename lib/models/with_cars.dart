import 'car.dart';

/// Запись вместе с автомобилями, которые на неё ссылаются, — для карточек
/// клиента, марки, мастера и услуги.
class WithCars<T> {
  final T item;
  final List<Car> cars;

  /// Всего связанных автомобилей; в [cars] может быть только первая часть.
  final int total;

  const WithCars({required this.item, required this.cars, required this.total});
}
