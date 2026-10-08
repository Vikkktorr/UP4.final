import '../models/entity_query.dart';
import '../models/service_category.dart';
import 'entity_repository.dart';

abstract interface class CategoryRepository
    implements EntityRepository<ServiceCategory, EntityQuery> {}
