import '../models/service_item.dart';
import '../models/entity_query.dart';
import 'entity_repository.dart';

abstract interface class ServiceRepository
    implements EntityRepository<ServiceItem, EntityQuery> {}
