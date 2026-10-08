import '../core/json.dart';
import 'entity.dart';

/// Модель автомобиля: «Granta» у марки Lada. Марка → модели — один ко
/// многим; модель → автомобили — тоже один ко многим.
class CarModel implements Entity {
  @override
  final String id;
  final String brandId;
  final String name;
  @override
  final DateTime? deletedAt;

  const CarModel({
    required this.id,
    required this.brandId,
    required this.name,
    this.deletedAt,
  });

  @override
  bool get isDeleted => deletedAt != null;

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'brand': brandId,
    'name': name,
    'deleted_at': deletedAt == null ? '' : dateTimeToJson(deletedAt!),
  };

  factory CarModel.fromJson(Map<String, dynamic> json) => CarModel(
    id: readId(json, 'id'),
    brandId: readId(json, 'brand'),
    name: readString(json, 'name'),
    deletedAt: readDateOrNull(json, 'deleted_at'),
  );
}
