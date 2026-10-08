import 'package:flutter/foundation.dart';

import '../models/client.dart';
import '../models/client_query.dart';
import '../repositories/client_repository.dart';
import 'entity_list_notifier.dart';

class ClientListNotifier extends EntityListNotifier<Client, ClientQuery> {
  ClientListNotifier(ClientRepository repository, {Listenable? changes})
    : super(
        repository,
        (client) => client.id,
        const ClientQuery(),
        changes: changes,
      );
}
