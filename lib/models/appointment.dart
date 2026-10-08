import '../core/json.dart';
import 'car.dart';
import 'entity.dart';

/// Состояние записи на обслуживание.
enum AppointmentStatus {
  planned('planned', 'Запланирована'),
  inProgress('in_progress', 'В работе'),
  done('done', 'Выполнена'),
  cancelled('cancelled', 'Отменена');

  const AppointmentStatus(this.code, this.title);

  final String code;
  final String title;

  static AppointmentStatus? fromCode(Object? code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return null;
  }
}

/// Откуда взялась скидка.
enum DiscountSource {
  none('none', 'без скидки'),
  card('card', 'по клубной карте'),
  personal('personal', 'персональная');

  const DiscountSource(this.code, this.title);

  final String code;
  final String title;

  static DiscountSource fromCode(Object? code) => values.firstWhere(
    (s) => s.code == code,
    orElse: () => DiscountSource.none,
  );
}

/// Запись автомобиля на обслуживание к мастеру.
///
/// Связи: автомобиль и мастер — многие к одному, услуги — многие ко
/// многим. Окончание и стоимость считает сервер: окончание — по нормам
/// времени услуг, стоимость — с учётом скидки клиента.
class Appointment implements Entity {
  @override
  final String id;
  final String carId;
  final String mechanicId;
  final List<String> serviceIds;
  final DateTime startsAt;
  final DateTime? endsAt;
  final AppointmentStatus status;

  /// Сумма цен услуг, ₽.
  final int subtotal;
  final int discountPercent;
  final DiscountSource discountSource;

  /// К оплате, ₽.
  final int total;
  final String comment;
  @override
  final DateTime? deletedAt;

  /// Автомобиль целиком — PocketBase разворачивает связь (expand=car),
  /// чтобы в списке был виден госномер без отдельного запроса.
  final Car? car;

  const Appointment({
    required this.id,
    required this.carId,
    required this.mechanicId,
    required this.serviceIds,
    required this.startsAt,
    this.endsAt,
    this.status = AppointmentStatus.planned,
    this.subtotal = 0,
    this.discountPercent = 0,
    this.discountSource = DiscountSource.none,
    this.total = 0,
    this.comment = '',
    this.deletedAt,
    this.car,
  });

  /// Продолжительность работ.
  Duration get duration => (endsAt ?? startsAt).difference(startsAt);

  @override
  bool get isDeleted => deletedAt != null;

  bool get isActive => status != AppointmentStatus.cancelled && !isDeleted;

  /// Расчётные поля (окончание, суммы) не отправляются: их считает сервер.
  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'car': carId,
    'mechanic': mechanicId,
    'services': serviceIds,
    'starts_at': dateTimeToJson(startsAt),
    'status': status.code,
    'comment': comment,
    'deleted_at': deletedAt == null ? '' : dateTimeToJson(deletedAt!),
  };

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
    id: readId(json, 'id'),
    carId: readId(json, 'car'),
    mechanicId: readId(json, 'mechanic'),
    serviceIds: readIds(json, 'services'),
    startsAt: readDate(json, 'starts_at', DateTime(2000)),
    endsAt: readDateOrNull(json, 'ends_at'),
    status:
        AppointmentStatus.fromCode(json['status']) ?? AppointmentStatus.planned,
    subtotal: readInt(json, 'subtotal'),
    discountPercent: readInt(json, 'discount_percent'),
    discountSource: DiscountSource.fromCode(json['discount_source']),
    total: readInt(json, 'total'),
    comment: readString(json, 'comment'),
    deletedAt: readDateOrNull(json, 'deleted_at'),
    car: switch (readMap(json, 'expand')['car']) {
      Map car => Car.fromJson(car.cast<String, dynamic>()),
      _ => null,
    },
  );
}
