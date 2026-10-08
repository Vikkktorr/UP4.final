/// Рабочий график автосервиса и проверка занятости — те же правила, что
/// в серверном хуке. Окончательное решение принимает сервер: два клиента
/// могут выбрать одно и то же время одновременно.
class Schedule {
  const Schedule._();

  /// Рабочие часы: с 9:00 до 20:00.
  static const openHour = 9;
  static const closeHour = 20;

  /// Промежутки пересекаются, если один начинается раньше, чем кончается
  /// другой, и наоборот. Касание (одна запись кончается в 11:00, другая
  /// в 11:00 начинается) пересечением не считается.
  static bool overlaps(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) => aStart.isBefore(bEnd) && aEnd.isAfter(bStart);

  /// Укладываются ли работы в рабочий день.
  static bool withinHours(DateTime start, Duration duration) {
    final opens = DateTime(start.year, start.month, start.day, openHour);
    final closes = DateTime(start.year, start.month, start.day, closeHour);
    return !start.isBefore(opens) && !start.add(duration).isAfter(closes);
  }

  /// Понедельник недели, в которую попадает [date].
  static DateTime weekStart(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }
}
