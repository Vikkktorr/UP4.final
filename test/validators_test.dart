import 'package:autoservice_web/core/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Обязательное поле', () {
    test('пустая строка и одни пробелы отклоняются', () {
      expect(requiredText()(''), isNotNull);
      expect(requiredText()('   '), isNotNull);
    });

    test('непустая строка принимается', () {
      expect(requiredText()('Lada'), isNull);
    });
  });

  group('Госномер', () {
    test('номер с двух- и трёхзначным регионом принимается', () {
      expect(plate()('А123ВС77'), isNull);
      expect(plate()('А123ВС777'), isNull);
    });

    test('латинские двойники букв допускаются', () {
      expect(plate()('A123BC777'), isNull);
    });

    test('буква не из списка и неверный формат отклоняются', () {
      expect(plate()('Б123ВС77'), isNotNull);
      expect(plate()('123АВС77'), isNotNull);
    });
  });

  group('VIN', () {
    test('17 знаков без I, O, Q принимаются', () {
      expect(vin()('XTA219170K0123456'), isNull);
    });

    test('неверная длина и буквы I, O, Q отклоняются', () {
      expect(vin()('XTA219170'), contains('17 знаков'));
      expect(vin()('XTA219170K012345O'), contains('I, O и Q'));
    });
  });

  test('телефон: 11 цифр, начинается с 7 или 8', () {
    expect(phone()('+7 (916) 123-45-67'), isNull);
    expect(phone()('8 916 123 45 67'), isNull);
    expect(phone()('+7 916 123'), isNotNull);
    expect(phone()('+1 (916) 123-45-67'), isNotNull);
  });

  test('год выпуска: от 1950 до следующего года', () {
    final next = DateTime.now().year + 1;
    expect(year()('2019'), isNull);
    expect(year()('$next'), isNull);
    expect(year()('1949'), isNotNull);
    expect(year()('${next + 1}'), isNotNull);
    expect(year()('двадцать'), 'Введите целое число');
  });

  test('цепочка all возвращает первую ошибку', () {
    final v = all([requiredText('Пусто'), minLength(3)]);
    expect(v(''), 'Пусто');
    expect(v('ab'), startsWith('Не короче 3'));
    expect(v('abc'), isNull);
  });

  test('необязательное поле: пустое не проверяется дальше', () {
    final v = optional([email()]);
    expect(v(''), isNull);
    expect(v('s.ivanov@mail.ru'), isNull);
    expect(v('s.ivanov@'), isNotNull);
  });

  test('пароль: длина, цифра и специальный символ', () {
    expect(strongPassword()('Admin#2026'), isNull);
    expect(strongPassword()(''), 'Придумайте пароль');
    expect(strongPassword()('Ab#1'), contains('не короче 8'));
    expect(strongPassword()('Admin#adm'), contains('цифра'));
    expect(strongPassword()('Admin2026'), contains('специальный'));
  });
}
