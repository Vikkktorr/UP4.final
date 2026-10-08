import '../models/page_result.dart';

/// Что приложение умеет делать с записями списка — безотносительно того,
/// где они хранятся.
///
/// [T] — модель, [Q] — объект условий отбора. Общий интерфейс позволяет
/// написать одно состояние списка на все сущности.
abstract interface class EntityRepository<T, Q> {
  Future<PageResult<T>> find(Q query);

  /// Все записи, включая удалённые, — для подписей и выпадающих списков.
  Future<List<T>> findAll();
  Future<T?> findById(String id);

  /// Ошибки проверки на сервере — [ValidationException] с ошибками по полям,
  /// нарушение ограничений целостности — [ConflictException].
  Future<T> create(T entity);
  Future<T> update(T entity);

  /// Логическое удаление: запись получает deletedAt и пропадает из выборки.
  Future<void> softDelete(String id);

  /// Физическое удаление: запись стирается насовсем.
  Future<void> hardDelete(String id);
  Future<void> restore(String id);

  /// Логически удаляет несколько записей, возвращает число удалённых.
  Future<int> deleteMany(List<String> ids);
}
