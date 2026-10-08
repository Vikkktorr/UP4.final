import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/api_exceptions.dart';
import '../core/json.dart';
import '../core/pocketbase.dart';
import '../models/entity.dart';
import '../models/page_result.dart';
import 'data_changes.dart';
import 'entity_repository.dart';

/// Репозиторий поверх REST API PocketBase. Интерфейс [EntityRepository]
/// прежний — поменялась только реализация.
///
/// Записи коллекции лежат по адресу `/api/collections/{collection}/records`.
/// Всё общее — страницы, удаление, восстановление — написано здесь один раз.
/// Наследник задаёт коллекцию, разбор JSON, фильтр и сортировку. Каждое
/// обращение к сети обёрнуто в [guard]: наружу выходят только исключения
/// предметной области.
abstract class ApiRepository<T extends Entity, Q extends PagedQuery>
    implements EntityRepository<T, Q> {
  ApiRepository(
    this._dio, {
    required this.collection,
    required this.changes,
    this.expand,
    this.cacheAll = false,
  });

  final Dio _dio;

  @protected
  Dio get dio => _dio;

  /// Имя коллекции PocketBase: `cars`, `brands`…
  final String collection;

  /// Связи, которые PocketBase разворачивает прямо в ответе (`expand`).
  final String? expand;

  final DataChanges changes;

  /// Справочник: полный список запрашивается один раз и хранится, пока
  /// записи этого ресурса не изменятся.
  final bool cacheAll;

  @protected
  String get path => '/api/collections/$collection/records';

  // ---- то, что описывает наследник ----

  T fromJson(Map<String, dynamic> json);

  /// Поиск и фильтры в виде выражения PocketBase, без условия про удалённые.
  String filterOf(Q query);

  /// Поле PocketBase для сортировки по полю [PagedQuery.sortField].
  String sortFieldOf(String field) => field;

  /// Тело запроса на создание и изменение: без id и отметки удаления —
  /// удаляют и восстанавливают отдельные операции.
  @protected
  Map<String, dynamic> toBody(T item) => item.toJson()
    ..remove('id')
    ..remove('deleted_at');

  // ---- чтение ----

  CancelToken? _findToken;
  Future<List<T>>? _cache;

  @override
  Future<PageResult<T>> find(Q q) => guard(() async {
    // Отмена устаревшего запроса: при быстром вводе в поле поиска
    // ответ на «Ki» не должен прийти после ответа на «Kia» и затереть его.
    _findToken?.cancel('Запрос устарел');
    final token = _findToken = CancelToken();
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: {
        'page': q.page,
        'perPage': q.size,
        'sort': pbSort(sortFieldOf(q.sortField), q.sortAscending),
        'filter': pbAnd([filterOf(q), pbNotDeleted(q.includeDeleted)]),
        'expand': ?expand,
      },
      cancelToken: token,
    );
    return _page(response.data!);
  });

  PageResult<T> _page(Map<String, dynamic> data) => PageResult(
    items: (data['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(fromJson)
        .toList(),
    page: readInt(data, 'page', 1),
    size: readInt(data, 'perPage', 10),
    total: readInt(data, 'totalItems'),
  );

  /// Записи по произвольному фильтру — для карточек: записи автомобиля,
  /// модели марки. [limit] — сколько записей вернуть.
  Future<PageResult<T>> findWhere(
    String filter, {
    String sort = 'id',
    int limit = 50,
  }) => guard(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: {
        'perPage': limit,
        'sort': sort,
        'filter': filter,
        'expand': ?expand,
      },
    );
    return _page(response.data!);
  });

  @override
  Future<List<T>> findAll() {
    if (!cacheAll) return _loadAll();
    final future = _cache ??= _loadAll();
    // Неудачный запрос не кэшируется — следующая загрузка повторит его.
    future.then(
      (_) {},
      onError: (_) {
        if (identical(_cache, future)) _cache = null;
      },
    );
    return future;
  }

  Future<List<T>> _loadAll() => guard(() async {
    // PocketBase отдаёт не больше 500 записей за раз — собираем по страницам.
    final all = <T>[];
    for (var page = 1; ; page++) {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: {
          'page': page,
          'perPage': 500,
          'sort': 'id',
          'expand': ?expand,
        },
      );
      final result = _page(response.data!);
      all.addAll(result.items);
      if (result.items.isEmpty || all.length >= result.total) break;
    }
    return List<T>.unmodifiable(all);
  });

  @override
  Future<T?> findById(String id) async {
    try {
      return await guard(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '$path/$id',
          queryParameters: {'expand': ?expand},
        );
        return fromJson(response.data!);
      });
    } on NotFoundException {
      return null;
    }
  }

  // ---- запись ----

  @override
  Future<T> create(T entity) => _write(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: toBody(entity),
      queryParameters: {'expand': ?expand},
    );
    return fromJson(response.data!);
  });

  @override
  Future<T> update(T entity) => _write(() async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '$path/${entity.id}',
      data: toBody(entity),
      queryParameters: {'expand': ?expand},
    );
    return fromJson(response.data!);
  });

  /// Логическое удаление — отметка времени в deleted_at.
  @override
  Future<void> softDelete(String id) => _write(
    () => _dio.patch<void>(
      '$path/$id',
      data: {'deleted_at': dateTimeToJson(DateTime.now())},
    ),
  );

  @override
  Future<void> hardDelete(String id) =>
      _write(() => _dio.delete<void>('$path/$id'));

  @override
  Future<void> restore(String id) =>
      _write(() => _dio.patch<void>('$path/$id', data: {'deleted_at': ''}));

  /// Логическое удаление нескольких записей одним запросом /api/batch:
  /// PocketBase выполняет их в одной транзакции — удалятся все или ни одна.
  @override
  Future<int> deleteMany(List<String> ids) => _write(() async {
    final now = dateTimeToJson(DateTime.now());
    await _dio.post<void>(
      '/api/batch',
      data: {
        'requests': [
          for (final id in ids)
            {
              'method': 'PATCH',
              'url': '$path/$id',
              'body': {'deleted_at': now},
            },
        ],
      },
    );
    return ids.length;
  });

  /// После успешной записи кэш справочника устаревает, а остальные части
  /// приложения узнают об изменении.
  @protected
  Future<R> write<R>(Future<R> Function() action) => _write(action);

  Future<R> _write<R>(Future<R> Function() action) async {
    final result = await guard(action);
    _cache = null;
    changes.changed();
    return result;
  }
}
