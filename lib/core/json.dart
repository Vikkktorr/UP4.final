/// Разбор значений из JSON, который не роняет приложение.
///
/// Данные приходят из внешнего источника — с сервера. Поля может не быть, оно может оказаться null или прийти
/// другого типа: число строкой, целое как 12.0. Каждая функция в таком
/// случае возвращает запасное значение, а не бросает исключение.
library;

int readInt(Map<String, dynamic> json, String key, [int fallback = 0]) =>
    asInt(json[key]) ?? fallback;

int? readIntOrNull(Map<String, dynamic> json, String key) => asInt(json[key]);

int? asInt(Object? value) => switch (value) {
  int v => v,
  double v when v == v.roundToDouble() => v.toInt(),
  String v => int.tryParse(v.trim()),
  _ => null,
};

String readString(
  Map<String, dynamic> json,
  String key, [
  String fallback = '',
]) => switch (json[key]) {
  String v => v,
  num v => '$v',
  _ => fallback,
};

/// Список идентификаторов. Нечисловые элементы отбрасываются, повторы тоже.
List<int> readIntList(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw is! List) return const [];
  return raw.map(asInt).whereType<int>().toSet().toList();
}

/// Идентификаторы из списка развёрнутых объектов: `[{"id": 1, …}, …]`.
List<int> readIdsOf(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => asInt(e['id']))
      .whereType<int>()
      .toSet()
      .toList();
}

List<String> readStringList(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw is! List) return const [];
  return raw.whereType<String>().toList();
}

/// Дата PocketBase: «2026-10-08 10:00:00.000Z», пустая строка — нет даты.
/// Время приходит в UTC и переводится в местное.
DateTime? readDateOrNull(Map<String, dynamic> json, String key) =>
    switch (json[key]) {
      String v when v.isNotEmpty => DateTime.tryParse(v)?.toLocal(),
      _ => null,
    };

DateTime readDate(Map<String, dynamic> json, String key, DateTime fallback) =>
    readDateOrNull(json, key) ?? fallback;

/// Вложенный объект; если его нет или это не объект — пустой.
Map<String, dynamic> readMap(Map<String, dynamic> json, String key) {
  final raw = json[key];
  return raw is Map ? raw.cast<String, dynamic>() : const {};
}

/// Дата без времени — полночь по местному времени в формате PocketBase.
String dateToJson(DateTime date) =>
    dateTimeToJson(DateTime(date.year, date.month, date.day));

/// Момент времени в формате PocketBase (UTC): «2026-10-08 07:00:00.000Z».
String dateTimeToJson(DateTime date) =>
    date.toUtc().toIso8601String().replaceFirst('T', ' ');

/// Идентификатор записи PocketBase — строка из 15 символов. Пустая
/// строка — связь не задана.
String readId(Map<String, dynamic> json, String key) => switch (json[key]) {
  String v => v,
  _ => '',
};

String? readIdOrNull(Map<String, dynamic> json, String key) {
  final id = readId(json, key);
  return id.isEmpty ? null : id;
}

/// Связь «многие» — список идентификаторов, повторы отбрасываются.
List<String> readIds(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw is! List) return const [];
  return raw.whereType<String>().where((s) => s.isNotEmpty).toSet().toList();
}
