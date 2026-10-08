/// Связывает маршрутизатор с открытой формой.
///
/// PopScope перехватывает только «назад» внутри навигатора. Переход по
/// боковому меню или ссылке выполняется через context.go и PopScope не
/// спрашивает — для него у маршрута формы задан onExit, который
/// обращается сюда. Форма при открытии регистрирует проверку, при
/// закрытии снимает.
class LeaveGuard {
  Future<bool> Function()? _check;

  void register(Future<bool> Function() check) => _check = check;

  void unregister(Future<bool> Function() check) {
    if (identical(_check, check)) _check = null;
  }

  /// true — можно уходить: изменений нет или пользователь согласился
  /// их потерять.
  Future<bool> canLeave() async => await _check?.call() ?? true;
}
