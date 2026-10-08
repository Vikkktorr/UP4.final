import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_exceptions.dart';
import '../core/config.dart';
import '../core/permissions.dart';
import '../models/app_user.dart';
import '../repositories/auth_api.dart';

/// Сессия пользователя: токен, профиль, сроки.
///
/// Токен и профиль лежат в shared_preferences, то есть в localStorage:
/// они должны пережить перезагрузку страницы. Профиль с ролью хранится
/// только для того, чтобы сразу нарисовать интерфейс. Права по нему не
/// проверяются — роль для решения «разрешить операцию» сервер берёт
/// из подписанного токена.
class AuthNotifier extends ChangeNotifier {
  static const _kAccess = 'auth_access_token';
  static const _kUser = 'auth_user';
  static const _kStarted = 'auth_session_started';
  static const _kActivity = 'auth_last_activity';

  AuthNotifier(this._prefs, this._api);

  final SharedPreferences _prefs;
  final AuthApi _api;

  AppUser? _user;
  String? _accessToken;
  String? _endReason;
  Timer? _sessionTimer;
  Future<void>? _refreshing;
  DateTime _lastTouchSaved = DateTime.fromMillisecondsSinceEpoch(0);

  AppUser? get user => _user;
  String? get accessToken => _accessToken;

  /// За сколько до истечения токен обновляется заранее.
  static const refreshAhead = Duration(minutes: 2);
  bool get isAuthenticated => _user != null;

  /// Почему сессия завершилась — показывается на экране входа.
  String? get endReason => _endReason;

  bool has(Role role) => _user != null && _user!.role.level >= role.level;
  bool can(Operation operation) => isAllowed(_user?.role, operation);

  /// Восстановление сессии при запуске приложения.
  /// Вызывается один раз до построения дерева виджетов.
  Future<void> restore() async {
    final access = _prefs.getString(_kAccess);
    if (access == null) return;

    // Сроки проверяются и через перезагрузку: таймеры живут в памяти
    // вкладки, а время начала сессии и последнего действия — в localStorage.
    final now = DateTime.now();
    final started = _readTime(_kStarted);
    if (started != null && now.difference(started) >= sessionMaxDuration) {
      return logout(reason: _sessionOverMessage);
    }
    final activity = _readTime(_kActivity);
    if (activity != null && now.difference(activity) >= inactivityTimeout) {
      return logout(reason: inactivityMessage);
    }

    // Истёкший токен PocketBase обновить нельзя — только войти заново.
    final expiry = tokenExpiry(access);
    if (expiry != null && !expiry.isAfter(now)) {
      return logout(reason: _expiredMessage);
    }

    _accessToken = access;
    final cached = _readUser();
    if (cached != null) {
      // Профиль из прошлого входа: интерфейс рисуется сразу.
      _user = cached;
    } else {
      try {
        await _saveTokens(await _api.refresh(access));
      } on UnauthorizedException {
        return logout(reason: _expiredMessage);
      } catch (_) {
        // Сервер недоступен: сессию не сбрасываем, покажем ошибку позже
      }
    }
    _scheduleSessionEnd(started ?? now);
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    await _start(await _api.login(username, password));
  }

  Future<void> register({
    required String username,
    required String password,
    required String lastName,
    required String firstName,
  }) async {
    await _start(
      await _api.register(
        username: username,
        password: password,
        lastName: lastName,
        firstName: firstName,
      ),
    );
  }

  /// Обновление токена: действующий токен меняется на новый с полным
  /// сроком (auth-refresh). Если несколько запросов одновременно получили
  /// 401, обновление выполняется один раз, остальные ждут его результата.
  Future<void> refreshTokens() {
    final token = _accessToken;
    if (token == null) {
      return Future.error(const UnauthorizedException());
    }
    return _refreshing ??= _refreshWith(token).whenComplete(() {
      _refreshing = null;
    });
  }

  /// Перед каждым запросом: если токену осталось жить меньше
  /// [refreshAhead], он обновляется заранее — пользователь не увидит 401.
  Future<void> ensureFreshToken() async {
    final token = _accessToken;
    if (token == null) return;
    final expiry = tokenExpiry(token);
    if (expiry == null) return;
    final left = expiry.difference(DateTime.now());
    if (left > refreshAhead || left.isNegative) return;
    try {
      await refreshTokens();
    } catch (_) {
      // Не вышло — запрос уйдёт со старым токеном, а на 401 сработает
      // общий обработчик.
    }
  }

  /// Выход: токены и профиль удаляются из localStorage.
  /// [reason] — сообщение для экрана входа.
  Future<void> logout({String? reason}) async {
    _sessionTimer?.cancel();
    _user = null;
    _accessToken = null;
    _endReason = reason;
    await _prefs.remove(_kAccess);
    await _prefs.remove(_kUser);
    await _prefs.remove(_kStarted);
    await _prefs.remove(_kActivity);
    notifyListeners();
  }

  /// Пользователь что-то сделал. Время записывается не чаще раза
  /// в пять секунд, чтобы не писать в localStorage на каждое движение мыши.
  void touch() {
    final now = DateTime.now();
    if (now.difference(_lastTouchSaved) < const Duration(seconds: 5)) return;
    _lastTouchSaved = now;
    _prefs.setInt(_kActivity, now.millisecondsSinceEpoch);
  }

  static const _expiredMessage = 'Сессия истекла: войдите в систему снова.';

  static const inactivityMessage =
      'Сессия завершена: не было действий в течение трёх минут.';
  static final _sessionOverMessage =
      'Сессия завершена: истекло допустимое время работы '
      '(${sessionMaxDuration.inMinutes} мин). Войдите снова.';

  Future<void> _start(AuthResult result) async {
    _endReason = null;
    final now = DateTime.now();
    await _saveTokens(result);
    await _prefs.setInt(_kStarted, now.millisecondsSinceEpoch);
    await _prefs.setInt(_kActivity, now.millisecondsSinceEpoch);
    _scheduleSessionEnd(now);
    notifyListeners();
  }

  Future<void> _refreshWith(String token) async {
    final result = await _api.refresh(token);
    // Время начала сессии не сдвигается: обновление токена не продлевает
    // общий срок работы.
    await _saveTokens(result);
    notifyListeners();
  }

  Future<void> _saveTokens(AuthResult result) async {
    _accessToken = result.token;
    _user = result.user;
    await _prefs.setString(_kAccess, result.token);
    await _saveUser(result.user);
  }

  Future<void> _saveUser(AppUser user) =>
      _prefs.setString(_kUser, jsonEncode(user.toJson()));

  AppUser? _readUser() {
    final raw = _prefs.getString(_kUser);
    if (raw == null) return null;
    try {
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  DateTime? _readTime(String key) {
    final ms = _prefs.getInt(key);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Ограничение общей длительности сессии — независимо от активности.
  void _scheduleSessionEnd(DateTime started) {
    _sessionTimer?.cancel();
    final left = sessionMaxDuration - DateTime.now().difference(started);
    _sessionTimer = Timer(
      left.isNegative ? Duration.zero : left,
      () => logout(reason: _sessionOverMessage),
    );
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }
}
