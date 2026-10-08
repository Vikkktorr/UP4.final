/// Валидаторы полей форм.
///
/// Каждая функция возвращает валидатор — функцию, которая получает значение
/// поля и возвращает текст ошибки или null. Валидаторы собираются в цепочку
/// через [all]: срабатывает первая найденная ошибка. Так одна и та же
/// проверка («обязательно», «от 1 до 6») переиспользуется во всех формах —
/// аналог аннотаций @NotBlank, @Size, @Min в Spring.
library;

import 'formatting.dart';

typedef Validator = String? Function(String value);
typedef DateValidator = String? Function(DateTime? value);
typedef ListValidator = String? Function(List<String> value);
typedef ChoiceValidator = String? Function(Object? value);

/// Цепочка проверок: возвращает первую ошибку.
Validator all(List<Validator> validators) => (value) {
  for (final v in validators) {
    final error = v(value);
    if (error != null) return error;
  }
  return null;
};

/// Необязательное поле: пустое значение не проверяется дальше.
Validator optional(List<Validator> validators) =>
    (value) => value.trim().isEmpty ? null : all(validators)(value);

// ---- строки ----

Validator requiredText([String message = 'Обязательное поле']) =>
    (value) => value.trim().isEmpty ? message : null;

Validator minLength(int min) =>
    (value) => value.trim().length < min
    ? 'Не короче $min ${plural(min, 'символа', 'символов', 'символов')}'
    : null;

Validator maxLength(int max) =>
    (value) => value.trim().length > max
    ? 'Не длиннее $max ${plural(max, 'символа', 'символов', 'символов')}'
    : null;

Validator pattern(RegExp regExp, String message) =>
    (value) => regExp.hasMatch(value.trim()) ? null : message;

/// Фамилия, имя, отчество: буквы, пробел, дефис и апостроф.
Validator personName() => pattern(
  RegExp(r"^[A-Za-zА-Яа-яЁё][A-Za-zА-Яа-яЁё' -]*$"),
  'Только буквы, пробел и дефис',
);

Validator email() => pattern(
  RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)*\.[A-Za-z]{2,}$'),
  'Адрес вида name@example.ru',
);

/// Российский номер: 11 цифр, начинается с 7 или 8.
Validator phone() => (value) {
  final digits = digitsOnly(value);
  if (digits.length != 11 ||
      !(digits.startsWith('7') || digits.startsWith('8'))) {
    return 'Номер вида +7 (916) 123-45-67';
  }
  return null;
};

/// Госномер «А123ВС77» или «А123ВС777». Латинские двойники букв
/// допускаются — при сохранении они заменяются кириллицей.
Validator plate() => (value) {
  final normalized = normalizePlate(value);
  final ok = RegExp(
    r'^[АВЕКМНОРСТУХ]\d{3}[АВЕКМНОРСТУХ]{2}\d{2,3}$',
  ).hasMatch(normalized);
  return ok
      ? null
      : 'Формат А123ВС77: буквы А, В, Е, К, М, Н, О, Р, С, Т, У, Х';
};

/// VIN: 17 знаков, латиница и цифры, без I, O, Q.
Validator vin() => (value) {
  final v = value.trim().toUpperCase();
  if (v.length != 17) return 'VIN состоит из 17 знаков (сейчас ${v.length})';
  if (RegExp('[IOQ]').hasMatch(v)) return 'В VIN не бывает букв I, O и Q';
  if (!RegExp(r'^[A-Z0-9]+$').hasMatch(v)) return 'Только латиница и цифры';
  return null;
};

// ---- числа ----

/// Целое число в диапазоне. Пустое значение — ошибка «обязательно».
Validator intRange(int min, int max, {String? unit}) => (value) {
  final text = value.trim();
  if (text.isEmpty) return 'Обязательное поле';
  final n = int.tryParse(text);
  if (n == null) return 'Введите целое число';
  if (n < min || n > max) {
    return 'От $min до $max${unit == null ? '' : ' $unit'}';
  }
  return null;
};

/// Положительное количество: 1 и больше.
Validator positive({int max = 1000000000, String? unit}) => (value) {
  final n = int.tryParse(value.trim());
  if (value.trim().isEmpty) return 'Обязательное поле';
  if (n == null) return 'Введите целое число';
  if (n <= 0) return 'Должно быть больше нуля';
  if (n > max) return 'Не больше $max${unit == null ? '' : ' $unit'}';
  return null;
};

/// Неотрицательное количество: 0 и больше.
Validator nonNegative({int max = 1000000000}) => intRange(0, max);

/// Год выпуска: не раньше 1950 и не позже следующего года.
Validator year() => intRange(1950, DateTime.now().year + 1);

// ---- выбор из списка ----

ChoiceValidator requiredChoice(String message) =>
    (value) => value == null ? message : null;

ListValidator atLeastOne(String message) =>
    (value) => value.isEmpty ? message : null;

ListValidator atMost(int max, String noun) =>
    (value) => value.length > max ? 'Не больше $max $noun' : null;

ListValidator allList(List<ListValidator> validators) => (value) {
  for (final v in validators) {
    final error = v(value);
    if (error != null) return error;
  }
  return null;
};

// ---- даты ----

DateValidator requiredDate([String message = 'Укажите дату']) =>
    (value) => value == null ? message : null;

DateValidator notInFuture() => (value) {
  if (value == null) return 'Укажите дату';
  return value.isAfter(DateTime.now()) ? 'Дата не может быть в будущем' : null;
};

/// Дата позже другой — для перекрёстных проверок («окончание позже выдачи»).
DateValidator after(DateTime? other, String message) => (value) {
  if (value == null) return 'Укажите дату';
  if (other != null && !value.isAfter(other)) return message;
  return null;
};

// ---- вход и регистрация ----

/// Логин: латиница, цифры и подчёркивание — как требует сервер.
Validator username() => all([
  requiredText('Укажите логин'),
  pattern(
    RegExp(r'^[A-Za-z0-9_]{3,20}$'),
    'Латинские буквы, цифры и «_», от 3 до 20 знаков',
  ),
]);

/// Требования к паролю. Список показывается под полем и отмечается
/// по мере ввода; те же правила проверяет сервер.
final passwordRules = <({String label, bool Function(String) test})>[
  (label: 'не короче 8 символов', test: (v) => v.length >= 8),
  (label: 'хотя бы одна цифра', test: (v) => RegExp(r'\d').hasMatch(v)),
  (
    label: 'хотя бы один специальный символ (! # % @ …)',
    test: (v) => RegExp(r'[^A-Za-z0-9]').hasMatch(v),
  ),
];

Validator strongPassword() => (value) {
  if (value.isEmpty) return 'Придумайте пароль';
  for (final rule in passwordRules) {
    if (!rule.test(value)) return 'Пароль: ${rule.label}';
  }
  return null;
};
