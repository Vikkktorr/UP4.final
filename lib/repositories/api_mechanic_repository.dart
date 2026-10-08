import '../core/pocketbase.dart';
import '../models/entity_query.dart';
import '../models/mechanic.dart';
import 'api_repository.dart';
import 'mechanic_repository.dart';

class ApiMechanicRepository extends ApiRepository<Mechanic, EntityQuery>
    implements MechanicRepository {
  ApiMechanicRepository(super.dio, {required super.changes})
    : super(collection: 'mechanics', cacheAll: true);

  @override
  Mechanic fromJson(Map<String, dynamic> json) => Mechanic.fromJson(json);

  @override
  String filterOf(EntityQuery q) => pbAnd([
    pbSearch(['last_name', 'first_name', 'middle_name', 'phone'], q.search),
    if (int.tryParse(q.filter('grade') ?? '') case final grade?)
      'grade = $grade',
  ]);

  @override
  String sortFieldOf(String field) => field == 'name' ? 'last_name' : field;
}
