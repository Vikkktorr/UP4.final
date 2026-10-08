import 'package:dio/dio.dart';

/// Исключения предметной области. Виджеты не знают о существовании Dio:
/// между сетевым слоем и остальным приложением стоит этот набор.
/// Текст [message] рассчитан на показ пользователю.
sealed class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

/// Нет соединения, таймаут, сервер недоступен, заблокировано CORS
class NetworkException extends ApiException {
  const NetworkException([
    super.message = 'Сервер недоступен. Проверьте соединение.',
  ]);
}

/// 401 — не аутентифицирован либо срок действия токена истёк
class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Требуется вход в систему.']);
}

/// 403 — роль не позволяет выполнить операцию
class ForbiddenException extends ApiException {
  const ForbiddenException([
    super.message = 'Недостаточно прав для этого действия.',
  ]);
}

/// 404
class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Запись не найдена.']);
}

/// 409 — нарушено правило предметной области: мастер занят в это время,
/// на марку ссылаются модели.
class ConflictException extends ApiException {
  const ConflictException(super.message);
}

/// 400/422 — ошибки валидации по полям. Ключи [errors] совпадают с именами
/// полей формы: `vin`, `phone`, `starts_at`.
class ValidationException extends ApiException {
  final Map<String, String> errors;
  const ValidationException(super.message, this.errors);
}

/// 5xx
class ServerException extends ApiException {
  const ServerException([
    super.message = 'Ошибка на сервере. Попробуйте позже.',
  ]);
}

/// Разбор ответа PocketBase с ошибкой: `{status, message, data}`.
///
/// В `data` — ошибки по полям: `{"plate": {"code": "validation_not_unique",
/// "message": "Value must be unique."}}`. Имя поля совпадает с путём поля
/// формы, поэтому ошибка показывается у нужного поля. Стандартные
/// сообщения PocketBase — на английском, их переводим по коду.
ApiException mapHttpError(int status, dynamic body) {
  final raw = (body is Map && body['message'] is String)
      ? body['message'] as String
      : null;
  final message = raw == null ? null : _translate(raw);
  final errors = <String, String>{
    if (body is Map && body['data'] is Map)
      for (final MapEntry(:key, :value) in (body['data'] as Map).entries)
        if (value is Map)
          '$key': _fieldMessage(value['code'], value['message']),
  };
  return switch (status) {
    400 || 422 when errors.isNotEmpty => ValidationException(
      status == 422 && message != null ? message : 'Проверьте выделенные поля.',
      errors,
    ),
    // 400 без ошибок по полям: чаще всего не прошло правило доступа
    // на создание записи.
    400 => ForbiddenException(
      message ??
          'Сервер отклонил запрос: недостаточно прав или неверные данные.',
    ),
    401 => UnauthorizedException(message ?? 'Требуется вход в систему.'),
    403 => ForbiddenException(
      message ?? 'Недостаточно прав для этого действия.',
    ),
    // PocketBase отвечает 404 и тогда, когда запись есть, но правило
    // доступа не разрешает её изменить.
    404 => NotFoundException(message ?? 'Запись не найдена.'),
    409 => ConflictException(message ?? 'Операция невозможна.'),
    422 => ValidationException(message ?? 'Ошибка валидации', errors),
    _ => ServerException(message ?? 'Неизвестная ошибка (код $status).'),
  };
}

const _messages = {
  'Failed to create record.':
      'Не удалось создать запись: недостаточно прав или неверные данные.',
  'Failed to update record.': 'Не удалось сохранить изменения.',
  'Failed to delete record.': 'Не удалось удалить запись.',
  'Failed to authenticate.': 'Неверный логин или пароль.',
  "The requested resource wasn't found.":
      'Запись не найдена или недоступна вашей роли.',
  'The request requires valid record authorization token.':
      'Требуется вход в систему.',
  'The request requires valid record authorization token to be set.':
      'Требуется вход в систему.',
  'The authorized record is not allowed to perform this action.':
      'Недостаточно прав для этого действия.',
  'Only superusers can perform this action.':
      'Недостаточно прав для этого действия.',
  'Something went wrong while processing your request.':
      'Ошибка на сервере. Попробуйте позже.',
};

String _translate(String message) => _messages[message] ?? message;

String _fieldMessage(Object? code, Object? message) => switch (code) {
  'validation_required' => 'Обязательное поле',
  'validation_not_unique' => 'Такое значение уже есть',
  'validation_invalid_email' => 'Неверный адрес e-mail',
  'validation_min_text_constraint' ||
  'validation_length_too_short' => 'Слишком короткое значение',
  'validation_max_text_constraint' ||
  'validation_length_too_long' => 'Слишком длинное значение',
  'validation_min_greater_equal_than_required' ||
  'validation_max_less_equal_than_required' =>
    'Значение вне допустимого диапазона',
  'validation_invalid_format' ||
  'validation_match_invalid' => 'Неверный формат',
  'validation_values_mismatch' => 'Значения не совпадают',
  'validation_missing_rel_records' => 'Связанная запись не найдена',
  'validation_not_one_of' ||
  'validation_invalid_value' => 'Недопустимое значение',
  _ => message is String ? message : 'Неверное значение',
};

ApiException mapDioError(DioException e) {
  // Если исключение уже разобрал интерсептор, повторно его не разбираем.
  // Без этой проверки ошибка 422 придёт в приложение как ServerException,
  // и обработчик `on ValidationException` никогда не сработает.
  final existing = e.error;
  if (existing is ApiException) return existing;

  return switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => const NetworkException(
      'Сервер не ответил вовремя.',
    ),
    DioExceptionType.connectionError => const NetworkException(
      'Не удалось соединиться с сервером. '
      'Если сервер запущен, откройте консоль браузера и проверьте наличие ошибки CORS.',
    ),
    DioExceptionType.cancel => const NetworkException('Запрос отменён.'),
    _ => const ServerException(),
  };
}

/// Не выпускает наружу DioException: в приложение попадают только
/// исключения предметной области.
Future<T> guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on DioException catch (e) {
    throw mapDioError(e);
  }
}
