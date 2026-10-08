import 'package:flutter/foundation.dart';

import '../models/brand.dart';
import '../models/entity_query.dart';
import '../models/mechanic.dart';
import '../models/service_category.dart';
import '../models/service_item.dart';
import '../repositories/brand_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/mechanic_repository.dart';
import '../repositories/service_repository.dart';
import 'entity_list_notifier.dart';

/// Списки справочников. Вся логика — в [EntityListNotifier], отдельные
/// классы нужны, чтобы provider различал их по типу.
class BrandListNotifier extends EntityListNotifier<Brand, EntityQuery> {
  BrandListNotifier(BrandRepository repository, {Listenable? changes})
    : super(
        repository,
        (b) => b.id,
        EntityQuery(Queries.brands),
        changes: changes,
      );
}

class MechanicListNotifier extends EntityListNotifier<Mechanic, EntityQuery> {
  MechanicListNotifier(MechanicRepository repository, {Listenable? changes})
    : super(
        repository,
        (m) => m.id,
        EntityQuery(Queries.mechanics),
        changes: changes,
      );
}

class ServiceListNotifier extends EntityListNotifier<ServiceItem, EntityQuery> {
  ServiceListNotifier(ServiceRepository repository, {Listenable? changes})
    : super(
        repository,
        (s) => s.id,
        EntityQuery(Queries.services),
        changes: changes,
      );
}

class CategoryListNotifier
    extends EntityListNotifier<ServiceCategory, EntityQuery> {
  CategoryListNotifier(CategoryRepository repository, {Listenable? changes})
    : super(
        repository,
        (c) => c.id,
        EntityQuery(Queries.categories),
        changes: changes,
      );
}
