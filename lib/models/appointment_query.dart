import '../core/query_params.dart';
import 'appointment.dart';
import 'entity.dart';

/// Условия отбора списка записей на обслуживание. Все условия отражаются
/// в адресе: `/appointments?status=planned&mechanicId=…&from=2026-10-01`.
class AppointmentQuery implements PagedQuery {
  /// Поиск по госномеру автомобиля.
  final String search;
  final AppointmentStatus? status;
  final String? mechanicId;
  final String? carId;

  /// Начало записи — с этого дня и по этот день включительно.
  final DateTime? from;
  final DateTime? to;
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

  static const sortFields = {'starts', 'total'};
  static const defaultSort = 'starts';

  /// Сначала новые записи.
  static const defaultAscending = false;

  const AppointmentQuery({
    this.search = '',
    this.status,
    this.mechanicId,
    this.carId,
    this.from,
    this.to,
    this.sortField = defaultSort,
    this.sortAscending = defaultAscending,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  });

  bool get hasFilters =>
      search.isNotEmpty ||
      status != null ||
      mechanicId != null ||
      carId != null ||
      from != null ||
      to != null;

  static const _unset = Object();

  AppointmentQuery copyWith({
    String? search,
    Object? status = _unset,
    Object? mechanicId = _unset,
    Object? carId = _unset,
    Object? from = _unset,
    Object? to = _unset,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    return AppointmentQuery(
      search: search ?? this.search,
      status: status == _unset ? this.status : status as AppointmentStatus?,
      mechanicId: mechanicId == _unset
          ? this.mechanicId
          : mechanicId as String?,
      carId: carId == _unset ? this.carId : carId as String?,
      from: from == _unset ? this.from : from as DateTime?,
      to: to == _unset ? this.to : to as DateTime?,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  AppointmentQuery cleared() => AppointmentQuery(
    sortField: sortField,
    sortAscending: sortAscending,
    size: size,
    includeDeleted: includeDeleted,
  );

  AppointmentQuery sortedBy(String field) => copyWith(
    sortField: field,
    sortAscending: field == sortField ? !sortAscending : true,
  );

  Map<String, String> toQueryParameters() => {
    if (search.isNotEmpty) 'search': search,
    if (status != null) 'status': status!.code,
    if (mechanicId != null) 'mechanicId': mechanicId!,
    if (carId != null) 'carId': carId!,
    if (from != null) 'from': formatDateParam(from!),
    if (to != null) 'to': formatDateParam(to!),
    if (sortField != defaultSort || sortAscending != defaultAscending)
      'sort': formatSort(sortField, sortAscending),
    if (page != 1) 'page': '$page',
    if (size != pageSizes.first) 'size': '$size',
    if (includeDeleted) 'deleted': '1',
  };

  factory AppointmentQuery.fromQueryParameters(Map<String, String> params) {
    final sort = params['sort'] == null
        ? (field: defaultSort, ascending: defaultAscending)
        : parseSort(
            params['sort'],
            allowed: sortFields,
            fallbackField: defaultSort,
          );
    return AppointmentQuery(
      search: params['search']?.trim() ?? '',
      status: AppointmentStatus.fromCode(params['status']),
      mechanicId: parseIdParam(params['mechanicId']),
      carId: parseIdParam(params['carId']),
      from: parseDateParam(params['from']),
      to: parseDateParam(params['to']),
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
      path: '/appointments',
      queryParameters: params.isEmpty ? null : params,
    ).toString();
  }

  @override
  bool operator ==(Object other) =>
      other is AppointmentQuery &&
      other.search == search &&
      other.status == status &&
      other.mechanicId == mechanicId &&
      other.carId == carId &&
      other.from == from &&
      other.to == to &&
      other.sortField == sortField &&
      other.sortAscending == sortAscending &&
      other.page == page &&
      other.size == size &&
      other.includeDeleted == includeDeleted;

  @override
  int get hashCode => Object.hash(
    search,
    status,
    mechanicId,
    carId,
    from,
    to,
    sortField,
    sortAscending,
    page,
    size,
    includeDeleted,
  );
}
