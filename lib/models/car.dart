import '../core/json.dart';
import 'entity.dart';
import 'fuel_type.dart';

/// Автомобиль клиента. Основная сущность приложения.
///
/// Связи: модель и владелец — многие к одному ([modelId], [clientId]),
/// закреплённые мастера — многие ко многим ([mechanicIds]). Марка
/// определяется через модель. Связи хранятся идентификаторами — так же,
/// как в PocketBase.
class Car implements Entity {
  @override
  final String id;

  /// Госномер в виде «А123ВС777», без пробелов.
  final String plate;
  final String vin;
  final String modelId;
  final int year;

  /// Пробег в километрах.
  final int mileage;
  final FuelType fuel;
  final String clientId;

  /// Мастера, закреплённые за автомобилем (от одного до трёх).
  final List<String> mechanicIds;
  @override
  final DateTime? deletedAt;

  const Car({
    required this.id,
    required this.plate,
    required this.vin,
    required this.modelId,
    required this.year,
    required this.mileage,
    required this.fuel,
    required this.clientId,
    this.mechanicIds = const [],
    this.deletedAt,
  });

  @override
  bool get isDeleted => deletedAt != null;

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'plate': plate,
    'vin': vin,
    'model': modelId,
    'year': year,
    'mileage': mileage,
    'fuel': fuel.code,
    'client': clientId,
    'mechanics': mechanicIds,
    'deleted_at': deletedAt == null ? '' : dateTimeToJson(deletedAt!),
  };

  factory Car.fromJson(Map<String, dynamic> json) => Car(
    id: readId(json, 'id'),
    plate: readString(json, 'plate'),
    vin: readString(json, 'vin'),
    modelId: readId(json, 'model'),
    year: readInt(json, 'year'),
    mileage: readInt(json, 'mileage'),
    // Неизвестный код двигателя не должен ронять разбор всего списка.
    fuel: FuelType.fromCode(json['fuel'] as Object?) ?? FuelType.petrol,
    clientId: readId(json, 'client'),
    mechanicIds: readIds(json, 'mechanics'),
    deletedAt: readDateOrNull(json, 'deleted_at'),
  );
}
