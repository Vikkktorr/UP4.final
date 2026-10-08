import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // kDebugMode, debugPrint

import 'api_exceptions.dart';
import 'config.dart';

/// Настроенный клиент Dio: базовый адрес, таймауты, общая обработка
/// ошибок, журнал запросов и повтор при сетевом сбое.
///
/// [tokenProvider] — текущий токен для заголовка Authorization.
/// [ensureFreshToken] — обновить токен заранее, если он скоро истечёт.
/// [refreshTokens] и [onRefreshFailed] — обновление токена после 401
/// и выход из системы, если обновить не удалось.
/// [simulate] — меню отладки: ответить ошибкой 500 или с задержкой, не
/// трогая сервер. [retryDelay] — пауза перед первым повтором; в тестах
/// её обнуляют.
Dio buildDio({
  String? Function()? tokenProvider,
  Future<void> Function()? ensureFreshToken,
  Future<void> Function()? refreshTokens,
  Future<void> Function()? onRefreshFailed,
  ({bool failing, bool slow}) Function()? simulate,
  Duration retryDelay = const Duration(milliseconds: 500),
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
      // Не бросать исключение на кодах 4xx — разберём их сами
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final sim = simulate?.call();
        if (sim != null && sim.slow) {
          await Future<void>.delayed(const Duration(milliseconds: 1500));
        }
        if (sim != null && sim.failing) {
          // Ответ 500 без обращения к серверу — проверка экрана ошибки.
          return handler.reject(
            DioException(
              requestOptions: options,
              response: Response(requestOptions: options, statusCode: 500),
              type: DioExceptionType.badResponse,
              error: const ServerException(
                'Ошибка сервера 500 (включена в меню отладки).',
              ),
            ),
          );
        }
        if (!isAuthPath(options.path)) await ensureFreshToken?.call();
        final token = tokenProvider?.call();
        // PocketBase ждёт токен в заголовке как есть, без «Bearer».
        if (token != null) options.headers['Authorization'] = token;
        return handler.next(options);
      },
      onResponse: (response, handler) {
        // Коды 4xx попадают сюда, а не в onError, из-за validateStatus.
        final status = response.statusCode ?? 0;
        if (status >= 400) {
          // Просто написать `throw mapHttpError(...)` нельзя: dio перехватит
          // любое исключение из интерсептора и завернёт его в DioException
          // с типом unknown, а наш ValidationException окажется спрятан
          // внутри поля error. Поэтому отправляем ответ по ветке ошибок сами,
          // приложив уже разобранное исключение.
          return handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
              error: mapHttpError(status, response.data),
            ),
            true,
          );
        }
        _log(response.requestOptions, '$status');
        return handler.next(response);
      },
      onError: (error, handler) {
        // Сюда приходят сетевые сбои, таймауты, коды 5xx
        // и всё, что отклонил обработчик выше.
        final status = error.response?.statusCode;
        _log(
          error.requestOptions,
          status != null ? '$status' : 'сбой: ${error.type.name}',
        );
        return handler.next(error);
      },
    ),
  );

  if (refreshTokens != null) {
    dio.interceptors.add(
      AuthRefreshInterceptor(
        dio,
        refreshTokens: refreshTokens,
        onRefreshFailed: onRefreshFailed ?? () async {},
      ),
    );
  }

  dio.interceptors.add(RetryInterceptor(dio, firstDelay: retryDelay));

  return dio;
}

/// Ответ 401: токен пробуем обновить и повторить исходный запрос.
///
/// Обычно до 401 не доходит: токен PocketBase живёт 15 минут, и перед
/// запросом его заранее меняет на свежий ensureFreshToken. Если же токен
/// уже истёк (вкладка долго спала), PocketBase его не обновит — тогда
/// пользователь выходит с сообщением «Сессия истекла».
///
/// Два условия исключают бесконечный цикл:
///  * адреса входа и обновления не обрабатываются — иначе неверный пароль
///    (401) вызвал бы обновление, оно тоже вернуло бы 401, и так без конца;
///  * запрос повторяется только один раз — если и с новым токеном
///    сервер ответил 401, ошибка уходит дальше.
/// Если обновить токен не удалось, пользователь выходит из системы.
class AuthRefreshInterceptor extends Interceptor {
  AuthRefreshInterceptor(
    this._dio, {
    required this.refreshTokens,
    required this.onRefreshFailed,
  });

  final Dio _dio;
  final Future<void> Function() refreshTokens;
  final Future<void> Function() onRefreshFailed;

  static const _retriedKey = 'authRetried';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        isAuthPath(options.path) ||
        options.extra[_retriedKey] == true) {
      return handler.next(err);
    }

    try {
      await refreshTokens();
    } catch (_) {
      if (kDebugMode) debugPrint('[API] обновить токен не удалось — выход');
      await onRefreshFailed();
      return handler.next(err);
    }

    if (kDebugMode) debugPrint('[API] токен обновлён, повтор: ${options.uri}');
    // Заголовок Authorization с новым токеном подставит onRequest.
    options.extra[_retriedKey] = true;
    try {
      return handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      return handler.next(e);
    }
  }
}

/// Вход, регистрация и обновление токена — их токен не подставляется
/// заранее и 401 на них не обрабатывается.
bool isAuthPath(String path) =>
    path.contains('/auth-') || path.endsWith('/collections/users/records');

/// В режиме отладки в консоль выводятся метод, адрес и код ответа.
void _log(RequestOptions options, String result) {
  if (kDebugMode) {
    debugPrint('[API] ${options.method} ${options.uri} → $result');
  }
}

/// Автоматический повтор при сетевом сбое: не более трёх повторов,
/// пауза каждый раз удваивается (0,5 → 1 → 2 с).
///
/// Повторяются только операции чтения (GET). Повторять создание записи
/// нельзя: первый запрос мог дойти до сервера, и повтор создал бы дубль.
class RetryInterceptor extends Interceptor {
  RetryInterceptor(
    this._dio, {
    this.maxRetries = 3,
    this.firstDelay = const Duration(milliseconds: 500),
  });

  final Dio _dio;
  final int maxRetries;
  final Duration firstDelay;

  static const _attemptKey = 'retryAttempt';

  static bool _isNetworkFailure(DioException e) => switch (e.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => true,
    _ => false,
  };

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final attempt = options.extra[_attemptKey] as int? ?? 0;
    if (options.method != 'GET' ||
        !_isNetworkFailure(err) ||
        attempt >= maxRetries) {
      return handler.next(err);
    }

    final delay = firstDelay * (1 << attempt);
    if (kDebugMode) {
      debugPrint(
        '[API] повтор ${attempt + 1} из $maxRetries через '
        '${delay.inMilliseconds} мс: ${options.uri}',
      );
    }
    await Future<void>.delayed(delay);
    // Пока шла пауза, запрос могли отменить как устаревший.
    if (options.cancelToken?.isCancelled ?? false) return handler.next(err);

    options.extra[_attemptKey] = attempt + 1;
    try {
      return handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      return handler.next(e);
    }
  }
}
