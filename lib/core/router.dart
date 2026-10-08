import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/appointment.dart';
import '../models/appointment_query.dart';
import '../models/brand.dart';
import '../models/car.dart';
import '../models/car_query.dart';
import '../models/client.dart';
import '../models/client_query.dart';
import '../models/entity_query.dart';
import '../models/mechanic.dart';
import '../models/service_category.dart';
import '../models/service_item.dart';
import '../models/with_cars.dart';
import '../repositories/appointment_repository.dart';
import '../repositories/brand_repository.dart';
import '../repositories/car_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/client_repository.dart';
import '../repositories/data_changes.dart';
import '../repositories/mechanic_repository.dart';
import '../repositories/service_repository.dart';
import '../screens/admin/stats_screen.dart' deferred as stats;
import '../screens/admin/users_screen.dart' deferred as users;
import '../screens/appointment_screens.dart';
import '../screens/auth/forbidden_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart' deferred as register;
import '../screens/car_detail_screen.dart';
import '../screens/car_list_screen.dart';
import '../screens/client_detail_screen.dart';
import '../screens/client_list_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/forms/appointment_form_screen.dart'
    deferred as appointment_form;
import '../screens/forms/car_form_screen.dart' deferred as car_form;
import '../screens/forms/client_form_screen.dart' deferred as client_form;
import '../screens/forms/reference_form_screens.dart'
    deferred as reference_forms;
import '../screens/my_cars_screen.dart';
import '../screens/not_found_screen.dart';
import '../screens/reference_screens.dart';
import '../screens/schedule_screen.dart';
import '../state/auth_notifier.dart';
import '../state/detail_notifier.dart';
import '../widgets/app_shell.dart';
import '../widgets/deferred_screen.dart';
import '../widgets/entity_form/leave_guard.dart';
import 'permissions.dart';
import 'query_params.dart';

/// Маршруты приложения. Формы, регистрация, пользователи и статистика
/// подключены через deferred: их код скачивается при первом открытии.
///
/// У каждой сущности одинаковый набор:
///
///   /cars            список
///   /cars/new        форма создания
///   /cars/:id        карточка
///   /cars/:id/edit   форма изменения — тот же экран, что и создание
///
/// Доступ проверяется в redirect: общий — «вошёл ли пользователь»,
/// у веток — «разрешено ли его роли». Это удобство интерфейса, а не
/// защита: настоящую проверку выполняют правила PocketBase.
GoRouter createRouter({
  required AuthNotifier auth,
  String initialLocation = '/',
  required LeaveGuard guard,
}) {
  // Проверка роли на уровне ветки маршрутов: чужой адрес, открытый
  // вручную, ведёт на экран отказа.
  GoRouterRedirect allow(Operation operation) =>
      (context, state) => auth.can(operation) ? null : '/forbidden';

  // Уход с формы (боковое меню, ссылка, кнопка «назад» браузера)
  // сначала спрашивает форму, нет ли несохранённых изменений.
  Future<bool> onExit(BuildContext context, GoRouterState state) =>
      guard.canLeave();

  String idOf(GoRouterState state) => state.pathParameters['id']!;

  List<RouteBase> entityRoutes({
    required Widget Function(GoRouterState state) form,
    required Widget Function(String id) edit,
    required Widget Function(BuildContext context, String id) detail,
  }) => [
    // «new» объявлен раньше «:id», иначе адрес /cars/new разобрался бы
    // как карточка с идентификатором «new».
    GoRoute(
      path: 'new',
      onExit: onExit,
      redirect: allow(Operation.editRecords),
      builder: (context, state) => form(state),
    ),
    GoRoute(
      path: ':id',
      builder: (context, state) => detail(context, idOf(state)),
      routes: [
        GoRoute(
          path: 'edit',
          onExit: onExit,
          redirect: allow(Operation.editRecords),
          // Ключ по id: при переходе с одной формы на другую экран
          // создаётся заново и загружает свою запись.
          builder: (context, state) => KeyedSubtree(
            key: ValueKey('edit-${idOf(state)}'),
            child: edit(idOf(state)),
          ),
        ),
      ],
    ),
  ];

  Widget appointmentForm({
    String? id,
    String? carId,
    String? mechanicId,
    required String back,
  }) => DeferredScreen(
    load: appointment_form.loadLibrary,
    build: () => appointment_form.AppointmentFormScreen(
      id: id,
      carId: carId,
      mechanicId: mechanicId,
      backLocation: back,
    ),
  );

  return GoRouter(
    initialLocation: initialLocation,
    // Маршрутизатор пересчитает redirect при каждом notifyListeners():
    // после входа уйдёт с формы входа, после выхода — на неё.
    refreshListenable: auth,
    errorBuilder: (context, state) =>
        NotFoundScreen(location: state.uri.toString()),
    redirect: (context, state) {
      final loggedIn = auth.isAuthenticated;
      final target = state.matchedLocation;
      final isPublic = target == '/login' || target == '/register';

      // Не вошёл и идёт на закрытый экран — на вход,
      // запомнив адрес, куда он хотел попасть
      if (!loggedIn && !isPublic) {
        final from = state.uri.toString();
        return from == '/'
            ? '/login'
            : '/login?from=${Uri.encodeComponent(from)}';
      }

      // Уже вошёл и идёт на экран входа — туда, откуда его отправили
      // на вход, либо на главную
      if (loggedIn && isPublic) {
        final from = state.uri.queryParameters['from'];
        return from != null && from.startsWith('/') ? from : '/';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => DeferredScreen(
          load: register.loadLibrary,
          build: () => register.RegisterScreen(),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/forbidden',
            builder: (context, state) => const ForbiddenScreen(),
          ),
          // Личный экран клиента: свои автомобили, записи, запись к мастеру.
          GoRoute(
            path: '/my',
            redirect: allow(Operation.bookOwnCar),
            builder: (context, state) => auth.user == null
                ? const SizedBox.shrink()
                : MyCarsScreen(user: auth.user!),
            routes: [
              GoRoute(
                path: 'book',
                onExit: onExit,
                builder: (context, state) => appointmentForm(
                  carId: parseIdParam(state.uri.queryParameters['car']),
                  back: '/my',
                ),
              ),
              GoRoute(
                path: 'appointments/:id',
                builder: (context, state) => _appointmentDetail(
                  context,
                  idOf(state),
                  backLocation: '/my',
                ),
              ),
            ],
          ),
          // Личный экран мастера: календарь записей на неделю.
          GoRoute(
            path: '/work',
            redirect: allow(Operation.viewOwnSchedule),
            builder: (context, state) => auth.user?.mechanicId == null
                ? const ScheduleUnlinked()
                : ScheduleScreen(
                    mechanicId: auth.user!.mechanicId!,
                    week: parseDateParam(state.uri.queryParameters['week']),
                  ),
          ),
          GoRoute(
            path: '/admin/users',
            redirect: allow(Operation.manageUsers),
            builder: (context, state) => DeferredScreen(
              load: users.loadLibrary,
              build: () => users.UsersScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/stats',
            redirect: allow(Operation.viewStats),
            builder: (context, state) => DeferredScreen(
              load: stats.loadLibrary,
              build: () => stats.StatsScreen(),
            ),
          ),
          GoRoute(
            path: '/appointments',
            redirect: allow(Operation.manageAppointments),
            builder: (context, state) => AppointmentListScreen(
              query: AppointmentQuery.fromQueryParameters(
                state.uri.queryParameters,
              ),
            ),
            routes: [
              GoRoute(
                path: 'new',
                onExit: onExit,
                builder: (context, state) => appointmentForm(
                  carId: parseIdParam(state.uri.queryParameters['car']),
                  mechanicId: parseIdParam(
                    state.uri.queryParameters['mechanic'],
                  ),
                  back: '/appointments',
                ),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => _appointmentDetail(
                  context,
                  idOf(state),
                  backLocation: '/appointments',
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    onExit: onExit,
                    builder: (context, state) => KeyedSubtree(
                      key: ValueKey('appointment-edit-${idOf(state)}'),
                      child: appointmentForm(
                        id: idOf(state),
                        back: '/appointments/${idOf(state)}',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/cars',
            redirect: allow(Operation.viewWorkshop),
            // Условия отбора берутся из адреса — аналог @RequestParam.
            builder: (context, state) => CarListScreen(
              query: CarQuery.fromQueryParameters(state.uri.queryParameters),
            ),
            routes: entityRoutes(
              form: (_) => DeferredScreen(
                load: car_form.loadLibrary,
                build: () => car_form.CarFormScreen(),
              ),
              edit: (id) => DeferredScreen(
                load: car_form.loadLibrary,
                build: () => car_form.CarFormScreen(id: id),
              ),
              detail: (context, id) => _detail<Car>(
                'car-$id',
                context,
                () => context.read<CarRepository>().findById(id),
                CarDetailScreen(id: id),
              ),
            ),
          ),
          GoRoute(
            path: '/clients',
            redirect: allow(Operation.viewWorkshop),
            builder: (context, state) => ClientListScreen(
              query: ClientQuery.fromQueryParameters(state.uri.queryParameters),
            ),
            routes: entityRoutes(
              form: (_) => DeferredScreen(
                load: client_form.loadLibrary,
                build: () => client_form.ClientFormScreen(),
              ),
              edit: (id) => DeferredScreen(
                load: client_form.loadLibrary,
                build: () => client_form.ClientFormScreen(id: id),
              ),
              detail: (context, id) => _detail<WithCars<Client>>(
                'client-$id',
                context,
                () => _withCars(
                  context,
                  context.read<ClientRepository>().findById(id),
                  CarQuery(clientId: id, size: 50),
                ),
                ClientDetailScreen(id: id),
              ),
            ),
          ),
          GoRoute(
            path: '/brands',
            redirect: allow(Operation.viewWorkshop),
            builder: (context, state) => BrandListScreen(
              query: EntityQuery.fromQueryParameters(
                Queries.brands,
                state.uri.queryParameters,
              ),
            ),
            routes: entityRoutes(
              form: (_) => DeferredScreen(
                load: reference_forms.loadLibrary,
                build: () => reference_forms.BrandFormScreen(),
              ),
              edit: (id) => DeferredScreen(
                load: reference_forms.loadLibrary,
                build: () => reference_forms.BrandFormScreen(id: id),
              ),
              detail: (context, id) => _detail<WithCars<Brand>>(
                'brand-$id',
                context,
                () => _withCars(
                  context,
                  context.read<BrandRepository>().findById(id),
                  CarQuery(brandId: id, size: 20),
                ),
                BrandDetailScreen(id: id),
              ),
            ),
          ),
          GoRoute(
            path: '/categories',
            redirect: allow(Operation.viewWorkshop),
            builder: (context, state) => CategoryListScreen(
              query: EntityQuery.fromQueryParameters(
                Queries.categories,
                state.uri.queryParameters,
              ),
            ),
            routes: entityRoutes(
              form: (_) => DeferredScreen(
                load: reference_forms.loadLibrary,
                build: () => reference_forms.CategoryFormScreen(),
              ),
              edit: (id) => DeferredScreen(
                load: reference_forms.loadLibrary,
                build: () => reference_forms.CategoryFormScreen(id: id),
              ),
              detail: (context, id) => _detail<WithCars<ServiceCategory>>(
                'category-$id',
                context,
                () => _withCars(
                  context,
                  context.read<CategoryRepository>().findById(id),
                  null,
                ),
                CategoryDetailScreen(id: id),
              ),
            ),
          ),
          GoRoute(
            path: '/mechanics',
            redirect: allow(Operation.viewWorkshop),
            builder: (context, state) => MechanicListScreen(
              query: EntityQuery.fromQueryParameters(
                Queries.mechanics,
                state.uri.queryParameters,
              ),
            ),
            routes: entityRoutes(
              form: (_) => DeferredScreen(
                load: reference_forms.loadLibrary,
                build: () => reference_forms.MechanicFormScreen(),
              ),
              edit: (id) => DeferredScreen(
                load: reference_forms.loadLibrary,
                build: () => reference_forms.MechanicFormScreen(id: id),
              ),
              detail: (context, id) => _detail<WithCars<Mechanic>>(
                'mechanic-$id',
                context,
                () => _withCars(
                  context,
                  context.read<MechanicRepository>().findById(id),
                  CarQuery(mechanicId: id, size: 20),
                ),
                MechanicDetailScreen(id: id),
              ),
            ),
          ),
          GoRoute(
            // Каталог услуг открыт всем ролям; формы — только мастеру
            // и администратору (redirect у new и edit).
            path: '/services',
            redirect: allow(Operation.viewCatalog),
            builder: (context, state) => ServiceListScreen(
              query: EntityQuery.fromQueryParameters(
                Queries.services,
                state.uri.queryParameters,
              ),
            ),
            routes: entityRoutes(
              form: (_) => DeferredScreen(
                load: reference_forms.loadLibrary,
                build: () => reference_forms.ServiceFormScreen(),
              ),
              edit: (id) => DeferredScreen(
                load: reference_forms.loadLibrary,
                build: () => reference_forms.ServiceFormScreen(id: id),
              ),
              detail: (context, id) => _detail<WithCars<ServiceItem>>(
                'service-$id',
                context,
                () => _withCars(
                  context,
                  context.read<ServiceRepository>().findById(id),
                  null,
                ),
                ServiceDetailScreen(id: id),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

/// Состояние карточки живёт, пока открыт экран. После изменений на
/// сервере (сохранили форму, удалили связанную запись) карточка
/// перечитывается сама.
Widget _detail<T>(
  String key,
  BuildContext context,
  Future<T?> Function() loader,
  Widget child,
) => ChangeNotifierProvider(
  key: ValueKey(key),
  create: (context) =>
      DetailNotifier<T>(loader, changes: context.read<DataChanges>())..load(),
  child: child,
);

Widget _appointmentDetail(
  BuildContext context,
  String id, {
  required String backLocation,
}) => _detail<Appointment>(
  'appointment-$id',
  context,
  () => context.read<AppointmentRepository>().findById(id),
  AppointmentDetailScreen(id: id, backLocation: backLocation),
);

/// Запись вместе со ссылающимися на неё автомобилями. [query] — null,
/// если автомобили на запись не ссылаются (услуга, категория).
Future<WithCars<T>?> _withCars<T>(
  BuildContext context,
  Future<T?> item,
  CarQuery? query,
) async {
  final cars = context.read<CarRepository>();
  final found = await item;
  if (found == null) return null;
  if (query == null) return WithCars(item: found, cars: const [], total: 0);
  final page = await cars.find(query);
  return WithCars(item: found, cars: page.items, total: page.total);
}
