import 'package:autoservice_web/core/pricing.dart';
import 'package:autoservice_web/core/schedule.dart';
import 'package:autoservice_web/models/appointment.dart';
import 'package:autoservice_web/models/club_card.dart';
import 'package:flutter_test/flutter_test.dart';

/// Правила записи к мастеру: скидка, стоимость, пересечение интервалов,
/// рабочие часы. Те же правила проверяет серверный хук.
void main() {
  final day = DateTime(2026, 10, 9);
  ClubCard card(CardLevel level, {DateTime? expires}) => ClubCard(
    id: 'card',
    clientId: 'cl',
    number: 'AS-000001',
    level: level,
    issuedAt: DateTime(2025, 1, 1),
    expiresAt: expires ?? DateTime(2027, 1, 1),
  );

  group('Скидка', () {
    test('без карты и персональной скидки — 0 %', () {
      final d = Pricing.discount(personal: 0, date: day);
      expect(d.percent, 0);
      expect(d.source, DiscountSource.none);
    });

    test('действует большая: карта 10 % против персональной 5 %', () {
      final d = Pricing.discount(
        personal: 5,
        card: card(CardLevel.gold),
        date: day,
      );
      expect(d.percent, 10);
      expect(d.source, DiscountSource.card);
    });

    test('персональная 7 % больше серебряной карты 5 %', () {
      final d = Pricing.discount(
        personal: 7,
        card: card(CardLevel.silver),
        date: day,
      );
      expect(d.percent, 7);
      expect(d.source, DiscountSource.personal);
    });

    test('скидка не больше 15 %', () {
      final d = Pricing.discount(
        personal: 30,
        card: card(CardLevel.gold),
        date: day,
      );
      expect(d.percent, Pricing.maxDiscount);
    });

    test('просроченная карта скидки не даёт', () {
      final d = Pricing.discount(
        personal: 0,
        card: card(CardLevel.gold, expires: DateTime(2026, 1, 1)),
        date: day,
      );
      expect(d.percent, 0);
    });

    test('к оплате — сумма минус скидка с округлением до рубля', () {
      expect(Pricing.total(5600, 5), 5320);
      expect(Pricing.total(1999, 7), 1859);
      expect(Pricing.total(1000, 0), 1000);
    });
  });

  group('Занятость мастера', () {
    DateTime at(int h, [int m = 0]) => DateTime(2026, 10, 9, h, m);

    test('промежутки пересекаются', () {
      expect(Schedule.overlaps(at(10), at(12), at(11), at(13)), isTrue);
      expect(Schedule.overlaps(at(10), at(12), at(9), at(10, 30)), isTrue);
      // Один внутри другого
      expect(Schedule.overlaps(at(10), at(12), at(10, 30), at(11)), isTrue);
    });

    test('касание и непересекающиеся промежутки — не пересечение', () {
      expect(Schedule.overlaps(at(10), at(11), at(11), at(12)), isFalse);
      expect(Schedule.overlaps(at(14), at(15), at(10), at(11)), isFalse);
    });

    test('рабочие часы: с 9:00 до 20:00', () {
      expect(Schedule.withinHours(at(9), const Duration(hours: 2)), isTrue);
      expect(Schedule.withinHours(at(18), const Duration(hours: 2)), isTrue);
      expect(
        Schedule.withinHours(at(8, 30), const Duration(hours: 1)),
        isFalse,
      );
      expect(Schedule.withinHours(at(19), const Duration(hours: 2)), isFalse);
    });

    test('неделя начинается с понедельника', () {
      // 9 октября 2026 — пятница
      expect(
        Schedule.weekStart(DateTime(2026, 10, 9, 15)),
        DateTime(2026, 10, 5),
      );
      expect(Schedule.weekStart(DateTime(2026, 10, 5)), DateTime(2026, 10, 5));
      expect(Schedule.weekStart(DateTime(2026, 10, 11)), DateTime(2026, 10, 5));
    });
  });
}
