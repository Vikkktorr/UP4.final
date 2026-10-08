import 'package:flutter/foundation.dart';

import '../models/brand.dart';
import '../models/car_model.dart';
import '../models/client.dart';
import '../models/entity.dart';
import '../models/mechanic.dart';
import '../models/service_category.dart';
import '../models/service_item.dart';
import '../repositories/brand_repository.dart';
import '../repositories/car_model_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/client_repository.dart';
import '../repositories/mechanic_repository.dart';
import '../repositories/service_repository.dart';

/// Справочники для подписей, выпадающих списков и наборов фишек.
///
/// В записях хранятся только идентификаторы, а в интерфейсе нужно показать
/// «Kia Rio», «Иванов С. П.» и имена мастеров. Варианты выбора в формах
/// берутся отсюда, то есть с сервера, а не из констант в коде.
class LookupNotifier extends ChangeNotifier {
  LookupNotifier({
    required BrandRepository brands,
    required CarModelRepository models,
    required ClientRepository clients,
    required MechanicRepository mechanics,
    required ServiceRepository services,
    required CategoryRepository categories,
    Listenable? changes,
    bool Function()? active,
    bool Function()? canViewClients,
  }) : _brands = brands,
       _models = models,
       _clients = clients,
       _mechanics = mechanics,
       _services = services,
       _categories = categories,
       _changes = changes,
       _active = active,
       _canViewClients = canViewClients {
    // После любой записи справочники перечитываются: новая марка сразу
    // появляется в форме автомобиля.
    _changes?.addListener(load);
  }

  final BrandRepository _brands;
  final CarModelRepository _models;
  final ClientRepository _clients;
  final MechanicRepository _mechanics;
  final ServiceRepository _services;
  final CategoryRepository _categories;
  final Listenable? _changes;

  /// Загружать ли справочники: до входа читать нечего.
  final bool Function()? _active;

  /// Можно ли роли смотреть всех клиентов. Клиенту правило PocketBase
  /// отдаёт только его собственную запись, поэтому список ему не нужен.
  final bool Function()? _canViewClients;

  Map<String, Brand> _brandById = const {};
  Map<String, CarModel> _modelById = const {};
  Map<String, Client> _clientById = const {};
  Map<String, Mechanic> _mechanicById = const {};
  Map<String, ServiceItem> _serviceById = const {};
  Map<String, ServiceCategory> _categoryById = const {};
  bool _loaded = false;
  bool _disposed = false;
  int _generation = 0;

  bool get loaded => _loaded;

  /// Действующие записи, отсортированные для показа в списках выбора.
  List<Brand> get brands => _live(_brandById, (b) => b.name);
  List<Client> get clients => _live(_clientById, (c) => c.fullName);
  List<Mechanic> get mechanics => _live(_mechanicById, (m) => m.fullName);
  List<ServiceItem> get services => _live(_serviceById, (s) => s.name);
  List<ServiceCategory> get categories => _live(_categoryById, (c) => c.name);

  /// Действующие модели марки — для формы автомобиля.
  List<CarModel> modelsOf(String brandId) => _live({
    for (final m in _modelById.values)
      if (m.brandId == brandId) m.id: m,
  }, (m) => m.name);

  /// Все страны марок — для фильтра списка марок.
  List<String> get countries =>
      {for (final b in _brandById.values) b.country}.toList()..sort();

  static List<T> _live<T extends Entity>(
    Map<String, T> map,
    String Function(T) label,
  ) {
    final list = map.values.where((e) => !e.isDeleted).toList();
    list.sort(
      (a, b) => label(a).toLowerCase().compareTo(label(b).toLowerCase()),
    );
    return list;
  }

  Brand? brand(String id) => _brandById[id];
  CarModel? model(String id) => _modelById[id];
  Client? client(String id) => _clientById[id];
  Mechanic? mechanic(String id) => _mechanicById[id];
  ServiceItem? service(String id) => _serviceById[id];
  ServiceCategory? category(String id) => _categoryById[id];

  String brandName(String id) => _brandById[id]?.name ?? '—';
  String modelName(String id) => _modelById[id]?.name ?? '—';

  /// Марка модели — у автомобиля хранится только модель.
  String? brandIdOfModel(String modelId) => _modelById[modelId]?.brandId;

  /// «Kia Rio» по модели.
  String carTitle(String modelId) {
    final model = _modelById[modelId];
    if (model == null) return '—';
    return '${brandName(model.brandId)} ${model.name}';
  }

  String clientName(String id) => _clientById[id]?.shortName ?? 'Клиент';
  String mechanicName(String id) => _mechanicById[id]?.shortName ?? 'Мастер';
  String serviceName(String id) => _serviceById[id]?.name ?? 'Услуга';
  String categoryName(String id) => _categoryById[id]?.name ?? '—';

  Future<void> load() async {
    if (_active != null && !_active()) return;
    final generation = ++_generation;
    final withClients = _canViewClients?.call() ?? true;
    try {
      final brands = await _brands.findAll();
      final models = await _models.findAll();
      final clients = withClients ? await _clients.findAll() : <Client>[];
      final mechanics = await _mechanics.findAll();
      final services = await _services.findAll();
      final categories = await _categories.findAll();
      // Пока шла загрузка, могла начаться следующая — её данные новее.
      if (_disposed || generation != _generation) return;
      _brandById = {for (final b in brands) b.id: b};
      _modelById = {for (final m in models) m.id: m};
      _clientById = {for (final c in clients) c.id: c};
      _mechanicById = {for (final m in mechanics) m.id: m};
      _serviceById = {for (final s in services) s.id: s};
      _categoryById = {for (final c in categories) c.id: c};
      _loaded = true;
      notifyListeners();
    } catch (_) {
      // Без справочников списки всё равно работают: вместо названий
      // покажутся прочерки. Повторная попытка — при следующей загрузке.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _changes?.removeListener(load);
    super.dispose();
  }
}
