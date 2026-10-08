import '../models/appointment.dart';
import '../models/appointment_query.dart';
import 'entity_repository.dart';

/// Промежуток, когда мастер занят. Без подробностей: клиенту при записи
/// нужно только время.
typedef BusySlot = ({String id, DateTime start, DateTime end});

abstract interface class AppointmentRepository
    implements EntityRepository<Appointment, AppointmentQuery> {
  /// Записи мастера, пересекающие промежуток [from]–[to] (для календаря).
  Future<List<Appointment>> forMechanic(
    String mechanicId,
    DateTime from,
    DateTime to,
  );

  /// Занятость мастера в промежутке — доступна и клиенту.
  Future<List<BusySlot>> busy(String mechanicId, DateTime from, DateTime to);

  /// Записи автомобиля, сначала новые.
  Future<List<Appointment>> forCar(String carId);

  /// Отмена записи. Клиенту сервер разрешает только это изменение.
  Future<void> cancel(String id);
}
