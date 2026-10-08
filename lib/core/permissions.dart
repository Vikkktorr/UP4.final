import '../models/app_user.dart';

/// Операции приложения и минимальная роль для каждой.
///
/// Таблица повторяет правила доступа коллекций PocketBase
/// (pocketbase/pb_migrations/1_init.js) и нужна только интерфейсу: по ней
/// прячутся кнопки и закрываются маршруты. Настоящую проверку выполняет
/// сервер — подмена роли в браузере откроет кнопки, но операцию он отклонит.
enum Operation {
  /// Каталог услуг: просмотр
  viewCatalog(Role.client),

  /// «Мои автомобили» — личный экран клиента
  viewOwnCars(Role.client, only: true),

  /// Запись своего автомобиля к мастеру и отмена своей записи
  bookOwnCar(Role.client, only: true),

  /// «Мой график» — календарь занятости мастера
  viewOwnSchedule(Role.mechanic, only: true),

  /// Записи на обслуживание всех автомобилей: список, создание, статусы
  manageAppointments(Role.mechanic),

  /// Автомобили, клиенты, марки, мастера: просмотр
  viewWorkshop(Role.mechanic),

  /// Создание и изменение записей
  editRecords(Role.mechanic),

  /// Логическое удаление (в том числе нескольких записей сразу)
  softDelete(Role.mechanic),

  /// Восстановление удалённых записей (и переключатель их показа в списках)
  restore(Role.admin),

  /// Физическое удаление
  hardDelete(Role.admin),

  /// Пользователи и их роли
  manageUsers(Role.admin),

  /// Статистика
  viewStats(Role.admin);

  const Operation(this.minRole, {this.only = false});

  final Role minRole;

  /// Личный экран: доступен ровно одной роли, старшинство не учитывается.
  /// У администратора нет своих автомобилей, у клиента — работ.
  final bool only;
}

/// Разрешена ли операция роли. null — пользователь не вошёл.
bool isAllowed(Role? role, Operation operation) {
  if (role == null) return false;
  if (operation.only) return role == operation.minRole;
  return role.level >= operation.minRole.level;
}
