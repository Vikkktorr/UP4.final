import '../core/api_exceptions.dart';
import '../core/json.dart';
import '../core/pocketbase.dart';
import '../models/appointment.dart';
import '../models/appointment_query.dart';
import 'api_repository.dart';
import 'appointment_repository.dart';

class ApiAppointmentRepository
    extends ApiRepository<Appointment, AppointmentQuery>
    implements AppointmentRepository {
  ApiAppointmentRepository(super.dio, {required super.changes})
    : super(collection: 'appointments', expand: 'car');

  @override
  Appointment fromJson(Map<String, dynamic> json) => Appointment.fromJson(json);

  @override
  String filterOf(AppointmentQuery q) => pbAnd([
    pbSearch(['car.plate'], q.search),
    if (q.status != null) 'status = ${pbString(q.status!.code)}',
    if (q.mechanicId != null) 'mechanic = ${pbString(q.mechanicId!)}',
    if (q.carId != null) 'car = ${pbString(q.carId!)}',
    if (q.from != null) 'starts_at >= ${pbString(dateTimeToJson(q.from!))}',
    if (q.to != null)
      'starts_at < ${pbString(dateTimeToJson(q.to!.add(const Duration(days: 1))))}',
  ]);

  @override
  String sortFieldOf(String field) => switch (field) {
    'starts' => 'starts_at',
    _ => field,
  };

  /// Пересекает промежуток: начинается раньше его конца и кончается
  /// позже его начала.
  String _overlaps(DateTime from, DateTime to) => pbAnd([
    'starts_at < ${pbString(dateTimeToJson(to))}',
    'ends_at > ${pbString(dateTimeToJson(from))}',
  ]);

  @override
  Future<List<Appointment>> forMechanic(
    String mechanicId,
    DateTime from,
    DateTime to,
  ) async => (await findWhere(
    pbAnd([
      'mechanic = ${pbString(mechanicId)}',
      'deleted_at = ""',
      _overlaps(from, to),
    ]),
    sort: 'starts_at',
    limit: 200,
  )).items;

  @override
  Future<List<BusySlot>> busy(String mechanicId, DateTime from, DateTime to) =>
      guard(() async {
        final response = await dio.get<Map<String, dynamic>>(
          '/api/collections/mechanic_busy/records',
          queryParameters: {
            'perPage': 200,
            'sort': 'starts_at',
            'filter': pbAnd([
              'mechanic = ${pbString(mechanicId)}',
              _overlaps(from, to),
            ]),
          },
        );
        return [
          for (final json
              in (response.data!['items'] as List).cast<Map<String, dynamic>>())
            (
              id: readId(json, 'id'),
              start: readDate(json, 'starts_at', from),
              end: readDate(json, 'ends_at', from),
            ),
        ];
      });

  @override
  Future<List<Appointment>> forCar(String carId) async => (await findWhere(
    pbAnd(['car = ${pbString(carId)}', 'deleted_at = ""']),
    sort: '-starts_at',
    limit: 100,
  )).items;

  @override
  Future<void> cancel(String id) => write(
    () => dio.patch<void>(
      '$path/$id',
      data: {'status': AppointmentStatus.cancelled.code},
    ),
  );
}
