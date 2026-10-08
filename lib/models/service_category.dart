import '../core/json.dart';
import 'entity.dart';

/// Категория услуг: «Техобслуживание», «Ходовая часть»… Категория → услуги —
/// один ко многим.
class ServiceCategory implements Entity {
  @override
  final String id;
  final String name;
  @override
  final DateTime? deletedAt;

  const ServiceCategory({required this.id, required this.name, this.deletedAt});

  @override
  bool get isDeleted => deletedAt != null;

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'deleted_at': deletedAt == null ? '' : dateTimeToJson(deletedAt!),
  };

  factory ServiceCategory.fromJson(Map<String, dynamic> json) =>
      ServiceCategory(
        id: readId(json, 'id'),
        name: readString(json, 'name'),
        deletedAt: readDateOrNull(json, 'deleted_at'),
      );
}
