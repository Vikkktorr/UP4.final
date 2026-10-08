import 'package:flutter/cupertino.dart' show CupertinoLocalizations;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_custom.dart';
import 'package:intl/date_symbols.dart' as intl;
import 'package:intl/intl.dart' as intl;

/// Подписи стандартных виджетов (подсказки, диалоги, выбор даты) только
/// на русском.
///
/// GlobalMaterialLocalizations.delegates подключает переводы и форматы
/// дат всех ~80 языков, которые поддерживает Flutter: это около 480 КБ
/// в main.dart.js, хотя приложению нужен один русский. Здесь берутся
/// готовые русские тексты (MaterialLocalizationRu из flutter_localizations)
/// и форматы дат одного языка.
const ruLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  _RuMaterialLocalizationsDelegate(),
  _RuCupertinoLocalizationsDelegate(),
  GlobalWidgetsLocalizations.delegate,
];

/// Форматы дат intl знают только en_US, пока не загружен другой язык.
/// После загрузки русский становится языком intl по умолчанию: форматы
/// без явного языка (DateFormat('dd.MM.yyyy')) тоже берут его.
bool _ruDatesReady = false;

void _ensureRuDates() {
  if (_ruDatesReady) return;
  initializeDateFormattingCustom(
    locale: 'ru',
    symbols: _ruDateSymbols,
    patterns: _ruDatePatterns,
  );
  intl.Intl.defaultLocale = 'ru';
  _ruDatesReady = true;
}

class _RuMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _RuMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ru';

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    _ensureRuDates();
    return SynchronousFuture(
      MaterialLocalizationRu(
        fullYearFormat: intl.DateFormat.y('ru'),
        compactDateFormat: intl.DateFormat.yMd('ru'),
        shortDateFormat: intl.DateFormat.yMMMd('ru'),
        mediumDateFormat: intl.DateFormat.MMMEd('ru'),
        longDateFormat: intl.DateFormat.yMMMMEEEEd('ru'),
        yearMonthFormat: intl.DateFormat.yMMMM('ru'),
        shortMonthDayFormat: intl.DateFormat.MMMd('ru'),
        decimalFormat: intl.NumberFormat.decimalPattern('ru'),
        twoDigitZeroPaddedFormat: intl.NumberFormat('00', 'ru'),
      ),
    );
  }

  @override
  bool shouldReload(_RuMaterialLocalizationsDelegate old) => false;
}

/// Тексты Cupertino-виджетов: Flutter требует их для каждого языка
/// приложения, даже если такие виджеты не используются напрямую.
class _RuCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _RuCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ru';

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    _ensureRuDates();
    return SynchronousFuture(
      CupertinoLocalizationRu(
        fullYearFormat: intl.DateFormat.y('ru'),
        dayFormat: intl.DateFormat.d('ru'),
        weekdayFormat: intl.DateFormat.E('ru'),
        mediumDateFormat: intl.DateFormat.MMMEd('ru'),
        singleDigitHourFormat: intl.DateFormat('HH', 'ru'),
        singleDigitMinuteFormat: intl.DateFormat.m('ru'),
        doubleDigitMinuteFormat: intl.DateFormat('mm', 'ru'),
        singleDigitSecondFormat: intl.DateFormat.s('ru'),
        decimalFormat: intl.NumberFormat.decimalPattern('ru'),
      ),
    );
  }

  @override
  bool shouldReload(_RuCupertinoLocalizationsDelegate old) => false;
}

// Данные русского языка — из generated_date_localizations.dart пакета
// flutter_localizations.
final _ruDateSymbols = intl.DateSymbols(
  NAME: 'ru',
  ERAS: const <String>['до н. э.', 'н. э.'],
  ERANAMES: const <String>['до Рождества Христова', 'от Рождества Христова'],
  NARROWMONTHS: const <String>[
    'Я',
    'Ф',
    'М',
    'А',
    'М',
    'И',
    'И',
    'А',
    'С',
    'О',
    'Н',
    'Д',
  ],
  STANDALONENARROWMONTHS: const <String>[
    'Я',
    'Ф',
    'М',
    'А',
    'М',
    'И',
    'И',
    'А',
    'С',
    'О',
    'Н',
    'Д',
  ],
  MONTHS: const <String>[
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ],
  STANDALONEMONTHS: const <String>[
    'январь',
    'февраль',
    'март',
    'апрель',
    'май',
    'июнь',
    'июль',
    'август',
    'сентябрь',
    'октябрь',
    'ноябрь',
    'декабрь',
  ],
  SHORTMONTHS: const <String>[
    'янв.',
    'февр.',
    'мар.',
    'апр.',
    'мая',
    'июн.',
    'июл.',
    'авг.',
    'сент.',
    'окт.',
    'нояб.',
    'дек.',
  ],
  STANDALONESHORTMONTHS: const <String>[
    'янв.',
    'февр.',
    'март',
    'апр.',
    'май',
    'июнь',
    'июль',
    'авг.',
    'сент.',
    'окт.',
    'нояб.',
    'дек.',
  ],
  WEEKDAYS: const <String>[
    'воскресенье',
    'понедельник',
    'вторник',
    'среда',
    'четверг',
    'пятница',
    'суббота',
  ],
  STANDALONEWEEKDAYS: const <String>[
    'воскресенье',
    'понедельник',
    'вторник',
    'среда',
    'четверг',
    'пятница',
    'суббота',
  ],
  SHORTWEEKDAYS: const <String>['вс', 'пн', 'вт', 'ср', 'чт', 'пт', 'сб'],
  STANDALONESHORTWEEKDAYS: const <String>[
    'вс',
    'пн',
    'вт',
    'ср',
    'чт',
    'пт',
    'сб',
  ],
  NARROWWEEKDAYS: const <String>['В', 'П', 'В', 'С', 'Ч', 'П', 'С'],
  STANDALONENARROWWEEKDAYS: const <String>['В', 'П', 'В', 'С', 'Ч', 'П', 'С'],
  SHORTQUARTERS: const <String>['1-й кв.', '2-й кв.', '3-й кв.', '4-й кв.'],
  QUARTERS: const <String>[
    '1-й квартал',
    '2-й квартал',
    '3-й квартал',
    '4-й квартал',
  ],
  AMPMS: const <String>['AM', 'PM'],
  DATEFORMATS: const <String>[
    "EEEE, d MMMM y 'г'.",
    "d MMMM y 'г'.",
    "d MMM y 'г'.",
    'dd.MM.y',
  ],
  TIMEFORMATS: const <String>[
    'HH:mm:ss zzzz',
    'HH:mm:ss z',
    'HH:mm:ss',
    'HH:mm',
  ],
  FIRSTDAYOFWEEK: 0,
  WEEKENDRANGE: const <int>[5, 6],
  FIRSTWEEKCUTOFFDAY: 3,
  DATETIMEFORMATS: const <String>[
    '{1}, {0}',
    '{1}, {0}',
    '{1}, {0}',
    '{1}, {0}',
  ],
);

const _ruDatePatterns = <String, String>{
  'd': 'd',
  'E': 'ccc',
  'EEEE': 'cccc',
  'LLL': 'LLL',
  'LLLL': 'LLLL',
  'M': 'L',
  'Md': 'dd.MM',
  'MEd': 'EEE, dd.MM',
  'MMM': 'LLL',
  'MMMd': 'd MMM',
  'MMMEd': 'ccc, d MMM',
  'MMMM': 'LLLL',
  'MMMMd': 'd MMMM',
  'MMMMEEEEd': 'cccc, d MMMM',
  'QQQ': 'QQQ',
  'QQQQ': 'QQQQ',
  'y': 'y',
  'yM': 'MM.y',
  'yMd': 'dd.MM.y',
  'yMEd': "ccc, dd.MM.y 'г'.",
  'yMMM': "LLL y 'г'.",
  'yMMMd': "d MMM y 'г'.",
  'yMMMEd': "EEE, d MMM y 'г'.",
  'yMMMM': "LLLL y 'г'.",
  'yMMMMd': "d MMMM y 'г'.",
  'yMMMMEEEEd': "EEEE, d MMMM y 'г'.",
  'yQQQ': "QQQ y 'г'.",
  'yQQQQ': "QQQQ y 'г'.",
  'H': 'HH',
  'Hm': 'HH:mm',
  'Hms': 'HH:mm:ss',
  'j': 'HH',
  'jm': 'HH:mm',
  'jms': 'HH:mm:ss',
  'jmv': 'HH:mm v',
  'jmz': 'HH:mm z',
  'jz': 'HH z',
  'm': 'm',
  'ms': 'mm:ss',
  's': 's',
  'v': 'v',
  'z': 'z',
  'zzzz': 'zzzz',
  'ZZZZ': 'ZZZZ',
};
