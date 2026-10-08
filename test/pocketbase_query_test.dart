import 'dart:convert';

import 'package:autoservice_web/core/api_exceptions.dart';
import 'package:autoservice_web/core/pocketbase.dart';
import 'package:autoservice_web/models/appointment.dart';
import 'package:autoservice_web/models/appointment_query.dart';
import 'package:autoservice_web/models/client_query.dart';
import 'package:autoservice_web/repositories/auth_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// Параметры запросов к PocketBase и разбор его ответов.
void main() {
  test('строка в фильтре экранируется', () {
    expect(pbString('Kia'), '"Kia"');
    expect(pbString('a"b'), r'"a\"b"');
    expect(pbString(r'a\b'), r'"a\\b"');
  });

  test(
    'поиск: несколько написаний, чтобы кириллица искалась без учёта регистра',
    () {
      final f = pbSearch(['last_name'], 'гро');
      expect(f, contains('last_name ~ "гро"'));
      expect(f, contains('last_name ~ "Гро"'));
      expect(f, contains('last_name ~ "ГРО"'));
      expect(pbSearch(['name'], '   '), '');
    },
  );

  test('условия соединяются через «и», пустые пропускаются', () {
    expect(pbAnd(['a = 1', '', 'b = 2']), '(a = 1) && (b = 2)');
    expect(pbAnd(['a = 1']), 'a = 1');
    expect(pbAnd(['']), '');
  });

  test('сортировка: минус — по убыванию, вторым ключом id', () {
    expect(pbSort('year', false), '-year,id');
    expect(pbSort('plate', true), 'plate,id');
  });

  test('условия отбора записей переживают адрес туда и обратно', () {
    final q = AppointmentQuery(
      search: 'А123',
      status: AppointmentStatus.planned,
      mechanicId: 'mech00000000001',
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 31),
      page: 2,
    );
    final params = q.toQueryParameters();
    expect(params['from'], '2026-10-01');
    expect(params['status'], 'planned');
    expect(AppointmentQuery.fromQueryParameters(params), q);
    // Мусор в адресе — фильтр не задан, без исключений.
    final junk = AppointmentQuery.fromQueryParameters({
      'from': '2026-13-45',
      'mechanicId': 'DROP TABLE',
      'status': 'nope',
    });
    expect(junk.from, isNull);
    expect(junk.mechanicId, isNull);
    expect(junk.status, isNull);
  });

  test('фильтры клиентов: скидка и годы попадают в адрес', () {
    const q = ClientQuery(discountFrom: 5, sinceFrom: 2019, sinceTo: 2021);
    final params = q.toQueryParameters();
    expect(params, containsPair('discountFrom', '5'));
    expect(ClientQuery.fromQueryParameters(params), q);
  });

  test('ошибки PocketBase переводятся, 409 — конфликт с текстом сервера', () {
    final v = mapHttpError(400, {
      'message': 'Failed to create record.',
      'data': {
        'name': {'code': 'validation_required', 'message': 'Cannot be blank.'},
      },
    });
    expect(v, isA<ValidationException>());
    expect((v as ValidationException).errors['name'], 'Обязательное поле');

    final c = mapHttpError(409, {'message': 'Мастер занят с 10:00 до 11:30.'});
    expect(c, isA<ConflictException>());
    expect(c.message, contains('Мастер занят'));

    expect(
      mapHttpError(400, {'message': 'Failed to authenticate.'}).message,
      'Неверный логин или пароль.',
    );
  });

  test('срок действия токена читается из JWT', () {
    String jwt(Map<String, Object> payload) =>
        'h.${base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '')}.s';
    final exp = DateTime(2026, 10, 9, 12).millisecondsSinceEpoch ~/ 1000;
    expect(
      tokenExpiry(jwt({'exp': exp})),
      DateTime.fromMillisecondsSinceEpoch(exp * 1000),
    );
    expect(tokenExpiry('не токен'), isNull);
  });
}
