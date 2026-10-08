import '../core/json.dart';
import 'entity.dart';

/// Уровень клубной карты и скидка по нему.
enum CardLevel {
  standard('standard', 'Стандарт', 0),
  silver('silver', 'Серебряная', 5),
  gold('gold', 'Золотая', 10);

  const CardLevel(this.code, this.title, this.discount);

  final String code;
  final String title;

  /// Скидка на работы по карте, %.
  final int discount;

  static CardLevel? fromCode(Object? code) {
    for (final level in values) {
      if (level.code == code) return level;
    }
    return null;
  }
}

/// Клубная карта — отдельная запись, связанная с клиентом «один к одному»:
/// у клиента не больше одной карты (уникальный индекс по client на сервере).
class ClubCard implements Entity {
  @override
  final String id;
  final String clientId;

  /// Номер вида «AS-000123».
  final String number;
  final CardLevel level;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final int bonusPoints;

  const ClubCard({
    required this.id,
    required this.clientId,
    required this.number,
    this.level = CardLevel.standard,
    required this.issuedAt,
    required this.expiresAt,
    this.bonusPoints = 0,
  });

  /// У карты нет логического удаления: она удаляется вместе с клиентом
  /// или снимается с клиента физически.
  @override
  DateTime? get deletedAt => null;

  @override
  bool get isDeleted => false;

  /// Действует ли карта в этот день.
  bool isValidAt(DateTime date) =>
      !date.isBefore(issuedAt) && !date.isAfter(expiresAt);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'client': clientId,
    'number': number,
    'level': level.code,
    'issued_at': dateToJson(issuedAt),
    'expires_at': dateToJson(expiresAt),
    'bonus_points': bonusPoints,
  };

  factory ClubCard.fromJson(Map<String, dynamic> json) {
    final issued = readDate(json, 'issued_at', DateTime(2000));
    return ClubCard(
      id: readId(json, 'id'),
      clientId: readId(json, 'client'),
      number: readString(json, 'number'),
      level: CardLevel.fromCode(json['level']) ?? CardLevel.standard,
      issuedAt: issued,
      // Без даты окончания карта считается действующей год с выдачи.
      expiresAt: readDate(
        json,
        'expires_at',
        DateTime(issued.year + 1, issued.month, issued.day),
      ),
      bonusPoints: readInt(json, 'bonus_points'),
    );
  }
}
