import 'dart:async';
import 'dart:convert';

import 'package:autoservice_web/core/api_exceptions.dart';
import 'package:autoservice_web/core/formatting.dart';
import 'package:autoservice_web/models/app_user.dart';
import 'package:autoservice_web/models/appointment.dart';
import 'package:autoservice_web/models/appointment_query.dart';
import 'package:autoservice_web/models/brand.dart';
import 'package:autoservice_web/models/car.dart';
import 'package:autoservice_web/models/car_model.dart';
import 'package:autoservice_web/models/car_query.dart';
import 'package:autoservice_web/models/client.dart';
import 'package:autoservice_web/models/client_query.dart';
import 'package:autoservice_web/models/entity.dart';
import 'package:autoservice_web/models/entity_query.dart';
import 'package:autoservice_web/models/fuel_type.dart';
import 'package:autoservice_web/models/mechanic.dart';
import 'package:autoservice_web/models/page_result.dart';
import 'package:autoservice_web/models/service_category.dart';
import 'package:autoservice_web/models/service_item.dart';
import 'package:autoservice_web/repositories/appointment_repository.dart';
import 'package:autoservice_web/repositories/auth_api.dart';
import 'package:autoservice_web/repositories/brand_repository.dart';
import 'package:autoservice_web/repositories/car_model_repository.dart';
import 'package:autoservice_web/repositories/car_repository.dart';
import 'package:autoservice_web/repositories/category_repository.dart';
import 'package:autoservice_web/repositories/client_repository.dart';
import 'package:autoservice_web/repositories/mechanic_repository.dart';
import 'package:autoservice_web/repositories/service_repository.dart';
import 'package:autoservice_web/screens/forms/appointment_form_screen.dart';
import 'package:autoservice_web/screens/forms/reference_form_screens.dart';
import 'package:autoservice_web/screens/reference_screens.dart';
import 'package:autoservice_web/state/auth_notifier.dart';
import 'package:autoservice_web/state/lookup_notifier.dart';
import 'package:autoservice_web/state/reference_list_notifiers.dart';
import 'package:autoservice_web/widgets/entity_form/leave_guard.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Репозиторий без сервера: записи задаёт тест.
class FakeRepository<T extends Entity, Q extends PagedQuery> {
  FakeRepository({List<T> items = const []}) : items = List.of(items);

  List<T> items;

  /// Если задано — запрос списка завершается этой ошибкой.
  Object? error;

  /// Если задано — запрос списка ждёт, пока тест не завершит его сам.
  Completer<PageResult<T>>? pending;

  int findCalls = 0;

  Future<PageResult<T>> find(Q query) async {
    findCalls++;
    if (pending != null) return pending!.future;
    if (error != null) throw error!;
    return PageResult(
      items: items,
      total: items.length,
      page: 1,
      size: query.size,
    );
  }

  Future<List<T>> findAll() async => items;

  Future<T?> findById(String id) async {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<T> create(T entity) async => entity;
  Future<T> update(T entity) async => entity;
  Future<void> softDelete(String id) async {}
  Future<void> hardDelete(String id) async {}
  Future<void> restore(String id) async {}
  Future<int> deleteMany(List<String> ids) async => 0;
}

class FakeServiceRepository extends FakeRepository<ServiceItem, EntityQuery>
    implements ServiceRepository {
  FakeServiceRepository({super.items});
}

class FakeBrands extends FakeRepository<Brand, EntityQuery>
    implements BrandRepository {}

class FakeModels extends FakeRepository<CarModel, EntityQuery>
    implements CarModelRepository {
  FakeModels({super.items});
}

class FakeClients extends FakeRepository<Client, ClientQuery>
    implements ClientRepository {
  FakeClients({super.items});
}

class FakeMechanics extends FakeRepository<Mechanic, EntityQuery>
    implements MechanicRepository {
  FakeMechanics({super.items});
}

class FakeCategories extends FakeRepository<ServiceCategory, EntityQuery>
    implements CategoryRepository {
  FakeCategories({super.items});
}

class FakeCars extends FakeRepository<Car, CarQuery> implements CarRepository {
  FakeCars({super.items});
}

/// Записи: изменение отклоняется сервером, как при занятом мастере.
class FakeAppointments extends FakeRepository<Appointment, AppointmentQuery>
    implements AppointmentRepository {
  FakeAppointments({super.items, this.saveError});

  final Object? saveError;

  @override
  Future<Appointment> update(Appointment entity) async =>
      saveError == null ? entity : throw saveError!;

  @override
  Future<List<BusySlot>> busy(
    String mechanicId,
    DateTime from,
    DateTime to,
  ) async => const [];

  @override
  Future<List<Appointment>> forMechanic(
    String m,
    DateTime f,
    DateTime t,
  ) async => items;

  @override
  Future<List<Appointment>> forCar(String carId) async => items;

  @override
  Future<void> cancel(String id) async {}
}

/// Вошедший пользователь с заданной ролью: профиль лежит в хранилище,
/// как после входа, и восстанавливается без обращения к серверу.
Future<AuthNotifier> signedIn(Role role) async {
  const user = AppUser(
    id: 'user00000000001',
    username: 'user',
    role: Role.client,
    lastName: 'Иванов',
    firstName: 'Сергей',
  );
  SharedPreferences.setMockInitialValues({
    'auth_access_token': 'token',
    'auth_user': jsonEncode({...user.toJson(), 'role': role.name}),
  });
  final auth = AuthNotifier(
    await SharedPreferences.getInstance(),
    AuthApi(Dio()),
  );
  await auth.restore();
  return auth;
}

const maintenance = ServiceCategory(
  id: 'cat000000000001',
  name: 'Техобслуживание',
);

const oilChange = ServiceItem(
  id: 'srv000000000001',
  name: 'Замена моторного масла',
  categoryId: 'cat000000000001',
  price: 1800,
  duration: 40,
);

/// Экран в окружении приложения: маршрутизатор, вошедший пользователь,
/// справочники и подставные репозитории.
Widget buildTestApp(
  Widget screen, {
  required AuthNotifier auth,
  FakeServiceRepository? repository,
  FakeCars? cars,
  FakeClients? clients,
  FakeMechanics? mechanics,
  FakeAppointments? appointments,
}) {
  final services = repository ?? FakeServiceRepository(items: [oilChange]);
  final clientRepo = clients ?? FakeClients();
  final mechanicRepo = mechanics ?? FakeMechanics();
  return MultiProvider(
    providers: [
      // Провайдер закрывает AuthNotifier вместе с деревом — и его таймер сессии.
      ChangeNotifierProvider<AuthNotifier>(create: (_) => auth, lazy: false),
      Provider.value(value: LeaveGuard()),
      Provider<ServiceRepository>.value(value: services),
      Provider<CarRepository>.value(value: cars ?? FakeCars()),
      Provider<ClientRepository>.value(value: clientRepo),
      Provider<AppointmentRepository>.value(
        value: appointments ?? FakeAppointments(),
      ),
      ChangeNotifierProvider(create: (_) => ServiceListNotifier(services)),
      ChangeNotifierProvider(
        create: (_) => LookupNotifier(
          brands: FakeBrands(),
          models: FakeModels(),
          clients: clientRepo,
          mechanics: mechanicRepo,
          // Каталог услуг для справочника — всегда полный, даже если
          // список на экране пуст или с ошибкой.
          services: FakeServiceRepository(items: [oilChange]),
          categories: FakeCategories(items: [maintenance]),
        )..load(),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(body: screen),
          ),
        ],
      ),
    ),
  );
}

final servicesList = ServiceListScreen(query: EntityQuery(Queries.services));

void main() {
  testWidgets('Во время загрузки списка виден индикатор', (tester) async {
    final repository = FakeServiceRepository()..pending = Completer();
    final auth = await signedIn(Role.mechanic);
    await tester.pumpWidget(
      buildTestApp(servicesList, auth: auth, repository: repository),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Загрузка…'), findsOneWidget);

    repository.pending!.complete(
      const PageResult(items: [oilChange], total: 1, page: 1, size: 10),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Замена моторного масла'), findsOneWidget);
  });

  testWidgets('Список показывает сообщение при пустом результате', (
    tester,
  ) async {
    final auth = await signedIn(Role.mechanic);
    await tester.pumpWidget(
      buildTestApp(
        servicesList,
        auth: auth,
        repository: FakeServiceRepository(items: []),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ничего не найдено'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Ошибка загрузки: сообщение и кнопка повтора', (tester) async {
    final repository = FakeServiceRepository(items: [oilChange])
      ..error = const NetworkException();
    final auth = await signedIn(Role.mechanic);
    await tester.pumpWidget(
      buildTestApp(servicesList, auth: auth, repository: repository),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ошибка загрузки'), findsOneWidget);
    expect(find.textContaining('Сервер недоступен'), findsOneWidget);

    // Связь восстановилась: повтор загружает список без перезагрузки.
    repository.error = null;
    final calls = repository.findCalls;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(repository.findCalls, calls + 1);
    expect(find.text('Ошибка загрузки'), findsNothing);
    expect(find.text('Замена моторного масла'), findsOneWidget);
  });

  testWidgets('Форма не отправляется с пустым названием', (tester) async {
    final auth = await signedIn(Role.mechanic);
    await tester.pumpWidget(
      buildTestApp(
        const ServiceFormScreen(),
        auth: auth,
        repository: FakeServiceRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Добавить услугу'));
    await tester.pumpAndSettle();

    expect(find.text('Обязательное поле'), findsWidgets);
  });

  testWidgets('Кнопка добавления скрыта от клиента и видна мастеру', (
    tester,
  ) async {
    final repository = FakeServiceRepository(items: [oilChange]);

    await tester.pumpWidget(
      buildTestApp(
        servicesList,
        auth: await signedIn(Role.client),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Замена моторного масла'), findsOneWidget);
    expect(find.text('Добавить услугу'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      buildTestApp(
        servicesList,
        auth: await signedIn(Role.mechanic),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Добавить услугу'), findsOneWidget);
  });

  testWidgets('Запись на занятое время: сообщение сервера о занятости мастера', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final mechanic = Mechanic(
      id: 'mech00000000001',
      lastName: 'Громов',
      firstName: 'Виктор',
      phone: '+7 (916) 200-10-01',
      grade: 6,
      experience: 22,
      hiredAt: DateTime(2012),
    );
    const car = Car(
      id: 'car000000000001',
      plate: 'А123ВС777',
      vin: 'XTA219170K0123456',
      modelId: 'model0000000001',
      year: 2019,
      mileage: 84500,
      fuel: FuelType.petrol,
      clientId: 'client000000001',
      mechanicIds: ['mech00000000001'],
    );
    final appointment = Appointment(
      id: 'appt00000000001',
      carId: car.id,
      mechanicId: mechanic.id,
      serviceIds: [oilChange.id],
      startsAt: DateTime(2026, 10, 9, 10),
    );
    await tester.pumpWidget(
      buildTestApp(
        const AppointmentFormScreen(
          id: 'appt00000000001',
          backLocation: '/appointments',
        ),
        auth: await signedIn(Role.mechanic),
        cars: FakeCars(items: [car]),
        mechanics: FakeMechanics(items: [mechanic]),
        appointments: FakeAppointments(
          items: [appointment],
          saveError: const ConflictException(
            'Мастер занят с 10:00 до 11:30 — выберите другое время или мастера.',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Предпросмотр по правилам автосервиса: 40 минут, без скидки.
    expect(find.text('40 мин'), findsOneWidget);
    expect(find.text(formatMoney(1800)), findsWidgets);

    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Мастер занят с 10:00 до 11:30'),
      findsOneWidget,
    );
  });
}
