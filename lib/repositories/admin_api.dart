import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../core/json.dart';
import '../core/pocketbase.dart';
import '../models/app_user.dart';

/// Статистика для экрана администратора.
class Stats {
  const Stats({
    required this.counts,
    required this.deleted,
    required this.users,
    required this.revenue,
  });

  /// Действующие записи по коллекциям: cars, clients, brands…
  final Map<String, int> counts;

  /// Логически удалённые записи по коллекциям.
  final Map<String, int> deleted;

  /// Пользователи по ролям: client, mechanic, admin.
  final Map<String, int> users;

  /// Выручка по выполненным записям на обслуживание, ₽.
  final int revenue;
}

/// Операции администратора: пользователи, роли, статистика.
/// Правила PocketBase выполняют их только для роли admin.
class AdminApi {
  AdminApi(this._dio);

  final Dio _dio;

  static const _users = '/api/collections/users/records';

  /// Коллекции, по которым считается статистика.
  static const collections = [
    'cars',
    'clients',
    'brands',
    'car_models',
    'mechanics',
    'services',
    'service_categories',
    'appointments',
  ];

  Future<List<AppUser>> users() => guard(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      _users,
      queryParameters: {'perPage': 500, 'sort': 'username'},
    );
    return [
      for (final json in response.data!['items'] as List)
        AppUser.fromJson(json as Map<String, dynamic>),
    ];
  });

  Future<void> setRole(String id, Role role) => guard(() async {
    await _dio.patch<void>('$_users/$id', data: {'role': role.name});
  });

  Future<void> deleteUser(String id) => guard(() async {
    await _dio.delete<void>('$_users/$id');
  });

  /// Сколько записей подходит под фильтр: PocketBase возвращает totalItems,
  /// сами записи не нужны — достаточно страницы из одной.
  Future<int> _count(String collection, String filter) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/collections/$collection/records',
      queryParameters: {'perPage': 1, 'fields': 'id', 'filter': filter},
    );
    return readInt(response.data!, 'totalItems');
  }

  Future<Stats> stats() => guard(() async {
    final counts = <String, int>{};
    final deleted = <String, int>{};
    for (final c in collections) {
      counts[c] = await _count(c, 'deleted_at = ""');
      deleted[c] = await _count(c, 'deleted_at != ""');
    }
    final users = {
      for (final role in Role.values)
        role.name: await _count('users', 'role = ${pbString(role.name)}'),
    };
    var revenue = 0;
    for (var page = 1; ; page++) {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/collections/appointments/records',
        queryParameters: {
          'page': page,
          'perPage': 500,
          'fields': 'total',
          'filter': 'status = "done" && deleted_at = ""',
        },
      );
      final data = response.data!;
      for (final item in (data['items'] as List).cast<Map<String, dynamic>>()) {
        revenue += readInt(item, 'total');
      }
      if (page >= readInt(data, 'totalPages', 1)) break;
    }
    return Stats(
      counts: counts,
      deleted: deleted,
      users: users,
      revenue: revenue,
    );
  });
}
