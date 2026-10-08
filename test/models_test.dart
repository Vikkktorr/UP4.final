import 'package:autoservice_web/models/app_user.dart';
import 'package:autoservice_web/models/appointment.dart';
import 'package:autoservice_web/models/car.dart';
import 'package:autoservice_web/models/client.dart';
import 'package:autoservice_web/models/club_card.dart';
import 'package:autoservice_web/models/fuel_type.dart';
import 'package:autoservice_web/models/mechanic.dart';
import 'package:autoservice_web/models/service_item.dart';
import 'package:flutter_test/flutter_test.dart';

/// Разбор записей PocketBase: неполные и «кривые» данные не должны
/// приводить к исключению.
void main() {
  group('Автомобиль', () {
    test('отсутствующие поля не приводят к исключению', () {
      final car = Car.fromJson({'id': 'car000000000001'});
      expect(car.plate, '');
      expect(car.year, 0);
      expect(car.modelId, '');
      expect(car.mechanicIds, isEmpty);
      expect(car.deletedAt, isNull);
    });

    test(
      'пустая дата PocketBase — запись не удалена, заполненная — удалена',
      () {
        expect(Car.fromJson({'deleted_at': ''}).isDeleted, isFalse);
        final deleted = Car.fromJson({
          'deleted_at': '2026-08-14 00:00:00.000Z',
        });
        expect(deleted.isDeleted, isTrue);
        expect(deleted.deletedAt!.toUtc(), DateTime.utc(2026, 8, 14));
      },
    );

    test('связь «многие»: повторы и пустые идентификаторы отбрасываются', () {
      final car = Car.fromJson({
        'mechanics': ['m1', 'm1', '', 42, 'm2'],
      });
      expect(car.mechanicIds, ['m1', 'm2']);
    });

    test('число строкой и целое с точкой разбираются', () {
      final car = Car.fromJson({'year': '2019', 'mileage': 84500.0});
      expect(car.year, 2019);
      expect(car.mileage, 84500);
    });

    test('неизвестный тип двигателя заменяется бензином', () {
      expect(Car.fromJson({'fuel': 'nuclear'}).fuel, FuelType.petrol);
    });

    test('JSON для сервера совпадает с полями коллекции', () {
      const car = Car(
        id: 'c1',
        plate: 'А123ВС777',
        vin: 'XTA219170K0123456',
        modelId: 'mdl',
        year: 2019,
        mileage: 1000,
        fuel: FuelType.gas,
        clientId: 'cl',
        mechanicIds: ['m1'],
      );
      expect(car.toJson(), {
        'id': 'c1',
        'plate': 'А123ВС777',
        'vin': 'XTA219170K0123456',
        'model': 'mdl',
        'year': 2019,
        'mileage': 1000,
        'fuel': 'gas',
        'client': 'cl',
        'mechanics': ['m1'],
        'deleted_at': '',
      });
    });
  });

  group('Клиент и клубная карта', () {
    test('карта приходит развёрнутой обратной связью', () {
      final client = Client.fromJson({
        'id': 'cl1',
        'last_name': 'Иванов',
        'first_name': 'Сергей',
        'expand': {
          'club_cards_via_client': [
            {
              'id': 'card1',
              'client': 'cl1',
              'number': 'AS-001037',
              'level': 'silver',
              'issued_at': '2019-03-14 00:00:00.000Z',
              'expires_at': '2027-03-14 00:00:00.000Z',
            },
          ],
        },
      });
      expect(client.shortName, 'Иванов С.');
      expect(client.card?.number, 'AS-001037');
      expect(client.card?.level, CardLevel.silver);
    });

    test('без карты — card равна null, без даты окончания — год с выдачи', () {
      expect(Client.fromJson({'id': 'cl2'}).card, isNull);
      final card = ClubCard.fromJson({'issued_at': '2019-03-14 00:00:00.000Z'});
      expect(card.expiresAt.year, 2020);
      expect(card.level, CardLevel.standard);
    });
  });

  test('мастер и услуга: значения по умолчанию', () {
    final mechanic = Mechanic.fromJson({'id': 'm1'});
    expect(mechanic.grade, 1);
    expect(mechanic.experience, 0);

    final service = ServiceItem.fromJson({'id': 's1', 'price': '1200'});
    expect(service.name, '');
    expect(service.price, 1200);
    expect(service.categoryId, '');
  });

  test('запись: развёрнутый автомобиль, статус, источник скидки', () {
    final a = Appointment.fromJson({
      'id': 'a1',
      'car': 'c1',
      'mechanic': 'm1',
      'services': ['s1', 's2'],
      'starts_at': '2026-10-09 06:00:00.000Z',
      'ends_at': '2026-10-09 07:30:00.000Z',
      'status': 'in_progress',
      'subtotal': 4000,
      'discount_percent': 10,
      'discount_source': 'card',
      'total': 3600,
      'expand': {
        'car': {'id': 'c1', 'plate': 'А123ВС777'},
      },
    });
    expect(a.status, AppointmentStatus.inProgress);
    expect(a.duration, const Duration(minutes: 90));
    expect(a.discountSource, DiscountSource.card);
    expect(a.car?.plate, 'А123ВС777');
    // Расчётные поля на сервер не отправляются — их считает хук.
    expect(a.toJson().containsKey('total'), isFalse);
    expect(a.toJson().containsKey('ends_at'), isFalse);
  });

  test('пользователь: неизвестная роль даёт роль клиента', () {
    final user = AppUser.fromJson({
      'id': 'u1',
      'username': 'admin',
      'role': 'superuser',
      'client': '',
    });
    expect(user.role, Role.client);
    expect(user.clientId, isNull);
  });
}
