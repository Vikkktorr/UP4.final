import 'package:flutter/foundation.dart';

/// Переключатели меню отладки.
///
/// Включённый флаг действует на каждый запрос: «ошибка» — запрос не уходит
/// на сервер, а получает ответ 500; «задержка» — запрос уходит на полторы
/// секунды позже. Так экраны ошибки и загрузки проверяются без правки кода
/// и без вмешательства в базу.
class NetworkSimulator extends ChangeNotifier {
  bool _failing = false;
  bool _slow = false;

  bool get failing => _failing;

  bool get slow => _slow;

  set slow(bool value) {
    if (_slow == value) return;
    _slow = value;
    notifyListeners();
  }

  set failing(bool value) {
    if (_failing == value) return;
    _failing = value;
    notifyListeners();
  }

  /// Состояние для интерсептора Dio.
  ({bool failing, bool slow}) get state => (failing: _failing, slow: _slow);
}
