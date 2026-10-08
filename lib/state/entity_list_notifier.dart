import 'package:flutter/foundation.dart';

import '../models/page_result.dart';
import '../repositories/entity_repository.dart';
import 'list_state.dart';

/// Состояние списка любой сущности: условия отбора, текущая страница,
/// выделенные строки и операции удаления.
///
/// Экран автомобилей и экран клиентов отличаются только типами [T] и [Q],
/// поэтому логика написана один раз.
class EntityListNotifier<T, Q> extends ChangeNotifier {
  EntityListNotifier(
    this._repository,
    this._idOf,
    Q initialQuery, {
    Listenable? changes,
  }) : _query = initialQuery,
       _changes = changes {
    _changes?.addListener(_markStale);
  }

  /// Сигнал об изменении данных в хранилище (сохранение формы, удаление
  /// в другом разделе). Список помечается устаревшим и перечитывается
  /// при следующем показе.
  final Listenable? _changes;
  bool _stale = false;

  void _markStale() => _stale = true;

  final EntityRepository<T, Q> _repository;
  final String Function(T item) _idOf;

  Q _query;
  ListState<T> _state = const ListLoading();
  final Set<String> _selected = {};
  bool _loadedOnce = false;
  bool _disposed = false;

  /// Номер последнего запроса. Если пользователь быстро сменил условия,
  /// ответ на устаревший запрос может прийти позже нового — такой ответ
  /// отбрасывается.
  int _requestId = 0;

  Q get query => _query;
  ListState<T> get state => _state;
  Set<String> get selected => Set.unmodifiable(_selected);
  bool get hasSelection => _selected.isNotEmpty;

  /// Последняя полученная страница — в том числе во время перезагрузки.
  PageResult<T>? get page => switch (_state) {
    ListLoaded(:final page) => page,
    ListLoading(:final previous) => previous,
    ListFailed() => null,
  };

  Future<void> load() async {
    final requestId = ++_requestId;
    _stale = false;
    _state = ListLoading(previous: page);
    _notify();
    try {
      final result = await _repository.find(_query);
      if (requestId != _requestId) return;
      _state = ListLoaded(result);
      _loadedOnce = true;
    } catch (e) {
      if (requestId != _requestId) return;
      _state = ListFailed('Не удалось загрузить список: $e');
    }
    _notify();
  }

  Future<void> applyQuery(Q next) async {
    if (next == _query && _loadedOnce && !_stale && _state is! ListFailed<T>) {
      return;
    }
    if (next != _query) {
      _query = next;
      _selected.clear();
    }
    await load();
  }

  void toggleSelection(String id) {
    _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
    _notify();
  }

  /// Флажок в заголовке таблицы: выделить или снять все строки страницы.
  void setPageSelection(bool selected) {
    final ids = page?.items.map(_idOf) ?? const <String>[];
    selected ? _selected.addAll(ids) : _selected.removeAll(ids);
    _notify();
  }

  void clearSelection() {
    _selected.clear();
    _notify();
  }

  /// Ошибки операций пробрасываются вызывающему экрану — он покажет их
  /// во всплывающем сообщении, не ломая уже загруженный список.
  Future<int> deleteSelected() async {
    final count = await _repository.deleteMany(_selected.toList());
    _selected.clear();
    await load();
    return count;
  }

  Future<void> softDelete(String id) => _mutate(id, _repository.softDelete);

  Future<void> restore(String id) => _mutate(id, _repository.restore);

  Future<void> hardDelete(String id) => _mutate(id, _repository.hardDelete);

  Future<void> _mutate(String id, Future<void> Function(String) action) async {
    await action(id);
    _selected.remove(id);
    await load();
  }

  void _notify() {
    // Асинхронная операция могла завершиться после закрытия экрана.
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _changes?.removeListener(_markStale);
    super.dispose();
  }
}
