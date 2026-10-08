import 'package:autoservice_web/core/permissions.dart';
import 'package:autoservice_web/models/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

/// Соответствие роли и доступности операции. Таблица в
/// lib/core/permissions.dart должна совпадать с правилами доступа PocketBase.
void main() {
  test('без входа недоступно ничего', () {
    for (final operation in Operation.values) {
      expect(isAllowed(null, operation), isFalse, reason: operation.name);
    }
  });

  test('каталог услуг доступен всем трём ролям', () {
    for (final role in Role.values) {
      expect(isAllowed(role, Operation.viewCatalog), isTrue, reason: role.name);
    }
  });

  test('клиент не изменяет и не удаляет записи', () {
    expect(isAllowed(Role.client, Operation.viewWorkshop), isFalse);
    expect(isAllowed(Role.client, Operation.editRecords), isFalse);
    expect(isAllowed(Role.client, Operation.softDelete), isFalse);
  });

  test(
    'мастер изменяет записи, но не удаляет навсегда и не восстанавливает',
    () {
      expect(isAllowed(Role.mechanic, Operation.viewWorkshop), isTrue);
      expect(isAllowed(Role.mechanic, Operation.editRecords), isTrue);
      expect(isAllowed(Role.mechanic, Operation.softDelete), isTrue);
      expect(isAllowed(Role.mechanic, Operation.hardDelete), isFalse);
      expect(isAllowed(Role.mechanic, Operation.restore), isFalse);
    },
  );

  test(
    'пользователи, статистика и физическое удаление — только администратор',
    () {
      for (final operation in [
        Operation.manageUsers,
        Operation.viewStats,
        Operation.hardDelete,
        Operation.restore,
      ]) {
        expect(
          isAllowed(Role.admin, operation),
          isTrue,
          reason: operation.name,
        );
        expect(isAllowed(Role.mechanic, operation), isFalse);
        expect(isAllowed(Role.client, operation), isFalse);
      }
    },
  );

  test('«Мои автомобили» — только клиенту, даже администратор их не видит', () {
    expect(isAllowed(Role.client, Operation.viewOwnCars), isTrue);
    expect(isAllowed(Role.mechanic, Operation.viewOwnCars), isFalse);
    expect(isAllowed(Role.admin, Operation.viewOwnCars), isFalse);
  });

  test('записать свой автомобиль к мастеру может только клиент', () {
    expect(isAllowed(Role.client, Operation.bookOwnCar), isTrue);
    expect(isAllowed(Role.mechanic, Operation.bookOwnCar), isFalse);
    expect(isAllowed(Role.admin, Operation.bookOwnCar), isFalse);
  });

  test('«Мой график» — только мастеру', () {
    expect(isAllowed(Role.mechanic, Operation.viewOwnSchedule), isTrue);
    expect(isAllowed(Role.client, Operation.viewOwnSchedule), isFalse);
    expect(isAllowed(Role.admin, Operation.viewOwnSchedule), isFalse);
  });

  test('записи всех автомобилей ведут мастер и администратор', () {
    expect(isAllowed(Role.client, Operation.manageAppointments), isFalse);
    expect(isAllowed(Role.mechanic, Operation.manageAppointments), isTrue);
    expect(isAllowed(Role.admin, Operation.manageAppointments), isTrue);
  });

  test('у каждой роли есть операция, недоступная остальным', () {
    for (final role in Role.values) {
      final own = Operation.values.where(
        (op) =>
            isAllowed(role, op) &&
            Role.values.where((r) => r != role).every((r) => !isAllowed(r, op)),
      );
      expect(own, isNotEmpty, reason: role.name);
    }
  });

  test('роль из профиля: неизвестное значение даёт минимальные права', () {
    expect(Role.fromName('superuser'), Role.client);
    expect(Role.fromName(null), Role.client);
    expect(Role.fromName('admin'), Role.admin);
  });
}
