import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/config.dart';
import 'core/permissions.dart';
import 'core/router.dart';
import 'core/ru_localizations.dart';
import 'repositories/admin_api.dart';
import 'repositories/api_appointment_repository.dart';
import 'repositories/api_brand_repository.dart';
import 'repositories/api_car_model_repository.dart';
import 'repositories/api_category_repository.dart';
import 'repositories/api_car_repository.dart';
import 'repositories/api_client_repository.dart';
import 'repositories/api_mechanic_repository.dart';
import 'repositories/api_service_repository.dart';
import 'repositories/appointment_repository.dart';
import 'repositories/brand_repository.dart';
import 'repositories/car_model_repository.dart';
import 'repositories/category_repository.dart';
import 'repositories/club_card_repository.dart';
import 'repositories/car_repository.dart';
import 'repositories/client_repository.dart';
import 'repositories/data_changes.dart';
import 'repositories/mechanic_repository.dart';
import 'repositories/network_simulator.dart';
import 'repositories/service_repository.dart';
import 'state/auth_notifier.dart';
import 'state/appointment_list_notifier.dart';
import 'state/car_list_notifier.dart';
import 'state/client_list_notifier.dart';
import 'state/lookup_notifier.dart';
import 'state/reference_list_notifiers.dart';
import 'widgets/entity_form/leave_guard.dart';
import 'widgets/inactivity_watcher.dart';

/// Собирает зависимости приложения. Вынесено из main, чтобы можно было
/// подставить свою имитацию сети и начальный адрес.
///
/// [auth] создаётся в main: сессия восстанавливается до построения
/// дерева виджетов, иначе маршрутизатор успел бы отправить на вход.
Widget buildApp({
  required AuthNotifier auth,
  NetworkSimulator? network,
  String initialLocation = '/',
}) {
  final net = network ?? NetworkSimulator();
  final changes = DataChanges();
  final guard = LeaveGuard();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider.value(value: net),
      ChangeNotifierProvider.value(value: changes),
      Provider.value(value: guard),
      Provider<Dio>(
        create: (_) => buildDio(
          // Заголовок Authorization добавляется интерсептором к каждому
          // запросу, начиная с самого первого.
          tokenProvider: () => auth.accessToken,
          ensureFreshToken: auth.ensureFreshToken,
          refreshTokens: auth.refreshTokens,
          onRefreshFailed: () async {
            if (auth.isAuthenticated) {
              await auth.logout(
                reason: 'Сессия истекла: войдите в систему снова.',
              );
            }
          },
          simulate: () => net.state,
        ),
      ),
      ProxyProvider<Dio, AdminApi>(update: (_, dio, _) => AdminApi(dio)),
      // Единственное место, где выбирается источник данных: репозитории
      // PocketBase. Экраны получают репозитории через интерфейс.
      ProxyProvider<Dio, CarRepository>(
        update: (_, dio, _) => ApiCarRepository(dio, changes: changes),
      ),
      ProxyProvider<Dio, ClientRepository>(
        update: (_, dio, _) => ApiClientRepository(dio, changes: changes),
      ),
      ProxyProvider<Dio, BrandRepository>(
        update: (_, dio, _) => ApiBrandRepository(dio, changes: changes),
      ),
      ProxyProvider<Dio, MechanicRepository>(
        update: (_, dio, _) => ApiMechanicRepository(dio, changes: changes),
      ),
      ProxyProvider<Dio, ServiceRepository>(
        update: (_, dio, _) => ApiServiceRepository(dio, changes: changes),
      ),
      ProxyProvider<Dio, CarModelRepository>(
        update: (_, dio, _) => ApiCarModelRepository(dio, changes: changes),
      ),
      ProxyProvider<Dio, CategoryRepository>(
        update: (_, dio, _) => ApiCategoryRepository(dio, changes: changes),
      ),
      ProxyProvider<Dio, ClubCardRepository>(
        update: (_, dio, _) => ClubCardRepository(dio, changes: changes),
      ),
      ProxyProvider<Dio, AppointmentRepository>(
        update: (_, dio, _) => ApiAppointmentRepository(dio, changes: changes),
      ),
      ChangeNotifierProvider(
        create: (context) =>
            CarListNotifier(context.read<CarRepository>(), changes: changes),
      ),
      ChangeNotifierProvider(
        create: (context) => ClientListNotifier(
          context.read<ClientRepository>(),
          changes: changes,
        ),
      ),
      ChangeNotifierProvider(
        create: (context) => BrandListNotifier(
          context.read<BrandRepository>(),
          changes: changes,
        ),
      ),
      ChangeNotifierProvider(
        create: (context) => MechanicListNotifier(
          context.read<MechanicRepository>(),
          changes: changes,
        ),
      ),
      ChangeNotifierProvider(
        create: (context) => ServiceListNotifier(
          context.read<ServiceRepository>(),
          changes: changes,
        ),
      ),
      ChangeNotifierProvider(
        create: (context) => CategoryListNotifier(
          context.read<CategoryRepository>(),
          changes: changes,
        ),
      ),
      ChangeNotifierProvider(
        create: (context) => AppointmentListNotifier(
          context.read<AppointmentRepository>(),
          changes: changes,
        ),
      ),
      ChangeNotifierProvider(
        create: (context) => LookupNotifier(
          brands: context.read<BrandRepository>(),
          models: context.read<CarModelRepository>(),
          clients: context.read<ClientRepository>(),
          mechanics: context.read<MechanicRepository>(),
          services: context.read<ServiceRepository>(),
          categories: context.read<CategoryRepository>(),
          // Справочники перечитываются после записи данных и после входа.
          changes: Listenable.merge([changes, auth]),
          active: () => auth.isAuthenticated,
          canViewClients: () => auth.can(Operation.viewWorkshop),
        )..load(),
      ),
    ],
    child: AutoServiceApp(
      auth: auth,
      router: createRouter(
        auth: auth,
        initialLocation: initialLocation,
        guard: guard,
      ),
    ),
  );
}

class AutoServiceApp extends StatefulWidget {
  const AutoServiceApp({
    super.key,
    required this.auth,
    required this.router,
    this.notices = const [],
  });

  final AuthNotifier auth;
  final GoRouter router;

  /// Сообщения хранилища после запуска: миграция или сброс данных.
  final List<String> notices;

  @override
  State<AutoServiceApp> createState() => _AutoServiceAppState();
}

class _AutoServiceAppState extends State<AutoServiceApp> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    if (widget.notices.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _messenger.currentState?.showMaterialBanner(
          MaterialBanner(
            leading: const Icon(Icons.info_outline),
            content: Text(widget.notices.join('\n')),
            actions: [
              TextButton(
                onPressed: () =>
                    _messenger.currentState?.hideCurrentMaterialBanner(),
                child: const Text('Понятно'),
              ),
            ],
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Автосервис',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messenger,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F5FAD)),
        useMaterial3: true,
      ),
      // Подписи стандартных виджетов (подсказки, диалоги) — по-русски.
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: ruLocalizationsDelegates,
      // Широкую таблицу можно прокрутить вбок, перетащив мышью.
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
      ),
      routerConfig: widget.router,
      // Таймер неактивности работает над всем приложением, пока
      // пользователь в системе.
      builder: (context, child) => ListenableBuilder(
        listenable: widget.auth,
        builder: (context, _) => widget.auth.isAuthenticated
            ? InactivityWatcher(
                key: ValueKey(widget.auth.user!.id),
                timeout: inactivityTimeout,
                warning: inactivityWarning,
                onActivity: widget.auth.touch,
                onTimeout: () =>
                    widget.auth.logout(reason: AuthNotifier.inactivityMessage),
                child: child!,
              )
            : child!,
      ),
    );
  }
}
