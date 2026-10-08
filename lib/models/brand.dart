import '../core/json.dart';
import 'entity.dart';

/// Марка автомобиля. Связь с моделями — один ко многим ([CarModel.brandId]).
class Brand implements Entity {
  @override
  final String id;
  final String name;
  final String country;
  @override
  final DateTime? deletedAt;

  const Brand({
    required this.id,
    required this.name,
    required this.country,
    this.deletedAt,
  });

  @override
  bool get isDeleted => deletedAt != null;

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'country': country,
    'deleted_at': deletedAt == null ? '' : dateTimeToJson(deletedAt!),
  };

  factory Brand.fromJson(Map<String, dynamic> json) => Brand(
    id: readId(json, 'id'),
    name: readString(json, 'name'),
    country: readString(json, 'country'),
    deletedAt: readDateOrNull(json, 'deleted_at'),
  );
}
