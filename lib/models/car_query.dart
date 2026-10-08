import '../core/query_params.dart';
import 'entity.dart';
import 'fuel_type.dart';

class CarQuery implements PagedQuery {
  final String search;
  final String? brandId;
  final FuelType? fuel;
  final int? yearFrom;
  final int? yearTo;

  final String? clientId;

  /// Автомобили, за которыми закреплён мастер, — переход из карточки мастера.
  final String? mechanicId;

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

  static const sortFields = {'plate', 'brand', 'year', 'mileage'};
  static const defaultSort = 'plate';

  const CarQuery({
    this.search = '',
    this.brandId,
    this.fuel,
    this.yearFrom,
    this.yearTo,
    this.clientId,
    this.mechanicId,
    this.sortField = defaultSort,
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  });

  bool get hasFilters =>
      search.isNotEmpty ||
      brandId != null ||
      fuel != null ||
      yearFrom != null ||
      yearTo != null ||
      clientId != null ||
      mechanicId != null;

  CarQuery copyWith({
    String? search,
    Object? brandId = _unset,
    Object? fuel = _unset,
    Object? yearFrom = _unset,
    Object? yearTo = _unset,
    Object? clientId = _unset,
    Object? mechanicId = _unset,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    return CarQuery(
      search: search ?? this.search,
      brandId: brandId == _unset ? this.brandId : brandId as String?,
      fuel: fuel == _unset ? this.fuel : fuel as FuelType?,
      yearFrom: yearFrom == _unset ? this.yearFrom : yearFrom as int?,
      yearTo: yearTo == _unset ? this.yearTo : yearTo as int?,
      clientId: clientId == _unset ? this.clientId : clientId as String?,
      mechanicId: mechanicId == _unset
          ? this.mechanicId
          : mechanicId as String?,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      // Любое изменение условий отбора возвращает на первую страницу:
      // иначе с седьмой страницы после поиска попадём на пустой экран.
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  /// Сброс фильтров и поиска с сохранением сортировки и размера страницы.
  CarQuery cleared() => CarQuery(
    sortField: sortField,
    sortAscending: sortAscending,
    size: size,
    includeDeleted: includeDeleted,
  );

  /// Щелчок по заголовку колонки: та же колонка меняет направление,
  /// другая — включается по возрастанию.
  CarQuery sortedBy(String field) => copyWith(
    sortField: field,
    sortAscending: field == sortField ? !sortAscending : true,
  );

  // Отличает «параметр не передан» от «передан null, сбросить фильтр».
  static const _unset = Object();

  /// В адрес попадают только значения, отличные от умолчаний,
  /// чтобы ссылка оставалась короткой.
  Map<String, String> toQueryParameters() => {
    if (search.isNotEmpty) 'search': search,
    if (brandId != null) 'brandId': '$brandId',
    if (fuel != null) 'fuel': fuel!.code,
    if (yearFrom != null) 'yearFrom': '$yearFrom',
    if (yearTo != null) 'yearTo': '$yearTo',
    if (clientId != null) 'clientId': '$clientId',
    if (mechanicId != null) 'mechanicId': '$mechanicId',
    if (sortField != defaultSort || !sortAscending)
      'sort': formatSort(sortField, sortAscending),
    if (page != 1) 'page': '$page',
    if (size != pageSizes.first) 'size': '$size',
    if (includeDeleted) 'deleted': '1',
  };

  factory CarQuery.fromQueryParameters(Map<String, String> params) {
    final sort = parseSort(
      params['sort'],
      allowed: sortFields,
      fallbackField: defaultSort,
    );
    return CarQuery(
      search: params['search']?.trim() ?? '',
      brandId: parseIdParam(params['brandId']),
      fuel: FuelType.fromCode(params['fuel']),
      yearFrom: parseIntParam(params['yearFrom']),
      yearTo: parseIntParam(params['yearTo']),
      clientId: parseIdParam(params['clientId']),
      mechanicId: parseIdParam(params['mechanicId']),
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
      path: '/cars',
      queryParameters: params.isEmpty ? null : params,
    ).toString();
  }

  @override
  bool operator ==(Object other) =>
      other is CarQuery &&
      other.search == search &&
      other.brandId == brandId &&
      other.fuel == fuel &&
      other.yearFrom == yearFrom &&
      other.yearTo == yearTo &&
      other.clientId == clientId &&
      other.mechanicId == mechanicId &&
      other.sortField == sortField &&
      other.sortAscending == sortAscending &&
      other.page == page &&
      other.size == size &&
      other.includeDeleted == includeDeleted;

  @override
  int get hashCode => Object.hash(
    search,
    brandId,
    fuel,
    yearFrom,
    yearTo,
    clientId,
    mechanicId,
    sortField,
    sortAscending,
    page,
    size,
    includeDeleted,
  );
}
