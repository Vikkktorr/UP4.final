import '../core/json.dart';
import 'entity.dart';

/// Мастер автосервиса. Автомобили ↔ мастера — многие ко многим
/// (закреплённые мастера); мастер → записи на обслуживание — один ко многим.
class Mechanic implements Entity {
  @override
  final String id;
  final String lastName;
  final String firstName;
  final String middleName;
  final String phone;

  /// Квалификационный разряд, 1–6.
  final int grade;

  /// Стаж в годах.
  final int experience;
  final DateTime hiredAt;
  @override
  final DateTime? deletedAt;

  const Mechanic({
    required this.id,
    required this.lastName,
    required this.firstName,
    this.middleName = '',
    required this.phone,
    required this.grade,
    required this.experience,
    required this.hiredAt,
    this.deletedAt,
  });

  @override
  bool get isDeleted => deletedAt != null;

  String get fullName =>
      [lastName, firstName, middleName].where((s) => s.isNotEmpty).join(' ');

  /// «Громов В. А.» — для колонок таблицы и выпадающих списков.
  String get shortName => shortPersonName(lastName, firstName, middleName);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'last_name': lastName,
    'first_name': firstName,
    'middle_name': middleName,
    'phone': phone,
    'grade': grade,
    'experience': experience,
    'hired_at': dateToJson(hiredAt),
    'deleted_at': deletedAt == null ? '' : dateTimeToJson(deletedAt!),
  };

  factory Mechanic.fromJson(Map<String, dynamic> json) => Mechanic(
    id: readId(json, 'id'),
    lastName: readString(json, 'last_name'),
    firstName: readString(json, 'first_name'),
    middleName: readString(json, 'middle_name'),
    phone: readString(json, 'phone'),
    grade: readInt(json, 'grade', 1),
    experience: readInt(json, 'experience'),
    hiredAt: readDate(json, 'hired_at', DateTime(2000)),
    deletedAt: readDateOrNull(json, 'deleted_at'),
  );
}

/// «Иванов С. П.»
String shortPersonName(String lastName, String firstName, String middleName) {
  final initials = [
    firstName,
    middleName,
  ].where((s) => s.isNotEmpty).map((s) => '${s[0]}.').join(' ');
  return initials.isEmpty ? lastName : '$lastName $initials';
}
