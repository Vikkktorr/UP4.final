import '../core/json.dart';
import 'club_card.dart';
import 'entity.dart';
import 'mechanic.dart';

/// Клиент автосервиса. Клиент → автомобили — один ко многим,
/// клиент — клубная карта — один к одному.
class Client implements Entity {
  @override
  final String id;
  final String lastName;
  final String firstName;
  final String middleName;

  /// Телефон в виде «+7 (916) 123-45-67».
  final String phone;
  final String email;

  /// Персональная скидка на работы, %.
  final int discount;
  final DateTime registeredAt;

  /// Клубная карта, если выдана. Приходит из PocketBase развёрнутой связью
  /// (expand=club_cards_via_client) — отдельным запросом её не ищем.
  final ClubCard? card;
  @override
  final DateTime? deletedAt;

  const Client({
    required this.id,
    required this.lastName,
    required this.firstName,
    this.middleName = '',
    required this.phone,
    required this.email,
    this.discount = 0,
    required this.registeredAt,
    this.card,
    this.deletedAt,
  });

  @override
  bool get isDeleted => deletedAt != null;

  String get fullName =>
      [lastName, firstName, middleName].where((s) => s.isNotEmpty).join(' ');

  String get shortName => shortPersonName(lastName, firstName, middleName);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'last_name': lastName,
    'first_name': firstName,
    'middle_name': middleName,
    'phone': phone,
    'email': email,
    'discount': discount,
    'registered_at': dateToJson(registeredAt),
    'deleted_at': deletedAt == null ? '' : dateTimeToJson(deletedAt!),
  };

  factory Client.fromJson(Map<String, dynamic> json) {
    final cards = readMap(json, 'expand')['club_cards_via_client'];
    final card = switch (cards) {
      [Map first, ...] => ClubCard.fromJson(first.cast<String, dynamic>()),
      Map one => ClubCard.fromJson(one.cast<String, dynamic>()),
      _ => null,
    };
    return Client(
      id: readId(json, 'id'),
      lastName: readString(json, 'last_name'),
      firstName: readString(json, 'first_name'),
      middleName: readString(json, 'middle_name'),
      phone: readString(json, 'phone'),
      email: readString(json, 'email'),
      discount: readInt(json, 'discount'),
      registeredAt: readDate(json, 'registered_at', DateTime(2000)),
      card: card,
      deletedAt: readDateOrNull(json, 'deleted_at'),
    );
  }
}
