import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/app_user.dart';

/// Ответ PocketBase на вход и обновление токена: токен и учётная запись.
class AuthResult {
  const AuthResult({required this.token, required this.user});

  final String token;
  final AppUser user;

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
    token: json['token'] as String,
    user: AppUser.fromJson(json['record'] as Map<String, dynamic>),
  );
}

/// Вход, регистрация и обновление токена через коллекцию users PocketBase.
///
/// Пароль уходит на сервер как есть: хеширует его сервер. Хеш, посчитанный
/// в браузере, ничего не защищает — он просто становится новым паролем.
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  static const _users = '/api/collections/users';

  /// Вход по логину (или e-mail) и паролю.
  Future<AuthResult> login(String username, String password) => guard(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_users/auth-with-password',
      data: {'identity': username, 'password': password},
    );
    return AuthResult.fromJson(response.data!);
  });

  /// Регистрация — обычное создание записи в users. Правило коллекции
  /// разрешает гостю только роль client; сервер сам заводит карточку
  /// клиента и связывает её с учётной записью. Затем — вход.
  Future<AuthResult> register({
    required String username,
    required String password,
    required String lastName,
    required String firstName,
  }) async {
    await guard(
      () => _dio.post<void>(
        '$_users/records',
        data: {
          'username': username,
          'password': password,
          'passwordConfirm': password,
          'last_name': lastName,
          'first_name': firstName,
          'role': 'client',
        },
      ),
    );
    return login(username, password);
  }

  /// Новый токен взамен ещё действующего. С истёкшим токеном PocketBase
  /// отвечает 401 — тогда остаётся только войти заново.
  Future<AuthResult> refresh(String token) => guard(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_users/auth-refresh',
      options: Options(headers: {'Authorization': token}),
    );
    return AuthResult.fromJson(response.data!);
  });
}

/// Срок действия токена — поле exp внутри JWT. Подпись здесь не
/// проверяется: это делает сервер, приложению нужен только срок.
DateTime? tokenExpiry(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    final exp = payload is Map ? payload['exp'] : null;
    return exp is int ? DateTime.fromMillisecondsSinceEpoch(exp * 1000) : null;
  } catch (_) {
    return null;
  }
}
