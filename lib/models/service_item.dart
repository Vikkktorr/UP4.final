import '../core/json.dart';
import 'entity.dart';

/// Услуга из прайс-листа. Категория → услуги — один ко многим;
/// записи на обслуживание ↔ услуги — многие ко многим.
class ServiceItem implements Entity {
  @override
  final String id;
  final String name;
  final String categoryId;

  /// Цена в рублях.
  final int price;

  /// Норма времени в минутах.
  final int duration;
  @override
  final DateTime? deletedAt;

  const ServiceItem({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.price,
    required this.duration,
    this.deletedAt,
  });

  @override
  bool get isDeleted => deletedAt != null;

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': categoryId,
    'price': price,
    'duration': duration,
    'deleted_at': deletedAt == null ? '' : dateTimeToJson(deletedAt!),
  };

  factory ServiceItem.fromJson(Map<String, dynamic> json) => ServiceItem(
    id: readId(json, 'id'),
    name: readString(json, 'name'),
    categoryId: readId(json, 'category'),
    price: readInt(json, 'price'),
    duration: readInt(json, 'duration'),
    deletedAt: readDateOrNull(json, 'deleted_at'),
  );
}
