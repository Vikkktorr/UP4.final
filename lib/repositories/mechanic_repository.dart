import '../models/mechanic.dart';
import '../models/entity_query.dart';
import 'entity_repository.dart';

abstract interface class MechanicRepository
    implements EntityRepository<Mechanic, EntityQuery> {}
