import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/json.dart';
import '../../core/validators.dart';

/// Описание формы списком полей.
///
/// Экран конкретной сущности не строит виджеты сам: он перечисляет поля —
/// тип, подпись, валидатор, варианты выбора, — а разметку, проверку,
/// отправку и предупреждение о несохранённых изменениях берёт на себя
/// общий [EntityFormScreen].
///
/// Значения полей адресуются путём в JSON записи: `plate`, `brandId`,
/// `card.number`. Поэтому форма заполняется из `toJson()` и отдаёт JSON,
/// который превращается в модель через `fromJson()`.
sealed class FormItem {
  const FormItem();
}

/// Вложенная группа полей — так показывается связь «один к одному».
class FormGroup extends FormItem {
  const FormGroup({
    required this.title,
    required this.fields,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<FieldSpec> fields;
}

/// Вариант выбора для выпадающего списка или набора фишек.
class Option {
  const Option(this.value, this.label, {this.hint});

  final Object value;
  final String label;
  final String? hint;
}

sealed class FieldSpec extends FormItem {
  const FieldSpec({
    required this.path,
    required this.label,
    this.wide = false,
    this.helper,
  });

  /// Путь к значению в JSON записи.
  final String path;
  final String label;

  /// Во всю ширину формы, а не в половину.
  final bool wide;
  final String? helper;

  /// Значение из JSON → значение для поля формы.
  Object? toUi(Object? json);

  /// Значение поля формы → значение для JSON.
  Object? toJson(Object? ui);
}

enum TextKind {
  text,
  integer,

  /// Список строк, вводится через запятую: «Granta, Vesta, Largus».
  list,
}

class TextSpec extends FieldSpec {
  const TextSpec({
    required super.path,
    required super.label,
    this.kind = TextKind.text,
    this.validator,
    this.hint,
    this.maxLength,
    this.formatters = const [],
    this.keyboardType,
    this.capitalization = TextCapitalization.none,
    this.suffix,
    this.normalize,
    super.wide,
    super.helper,
  });

  final TextKind kind;
  final Validator? validator;
  final String? hint;
  final int? maxLength;
  final List<TextInputFormatter> formatters;
  final TextInputType? keyboardType;
  final TextCapitalization capitalization;
  final String? suffix;

  /// Приведение к хранимому виду при сохранении: госномер — кириллицей,
  /// VIN — в верхнем регистре.
  final String Function(String value)? normalize;

  @override
  Object? toUi(Object? json) => switch (json) {
    null => '',
    String s => s,
    List l => l.join(', '),
    _ => '$json',
  };

  @override
  Object? toJson(Object? ui) {
    final text = (ui as String? ?? '').trim();
    return switch (kind) {
      TextKind.integer => int.tryParse(text),
      TextKind.list => splitList(text),
      TextKind.text => normalize?.call(text) ?? text,
    };
  }
}

/// Выпадающий список — связь «многие к одному» или перечисление.
class ChoiceSpec extends FieldSpec {
  const ChoiceSpec({
    required super.path,
    required super.label,
    required this.options,
    this.validator,
    this.hint,
    super.wide,
    super.helper,
  });

  final List<Option> options;
  final ChoiceValidator? validator;
  final String? hint;

  @override
  Object? toUi(Object? json) => json;

  @override
  Object? toJson(Object? ui) => ui;
}

/// Множественный выбор фишками — связь «многие ко многим».
class MultiChoiceSpec extends FieldSpec {
  const MultiChoiceSpec({
    required super.path,
    required super.label,
    required this.options,
    this.validator,
    this.emptyText = 'Нет доступных вариантов',
    super.wide = true,
    super.helper,
  });

  final List<Option> options;
  final ListValidator? validator;
  final String emptyText;

  @override
  Object? toUi(Object? json) =>
      json is List ? json.whereType<String>().toList() : <String>[];

  @override
  Object? toJson(Object? ui) =>
      List<String>.of(ui as List<String>? ?? const []);
}

/// Дата без времени, выбирается календарём.
class DateSpec extends FieldSpec {
  const DateSpec({
    required super.path,
    required super.label,
    required this.firstDate,
    required this.lastDate,
    this.validator,
    super.wide,
    super.helper,
  });

  final DateTime firstDate;
  final DateTime lastDate;
  final DateValidator? validator;

  @override
  Object? toUi(Object? json) => switch (json) {
    DateTime d => d,
    String s => DateTime.tryParse(s),
    _ => null,
  };

  @override
  Object? toJson(Object? ui) => ui is DateTime ? dateToJson(ui) : null;
}

/// Все поля формы, включая вложенные в группы.
Iterable<FieldSpec> flattenFields(List<FormItem> items) sync* {
  for (final item in items) {
    switch (item) {
      case FieldSpec():
        yield item;
      case FormGroup(:final fields):
        yield* fields;
    }
  }
}

Object? readPath(Map<String, dynamic> json, String path) {
  Object? current = json;
  for (final part in path.split('.')) {
    if (current is! Map) return null;
    current = current[part];
  }
  return current;
}

void writePath(Map<String, dynamic> json, String path, Object? value) {
  final parts = path.split('.');
  var current = json;
  for (final part in parts.take(parts.length - 1)) {
    final next = current[part];
    final nested = next is Map
        ? {...next.cast<String, dynamic>()}
        : <String, dynamic>{};
    current[part] = nested;
    current = nested;
  }
  current[parts.last] = value;
}

/// «Granta, Vesta,, Granta» → [Granta, Vesta]: пустые и повторы убираются.
List<String> splitList(String text) => {
  for (final part in text.split(','))
    if (part.trim().isNotEmpty) part.trim(),
}.toList();
