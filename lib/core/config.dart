/// Адрес сервера задаётся только при сборке, в исходном коде адресов нет:
/// на занятии он один, дома другой, при публикации третий.
///
///   flutter run -d chrome --web-hostname 127.0.0.1 --dart-define=API_BASE_URL=http://127.0.0.1:8090
///   flutter build web --release --dart-define=API_BASE_URL=https://api.example.com
const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

/// Выход по неактивности: три минуты без действий пользователя.
/// Предупреждение показывается за [inactivityWarning] до выхода.
const inactivityTimeout = Duration(
  seconds: int.fromEnvironment('INACTIVITY_SECONDS', defaultValue: 180),
);
const inactivityWarning = Duration(seconds: 30);

/// Общая длительность сессии: по её истечении пользователь выходит
/// независимо от активности, даже если токен обновлялся.
const sessionMaxDuration = Duration(
  minutes: int.fromEnvironment('SESSION_MAX_MINUTES', defaultValue: 480),
);
