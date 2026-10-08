/// Общее у всех записей: идентификатор, отметка логического удаления
/// и преобразование в JSON.
///
/// Идентификатор — строка PocketBase из 15 символов. Пустая строка у
/// новой, ещё не сохранённой записи. JSON совпадает с полями коллекции
/// PocketBase: тот же JSON уходит на сервер и разбирается из ответа.
abstract interface class Entity {
  String get id;
  DateTime? get deletedAt;
  bool get isDeleted;
  Map<String, dynamic> toJson();
}

/// Общее у всех объектов условий отбора — то, что нужно репозиторию,
/// чтобы вырезать страницу и учесть удалённые записи.
abstract interface class PagedQuery {
  int get page;
  int get size;
  bool get includeDeleted;
  String get sortField;
  bool get sortAscending;
}
