import '../core/query_params.dart';
import 'club_card.dart';
import 'entity.dart';

/// Условия отбора списка клиентов.
class ClientQuery implements PagedQuery {
  final String search;

  /// Уровень клубной карты — фильтр по связанной записи «один к одному».
  final CardLevel? level;

  /// Персональная скидка не меньше, %.
  final int? discountFrom;

  /// Клиент с такого-то года (по дате регистрации), от и до.
  final int? sinceFrom;
  final int? sinceTo;
  @override
  final String sortField;
  @override
  final bool sortAscending;
  @override
  final int page;
  @override
  final int size;
  @override
  final bool includeDeleted;

  static const sortFields = {'name', 'registeredAt', 'discount'};
  static const defaultSort = 'name';

  const ClientQuery({
    this.search = '',
    this.level,
    this.discountFrom,
    this.sinceFrom,
    this.sinceTo,
    this.sortField = defaultSort,
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  });

  bool get hasFilters =>
      search.isNotEmpty ||
      level != null ||
      discountFrom != null ||
      sinceFrom != null ||
      sinceTo != null;

  ClientQuery copyWith({
    String? search,
    Object? level = _unset,
    Object? discountFrom = _unset,
    Object? sinceFrom = _unset,
    Object? sinceTo = _unset,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    return ClientQuery(
      search: search ?? this.search,
      level: level == _unset ? this.level : level as CardLevel?,
      discountFrom: discountFrom == _unset
          ? this.discountFrom
          : discountFrom as int?,
      sinceFrom: sinceFrom == _unset ? this.sinceFrom : sinceFrom as int?,
      sinceTo: sinceTo == _unset ? this.sinceTo : sinceTo as int?,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  ClientQuery cleared() => copyWith(
    search: '',
    level: null,
    discountFrom: null,
    sinceFrom: null,
    sinceTo: null,
  );

  static const _unset = Object();

  ClientQuery sortedBy(String field) => copyWith(
    sortField: field,
    sortAscending: field == sortField ? !sortAscending : true,
  );

  Map<String, String> toQueryParameters() => {
    if (search.isNotEmpty) 'search': search,
    if (level != null) 'level': level!.code,
    if (discountFrom != null) 'discountFrom': '$discountFrom',
    if (sinceFrom != null) 'sinceFrom': '$sinceFrom',
    if (sinceTo != null) 'sinceTo': '$sinceTo',
    if (sortField != defaultSort || !sortAscending)
      'sort': formatSort(sortField, sortAscending),
    if (page != 1) 'page': '$page',
    if (size != pageSizes.first) 'size': '$size',
    if (includeDeleted) 'deleted': '1',
  };

  factory ClientQuery.fromQueryParameters(Map<String, String> params) {
    final sort = parseSort(
      params['sort'],
      allowed: sortFields,
      fallbackField: defaultSort,
    );
    return ClientQuery(
      search: params['search']?.trim() ?? '',
      level: CardLevel.fromCode(params['level']),
      discountFrom: parseIntParam(params['discountFrom']),
      sinceFrom: parseIntParam(params['sinceFrom']),
      sinceTo: parseIntParam(params['sinceTo']),
      sortField: sort.field,
      sortAscending: sort.ascending,
      page: parsePage(params['page']),
      size: parsePageSize(params['size']),
      includeDeleted: parseFlag(params['deleted']),
    );
  }

  String toLocation() {
    final params = toQueryParameters();
    return Uri(
      path: '/clients',
      queryParameters: params.isEmpty ? null : params,
    ).toString();
  }

  @override
  bool operator ==(Object other) =>
      other is ClientQuery &&
      other.search == search &&
      other.level == level &&
      other.discountFrom == discountFrom &&
      other.sinceFrom == sinceFrom &&
      other.sinceTo == sinceTo &&
      other.sortField == sortField &&
      other.sortAscending == sortAscending &&
      other.page == page &&
      other.size == size &&
      other.includeDeleted == includeDeleted;

  @override
  int get hashCode => Object.hash(
    search,
    level,
    discountFrom,
    sinceFrom,
    sinceTo,
    sortField,
    sortAscending,
    page,
    size,
    includeDeleted,
  );
}
