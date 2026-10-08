/// Тип двигателя. [code] — значение для адреса, [title] — для интерфейса.
enum FuelType {
  petrol('petrol', 'Бензин'),
  diesel('diesel', 'Дизель'),
  hybrid('hybrid', 'Гибрид'),
  electric('electric', 'Электро'),
  gas('gas', 'Газ/бензин');

  const FuelType(this.code, this.title);

  final String code;
  final String title;

  /// Неизвестный код из адреса даёт null, то есть «фильтр не задан».
  static FuelType? fromCode(Object? code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    return null;
  }
}
