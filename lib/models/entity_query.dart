import '../core/query_params.dart';
import 'entity.dart';

/// Настройка условий отбора для конкретного списка: адрес, допустимые
/// поля сортировки и имена фильтров.
class QuerySpec {
  final String path;
  final Set<String> sortFields;
  final String defaultSort;

  /// Имена параметров-фильтров. Всё остальное из адреса игнорируется.
  final Set<String> filterKeys;

  const QuerySpec({
    required this.path,
    required this.sortFields,
    required this.defaultSort,
    this.filterKeys = const {},
  });
}

/// Условия отбора для справочников: марок, мастеров, услуг.
///
/// У автомобилей и клиентов свои классы с типизированными фильтрами.
/// Здесь фильтры хранятся строками по имени — справочникам хватает
/// одного-двух выпадающих списков, и один класс обслуживает все три.
class EntityQuery implements PagedQuery {
  final QuerySpec spec;
  final String search;
  final Map<String, String> filters;
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

  EntityQuery(
    this.spec, {
    this.search = '',
    this.filters = const {},
    String? sortField,
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  }) : sortField = sortField ?? spec.defaultSort;

  String? filter(String key) => filters[key];

  bool get hasFilters => search.isNotEmpty || filters.isNotEmpty;

  EntityQuery copyWith({
    String? search,
    Map<String, String>? filters,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    return EntityQuery(
      spec,
      search: search ?? this.search,
      filters: filters ?? this.filters,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      // Как и в CarQuery: изменение условий возвращает на первую страницу.
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  /// Установить или снять (null) один фильтр.
  EntityQuery withFilter(String key, String? value) => copyWith(
    filters: {
      for (final e in filters.entries)
        if (e.key != key) e.key: e.value,
      if (value != null && value.isNotEmpty) key: value,
    },
  );

  EntityQuery cleared() => copyWith(search: '', filters: const {});

  EntityQuery sortedBy(String field) => copyWith(
    sortField: field,
    sortAscending: field == sortField ? !sortAscending : true,
  );

  Map<String, String> toQueryParameters() => {
    if (search.isNotEmpty) 'search': search,
    ...filters,
    if (sortField != spec.defaultSort || !sortAscending)
      'sort': formatSort(sortField, sortAscending),
    if (page != 1) 'page': '$page',
    if (size != pageSizes.first) 'size': '$size',
    if (includeDeleted) 'deleted': '1',
  };

  factory EntityQuery.fromQueryParameters(
    QuerySpec spec,
    Map<String, String> params,
  ) {
    final sort = parseSort(
      params['sort'],
      allowed: spec.sortFields,
      fallbackField: spec.defaultSort,
    );
    return EntityQuery(
      spec,
      search: params['search']?.trim() ?? '',
      filters: {
        for (final key in spec.filterKeys)
          if (params[key]?.trim().isNotEmpty ?? false) key: params[key]!.trim(),
      },
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
      path: spec.path,
      queryParameters: params.isEmpty ? null : params,
    ).toString();
  }

  @override
  bool operator ==(Object other) =>
      other is EntityQuery &&
      other.spec.path == spec.path &&
      other.search == search &&
      _sameFilters(other.filters, filters) &&
      other.sortField == sortField &&
      other.sortAscending == sortAscending &&
      other.page == page &&
      other.size == size &&
      other.includeDeleted == includeDeleted;

  static bool _sameFilters(Map<String, String> a, Map<String, String> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

  @override
  int get hashCode => Object.hash(
    spec.path,
    search,
    Object.hashAllUnordered(filters.entries.map((e) => '${e.key}=${e.value}')),
    sortField,
    sortAscending,
    page,
    size,
    includeDeleted,
  );
}

/// Настройки справочников.
class Queries {
  const Queries._();

  static const brands = QuerySpec(
    path: '/brands',
    sortFields: {'name', 'country'},
    defaultSort: 'name',
    filterKeys: {'country'},
  );

  static const mechanics = QuerySpec(
    path: '/mechanics',
    sortFields: {'name', 'grade', 'experience'},
    defaultSort: 'name',
    filterKeys: {'grade'},
  );

  static const services = QuerySpec(
    path: '/services',
    sortFields: {'name', 'price', 'duration'},
    defaultSort: 'name',
    filterKeys: {'category'},
  );

  static const categories = QuerySpec(
    path: '/categories',
    sortFields: {'name'},
    defaultSort: 'name',
  );
}
