import '../models/page_result.dart';

/// Состояние экрана списка.
///
/// Запечатанный класс: switch по нему компилятор проверяет на полноту,
/// а страница данных доступна только в состоянии, где она существует.
sealed class ListState<T> {
  const ListState();
}

/// Идёт загрузка. [previous] — прежняя страница: пока обновляется выборка,
/// таблица остаётся на экране, а не сменяется пустым индикатором.
final class ListLoading<T> extends ListState<T> {
  const ListLoading({this.previous});

  final PageResult<T>? previous;
}

/// Данные получены. Пустая страница — тоже успех, а не ошибка.
final class ListLoaded<T> extends ListState<T> {
  const ListLoaded(this.page);

  final PageResult<T> page;
}

final class ListFailed<T> extends ListState<T> {
  const ListFailed(this.message);

  final String message;
}
