import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/club_card.dart';
import 'data_changes.dart';

/// Клубные карты. Своего списка у них нет: карта выдаётся, меняется
/// и снимается на карточке клиента.
class ClubCardRepository {
  ClubCardRepository(this._dio, {required this.changes});

  final Dio _dio;
  final DataChanges changes;

  static const _path = '/api/collections/club_cards/records';

  Future<ClubCard> save(ClubCard card) => _write(() async {
    final body = card.toJson()..remove('id');
    final response = card.id.isEmpty
        ? await _dio.post<Map<String, dynamic>>(_path, data: body)
        : await _dio.patch<Map<String, dynamic>>(
            '$_path/${card.id}',
            data: body,
          );
    return ClubCard.fromJson(response.data!);
  });

  Future<void> delete(String id) =>
      _write(() => _dio.delete<void>('$_path/$id'));

  Future<R> _write<R>(Future<R> Function() action) async {
    final result = await guard(action);
    changes.changed();
    return result;
  }
}
