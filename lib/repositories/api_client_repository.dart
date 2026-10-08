import '../core/pocketbase.dart';
import '../models/client.dart';
import '../models/client_query.dart';
import 'api_repository.dart';
import 'client_repository.dart';

class ApiClientRepository extends ApiRepository<Client, ClientQuery>
    implements ClientRepository {
  // Клубная карта приходит в том же ответе — через обратную связь
  // club_cards.client («карты, ссылающиеся на этого клиента»).
  ApiClientRepository(super.dio, {required super.changes})
    : super(collection: 'clients', expand: 'club_cards_via_client');

  @override
  Client fromJson(Map<String, dynamic> json) => Client.fromJson(json);

  @override
  String filterOf(ClientQuery q) => pbAnd([
    pbSearch([
      'last_name',
      'first_name',
      'middle_name',
      'phone',
      'email',
    ], q.search),
    if (q.level != null)
      'club_cards_via_client.level ?= ${pbString(q.level!.code)}',
    if (q.discountFrom != null) 'discount >= ${q.discountFrom}',
    if (q.sinceFrom != null)
      'registered_at >= ${pbString('${q.sinceFrom}-01-01 00:00:00.000Z')}',
    if (q.sinceTo != null)
      'registered_at < ${pbString('${q.sinceTo! + 1}-01-01 00:00:00.000Z')}',
  ]);

  @override
  String sortFieldOf(String field) => switch (field) {
    'name' => 'last_name',
    'registeredAt' => 'registered_at',
    _ => field,
  };
}
