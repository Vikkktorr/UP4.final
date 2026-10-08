import 'dart:convert';
import 'dart:typed_data';

import 'package:autoservice_web/core/api_client.dart';
import 'package:autoservice_web/core/api_exceptions.dart';
import 'package:autoservice_web/models/car.dart';
import 'package:autoservice_web/models/car_query.dart';
import 'package:autoservice_web/models/fuel_type.dart';
import 'package:autoservice_web/repositories/api_brand_repository.dart';
import 'package:autoservice_web/repositories/api_car_repository.dart';
import 'package:autoservice_web/repositories/data_changes.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Подменённый транспорт Dio: вместо сети отвечает заданная функция,
/// все запросы сохраняются для проверки.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.reply);

  final Future<ResponseBody> Function(RequestOptions options) reply;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return reply(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody json(int status, Object? body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json; charset=utf-8'],
  },
);

/// Сервер недоступен: так Dio сообщает об отказе в соединении.
Future<ResponseBody> unreachable(RequestOptions options) => Future.error(
  DioException.connectionError(
    requestOptions: options,
    reason: 'Connection refused',
  ),
);

/// Запись автомобиля в том виде, в каком её отдаёт PocketBase.
final carJson = {
  'id': 'car000000000001',
  'collectionName': 'cars',
  'plate': 'А123ВС777',
  'vin': 'XTA219170K0123456',
  'model': 'model0000000001',
  'year': 2019,
  'mileage': 84500,
  'fuel': 'petrol',
  'client': 'client000000003',
  'mechanics': ['mech00000000006'],
  'deleted_at': '',
  'created': '2026-10-08 10:00:00.000Z',
};

const newCar = Car(
  id: '',
  plate: 'А999АА77',
  vin: 'XTA219170K0123456',
  modelId: 'model0000000001',
  year: 2020,
  mileage: 100,
  fuel: FuelType.petrol,
  clientId: 'client000000001',
  mechanicIds: ['mech00000000001'],
);

void main() {
  late FakeAdapter adapter;
  late DataChanges changes;

  Dio dioWith(Future<ResponseBody> Function(RequestOptions) reply) {
    adapter = FakeAdapter(reply);
    // Тот же клиент, что в приложении, но без пауз между повторами.
    return buildDio(retryDelay: Duration.zero)..httpClientAdapter = adapter;
  }

  setUp(() => changes = DataChanges());

  test(
    'find передаёт поиск, фильтры, сортировку и страницу в PocketBase и разбирает ответ',
    () async {
      final repo = ApiCarRepository(
        dioWith(
          (_) async => json(200, {
            'items': [carJson],
            'page': 2,
            'perPage': 10,
            'totalItems': 11,
            'totalPages': 2,
          }),
        ),
        changes: changes,
      );

      final page = await repo.find(
        const CarQuery(
          search: ' kia ',
          brandId: 'brand0000000002',
          fuel: FuelType.diesel,
          sortField: 'year',
          sortAscending: false,
          page: 2,
        ),
      );

      final sent = adapter.requests.single;
      expect(sent.method, 'GET');
      expect(sent.path, '/api/collections/cars/records');
      expect(sent.queryParameters['page'], 2);
      expect(sent.queryParameters['perPage'], 10);
      expect(sent.queryParameters['sort'], '-year,id');
      final filter = sent.queryParameters['filter'] as String;
      // Поиск по госномеру и VIN, марка — через связь модели.
      expect(filter, contains('plate ~ "kia"'));
      expect(filter, contains('vin ~ "Kia"'));
      expect(filter, contains('model.brand = "brand0000000002"'));
      expect(filter, contains('fuel = "diesel"'));
      expect(filter, contains('deleted_at = ""'));
      expect(page.total, 11);
      expect(page.page, 2);
      final car = page.items.single;
      expect(car.id, 'car000000000001');
      expect(car.modelId, 'model0000000001');
      expect(car.clientId, 'client000000003');
      expect(car.mechanicIds, ['mech00000000006']);
      expect(car.deletedAt, isNull);
    },
  );

  test(
    'ошибка PocketBase по полям разбирается в ValidationException',
    () async {
      final repo = ApiCarRepository(
        dioWith(
          (_) async => json(400, {
            'status': 400,
            'message': 'Failed to create record.',
            'data': {
              'vin': {
                'code': 'validation_not_unique',
                'message': 'Value must be unique.',
              },
            },
          }),
        ),
        changes: changes,
      );

      await expectLater(
        repo.create(newCar),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.errors['vin'],
            'errors[vin]',
            'Такое значение уже есть',
          ),
        ),
      );
      // В тело запроса уходят идентификаторы связей, без id и deleted_at.
      final body = adapter.requests.single.data as Map<String, dynamic>;
      expect(body['model'], 'model0000000001');
      expect(body['mechanics'], ['mech00000000001']);
      expect(body.containsKey('id'), isFalse);
      expect(body.containsKey('deleted_at'), isFalse);
    },
  );

  test('ответ 422 из хука сервера — ошибка у поля starts_at', () async {
    final repo = ApiCarRepository(
      dioWith(
        (_) async => json(422, {
          'status': 422,
          'message':
              'Автосервис работает с 9:00 до 20:00, работы займут 60 мин.',
          'data': {
            'starts_at': {
              'code': 'validation_starts_at',
              'message':
                  'Автосервис работает с 9:00 до 20:00, работы займут 60 мин.',
            },
          },
        }),
      ),
      changes: changes,
    );

    await expectLater(
      repo.create(newCar),
      throwsA(
        isA<ValidationException>().having(
          (e) => e.errors['starts_at'],
          'errors[starts_at]',
          contains('с 9:00 до 20:00'),
        ),
      ),
    );
  });

  test('ответ 409 разбирается в ConflictException с текстом сервера', () async {
    final repo = ApiCarRepository(
      dioWith(
        (_) async => json(409, {
          'status': 409,
          'message': 'Мастер занят с 10:00 до 11:30 — выберите другое время.',
          'data': {},
        }),
      ),
      changes: changes,
    );

    await expectLater(
      repo.create(newCar),
      throwsA(
        isA<ConflictException>().having(
          (e) => e.message,
          'message',
          contains('Мастер занят'),
        ),
      ),
    );
  });

  test('недоступный сервер даёт NetworkException, а не DioException', () async {
    final repo = ApiCarRepository(dioWith(unreachable), changes: changes);

    await expectLater(repo.create(newCar), throwsA(isA<NetworkException>()));
    // Создание записи не повторяется: повтор мог бы создать дубль.
    expect(adapter.requests, hasLength(1));
  });

  test('чтение при сетевом сбое повторяется не больше трёх раз', () async {
    final repo = ApiCarRepository(dioWith(unreachable), changes: changes);

    await expectLater(
      repo.find(const CarQuery()),
      throwsA(isA<NetworkException>()),
    );
    expect(adapter.requests, hasLength(4)); // первая попытка и три повтора
  });

  test('после сбоя повтор получает данные', () async {
    var calls = 0;
    final repo = ApiCarRepository(
      dioWith((options) {
        calls++;
        return calls < 3
            ? unreachable(options)
            : Future.value(json(200, carJson));
      }),
      changes: changes,
    );

    final car = await repo.findById('car000000000001');
    expect(car?.plate, 'А123ВС777');
    expect(calls, 3);
  });

  test('404 в findById даёт null, 500 — ServerException', () async {
    final notFound = ApiCarRepository(
      dioWith(
        (_) async =>
            json(404, {'message': "The requested resource wasn't found."}),
      ),
      changes: changes,
    );
    expect(await notFound.findById('nosuch000000000'), isNull);

    final broken = ApiCarRepository(
      dioWith((_) async => json(500, {'message': 'Сбой'})),
      changes: changes,
    );
    await expectLater(
      broken.find(const CarQuery()),
      throwsA(isA<ServerException>()),
    );
  });

  test('справочник запрашивается один раз, после изменения — заново', () async {
    final repo = ApiBrandRepository(
      dioWith(
        (options) async => options.method == 'GET'
            ? json(200, {
                'items': [
                  {
                    'id': 'brand0000000001',
                    'name': 'Lada',
                    'country': 'Россия',
                    'deleted_at': '',
                  },
                ],
                'page': 1,
                'perPage': 500,
                'totalItems': 1,
                'totalPages': 1,
              })
            : json(204, null),
      ),
      changes: changes,
    );
    var notified = 0;
    changes.addListener(() => notified++);

    await repo.findAll();
    await repo.findAll();
    expect(adapter.requests, hasLength(1));

    await repo.softDelete('brand0000000001');
    expect(notified, 1);
    await repo.findAll();
    expect(adapter.requests.where((r) => r.method == 'GET'), hasLength(2));
  });

  test('новый поиск отменяет предыдущий запрос', () async {
    final repo = ApiCarRepository(
      dioWith(
        (_) => Future.delayed(
          const Duration(milliseconds: 50),
          () => json(200, {
            'items': [],
            'page': 1,
            'perPage': 10,
            'totalItems': 0,
            'totalPages': 0,
          }),
        ),
      ),
      changes: changes,
    );

    final first = repo.find(const CarQuery(search: 'ла'));
    final second = repo.find(const CarQuery(search: 'лада'));

    await expectLater(
      first,
      throwsA(
        isA<NetworkException>().having(
          (e) => e.message,
          'message',
          'Запрос отменён.',
        ),
      ),
    );
    expect((await second).total, 0);
  });
}
