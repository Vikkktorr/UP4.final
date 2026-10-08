import '../core/json.dart';

/// Роли пользователей. Уровень задаёт старшинство: мастеру доступно всё,
/// что клиенту в каталоге, администратору — всё, что мастеру.
enum Role {
  client(1, 'Клиент'),
  mechanic(2, 'Мастер'),
  admin(3, 'Администратор');

  const Role(this.level, this.title);

  final int level;
  final String title;

  static Role fromName(String? name) =>
      Role.values.firstWhere((r) => r.name == name, orElse: () => Role.client);
}

/// Учётная запись из коллекции users PocketBase.
///
/// [clientId] и [mechanicId] связывают учётную запись с записью клиента
/// или мастера: по ним строятся экраны «Мои автомобили» и «Мой график».
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.role,
    required this.lastName,
    required this.firstName,
    this.clientId,
    this.mechanicId,
  });

  final String id;
  final String username;
  final Role role;
  final String lastName;
  final String firstName;
  final String? clientId;
  final String? mechanicId;

  String get fullName => '$lastName $firstName'.trim();

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: readId(json, 'id'),
    username: readString(json, 'username'),
    role: Role.fromName(json['role'] as String?),
    lastName: readString(json, 'last_name'),
    firstName: readString(json, 'first_name'),
    clientId: readIdOrNull(json, 'client'),
    mechanicId: readIdOrNull(json, 'mechanic'),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'role': role.name,
    'last_name': lastName,
    'first_name': firstName,
    'client': clientId ?? '',
    'mechanic': mechanicId ?? '',
  };
}
