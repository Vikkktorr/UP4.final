import '../models/brand.dart';
import '../models/entity_query.dart';
import 'entity_repository.dart';

abstract interface class BrandRepository
    implements EntityRepository<Brand, EntityQuery> {}
