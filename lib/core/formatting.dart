import 'package:intl/intl.dart';

final _thousands = NumberFormat.decimalPattern('ru');

/// 125000 → «125 000 км».
String formatMileage(int km) => '${_thousands.format(km)} км';

/// 12500 → «12 500 ₽».
String formatMoney(int rub) => '${_thousands.format(rub)} ₽';

/// 90 → «1 ч 30 мин».
String formatDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m мин';
  return m == 0 ? '$h ч' : '$h ч $m мин';
}

/// Дата без времени в привычном виде: 05.03.2024.
String formatDate(DateTime date) => DateFormat('dd.MM.yyyy').format(date);

/// «09:30»
String formatTime(DateTime date) => DateFormat('HH:mm').format(date);

/// «08.10.2026, 09:30»
String formatDateTime(DateTime date) =>
    '${formatDate(date)}, ${formatTime(date)}';

/// «ср, 8 окт.» — для заголовков дней календаря.
String formatDayShort(DateTime date) =>
    DateFormat('EEE, d MMM', 'ru').format(date);

/// Склонение существительного после числа: 1 автомобиль, 2 автомобиля,
/// 5 автомобилей.
String plural(int n, String one, String few, String many) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
  return many;
}

/// Латинские буквы, совпадающие по написанию с буквами госномера.
const _latinToCyrillic = {
  'A': 'А', 'B': 'В', 'E': 'Е', 'K': 'К', 'M': 'М', 'H': 'Н', //
  'O': 'О', 'P': 'Р', 'C': 'С', 'T': 'Т', 'Y': 'У', 'X': 'Х',
};

/// Приводит госномер к виду для сравнения: без пробелов, в верхнем регистре,
/// латинские буквы заменены кириллическими двойниками. Пользователь может
/// набрать «a123bc» на английской раскладке и всё равно найти «А123ВС77».
String normalizePlate(String value) {
  final upper = value.toUpperCase().replaceAll(RegExp(r'\s'), '');
  final buffer = StringBuffer();
  for (final ch in upper.split('')) {
    buffer.write(_latinToCyrillic[ch] ?? ch);
  }
  return buffer.toString();
}

/// Оставляет в строке только цифры: «+7 (916) 123-45-67» → «79161234567».
String digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');
