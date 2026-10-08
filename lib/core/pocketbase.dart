/// Построение параметров запроса к PocketBase: фильтр и сортировка.
///
/// Фильтр PocketBase — выражение вида `year >= 2019 && model.brand = "id"`.
/// Строки в нём заключаются в двойные кавычки; значения из поля поиска
/// экранируются, чтобы кавычка во вводе не сломала выражение.
library;

/// Строковое значение для фильтра: `"Kia"`, кавычки и обратная косая черта
/// экранируются.
String pbString(String value) =>
    '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

/// Условия через «и»; пустые пропускаются.
String pbAnd(Iterable<String> conditions) {
  final parts = [
    for (final c in conditions)
      if (c.trim().isNotEmpty) c,
  ];
  if (parts.length == 1) return parts.single;
  return parts.map((c) => '($c)').join(' && ');
}

/// Поиск подстроки по нескольким полям.
///
/// Оператор `~` (LIKE в SQLite) не различает регистр только у латиницы:
/// по запросу «гро» «Громов» не найдётся. Поэтому для каждого поля
/// проверяется несколько написаний — как ввели, строчными, с заглавной
/// и прописными.
String pbSearch(List<String> fields, String text) {
  final q = text.trim();
  if (q.isEmpty) return '';
  final lower = q.toLowerCase();
  final variants = {
    q,
    lower,
    lower[0].toUpperCase() + lower.substring(1),
    q.toUpperCase(),
  };
  return [
    for (final field in fields)
      for (final v in variants) '$field ~ ${pbString(v)}',
  ].join(' || ');
}

/// Логически удалённые записи скрыты, если их не просили показать.
String pbNotDeleted(bool includeDeleted) =>
    includeDeleted ? '' : 'deleted_at = ""';

/// Сортировка PocketBase: `-year` — по убыванию. Вторым ключом идёт id,
/// чтобы порядок записей с одинаковым значением не менялся между страницами.
String pbSort(String field, bool ascending) =>
    '${ascending ? '' : '-'}$field,id';
