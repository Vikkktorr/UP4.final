import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/breakpoints.dart';
import '../core/permissions.dart';
import '../core/formatting.dart';
import '../models/car.dart';
import '../models/car_query.dart';
import '../models/fuel_type.dart';
import '../state/auth_notifier.dart';
import '../state/car_list_notifier.dart';
import '../state/lookup_notifier.dart';
import '../widgets/debounced_text_field.dart';
import '../widgets/entity_card_list.dart';
import '../widgets/entity_table.dart';
import '../widgets/list_state_view.dart';
import '../widgets/list_toolbar.dart';
import '../widgets/pagination_bar.dart';

/// Список автомобилей.
///
/// Условия отбора приходят из адреса в [query]. Экран их не хранит: любое
/// изменение фильтра — это переход на новый адрес, после которого маршрут
/// заново строит экран с новым [query]. Поэтому ссылка восстанавливает
/// список целиком, а кнопка «назад» возвращает прежние условия.
class CarListScreen extends StatefulWidget {
  const CarListScreen({super.key, required this.query});

  final CarQuery query;

  @override
  State<CarListScreen> createState() => _CarListScreenState();
}

class _CarListScreenState extends State<CarListScreen> {
  static const _sortLabels = {
    'plate': 'Госномер',
    'brand': 'Марка и модель',
    'year': 'Год выпуска',
    'mileage': 'Пробег',
  };

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(CarListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) _sync();
  }

  void _sync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CarListNotifier>().applyQuery(widget.query);
      final lookup = context.read<LookupNotifier>();
      if (!lookup.loaded) lookup.load();
    });
  }

  void _go(CarQuery next) => context.go(next.toLocation());

  Future<void> _softDelete(Car car) async {
    final notifier = context.read<CarListNotifier>();
    try {
      await notifier.softDelete(car.id);
      if (!mounted) return;
      showMessage(
        context,
        'Автомобиль ${car.plate} удалён',
        action: SnackBarAction(
          label: 'Отменить',
          onPressed: () => notifier.restore(car.id),
        ),
      );
    } catch (e) {
      if (mounted) showMessage(context, '$e');
    }
  }

  Future<void> _restore(Car car) async {
    try {
      await context.read<CarListNotifier>().restore(car.id);
      if (mounted) showMessage(context, 'Автомобиль ${car.plate} восстановлен');
    } catch (e) {
      if (mounted) showMessage(context, '$e');
    }
  }

  Future<void> _hardDelete(Car car) async {
    final notifier = context.read<CarListNotifier>();
    final ok = await confirmAction(
      context,
      title: 'Удалить навсегда?',
      message:
          'Автомобиль ${car.plate} будет стёрт без возможности '
          'восстановления.',
      confirmLabel: 'Удалить навсегда',
    );
    if (!ok) return;
    try {
      await notifier.hardDelete(car.id);
      if (mounted) showMessage(context, 'Автомобиль ${car.plate} стёрт');
    } catch (e) {
      if (mounted) showMessage(context, '$e');
    }
  }

  Future<void> _deleteSelected() async {
    final notifier = context.read<CarListNotifier>();
    final count = notifier.selected.length;
    final ok = await confirmAction(
      context,
      title: 'Удалить выбранные?',
      message:
          'Будет удалено $count '
          '${plural(count, 'автомобиль', 'автомобиля', 'автомобилей')}. '
          'Их можно будет восстановить, включив показ удалённых.',
      confirmLabel: 'Удалить',
    );
    if (!ok) return;
    try {
      final deleted = await notifier.deleteSelected();
      if (mounted) showMessage(context, 'Удалено записей: $deleted');
    } catch (e) {
      if (mounted) showMessage(context, '$e');
    }
  }

  // Недоступные роли кнопки не показываются. Это уборка интерфейса:
  // запрос всё равно проверит сервер.
  bool _can(Operation operation) =>
      Provider.of<AuthNotifier>(context, listen: false).can(operation);

  List<Widget> _actions(Car car) => car.isDeleted
      ? [
          if (_can(Operation.restore))
            IconButton(
              tooltip: 'Восстановить',
              icon: const Icon(Icons.restore_from_trash),
              onPressed: () => _restore(car),
            ),
          if (_can(Operation.hardDelete))
            IconButton(
              tooltip: 'Удалить навсегда',
              icon: const Icon(Icons.delete_forever),
              color: Theme.of(context).colorScheme.error,
              onPressed: () => _hardDelete(car),
            ),
        ]
      : [
          if (_can(Operation.editRecords))
            IconButton(
              tooltip: 'Изменить',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.go('/cars/${car.id}/edit'),
            ),
          if (_can(Operation.softDelete))
            IconButton(
              tooltip: 'Удалить',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _softDelete(car),
            ),
        ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final notifier = context.watch<CarListNotifier>();
    final lookup = context.watch<LookupNotifier>();
    final q = widget.query;
    final compact = screenSizeOf(context) == ScreenSize.compact;
    final page = notifier.page;

    return Title(
      title: 'Автомобили — Автосервис',
      color: Theme.of(context).colorScheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListHeader(
            title: 'Автомобили',
            total: page?.total,
            showDeleted: q.includeDeleted,
            onShowDeleted: auth.can(Operation.restore)
                ? (v) => _go(q.copyWith(includeDeleted: v))
                : null,
            onAdd: auth.can(Operation.editRecords)
                ? () => context.go('/cars/new')
                : null,
          ),
          const SizedBox(height: 12),
          _CarFilters(
            query: q,
            lookup: lookup,
            compact: compact,
            sortLabels: _sortLabels,
            onChanged: _go,
          ),
          if (notifier.hasSelection && auth.can(Operation.softDelete)) ...[
            const SizedBox(height: 8),
            SelectionBar(
              count: notifier.selected.length,
              onDelete: _deleteSelected,
              onClear: notifier.clearSelection,
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: ListStateView<Car>(
              state: notifier.state,
              onRetry: () {
                notifier.load();
                if (!lookup.loaded) lookup.load();
              },
              emptyTitle: 'Автомобили не найдены',
              emptyHint: q.hasFilters
                  ? 'Под условия отбора не подходит ни один автомобиль.'
                  : 'В базе пока нет автомобилей.',
              onResetFilters: q.hasFilters ? () => _go(q.cleared()) : null,
              onFirstPage: () => _go(q.copyWith(page: 1)),
              builder: (page) => compact
                  ? _cards(page.items, notifier, lookup)
                  : _table(page.items, notifier, lookup),
            ),
          ),
          if (page != null && page.total > 0)
            PaginationBar(
              page: page,
              onPage: (p) => _go(q.copyWith(page: p)),
              onSize: (s) => _go(q.copyWith(size: s)),
            ),
        ],
      ),
    );
  }

  Widget _table(
    List<Car> cars,
    CarListNotifier notifier,
    LookupNotifier lookup,
  ) {
    final q = widget.query;
    return EntityTable<Car>(
      items: cars,
      idOf: (c) => c.id,
      selected: notifier.selected,
      onToggleSelect: _can(Operation.softDelete)
          ? notifier.toggleSelection
          : null,
      onSelectAll: _can(Operation.softDelete)
          ? notifier.setPageSelection
          : null,
      sortField: q.sortField,
      sortAscending: q.sortAscending,
      onSort: (field) => _go(q.sortedBy(field)),
      onOpen: (c) => context.go('/cars/${c.id}'),
      isDeleted: (c) => c.isDeleted,
      actions: _actions,
      columns: [
        TableColumnSpec(
          label: 'Госномер',
          sortField: 'plate',
          build: (c) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                c.plate,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (c.isDeleted) ...[
                const SizedBox(width: 8),
                const DeletedBadge(),
              ],
            ],
          ),
        ),
        TableColumnSpec(
          label: 'Марка и модель',
          sortField: 'brand',
          build: (c) => Text(lookup.carTitle(c.modelId)),
        ),
        TableColumnSpec(
          label: 'VIN',
          build: (c) => Text(
            c.vin,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ),
        TableColumnSpec(
          label: 'Год',
          sortField: 'year',
          numeric: true,
          build: (c) => Text('${c.year}'),
        ),
        TableColumnSpec(
          label: 'Пробег',
          sortField: 'mileage',
          numeric: true,
          build: (c) => Text(formatMileage(c.mileage)),
        ),
        TableColumnSpec(label: 'Двигатель', build: (c) => Text(c.fuel.title)),
        TableColumnSpec(
          label: 'Владелец',
          build: (c) => Text(lookup.clientName(c.clientId)),
        ),
      ],
    );
  }

  Widget _cards(
    List<Car> cars,
    CarListNotifier notifier,
    LookupNotifier lookup,
  ) {
    return EntityCardList<Car>(
      items: cars,
      idOf: (c) => c.id,
      selected: notifier.selected,
      onToggleSelect: _can(Operation.softDelete)
          ? notifier.toggleSelection
          : null,
      onOpen: (c) => context.go('/cars/${c.id}'),
      isDeleted: (c) => c.isDeleted,
      actions: _actions,
      title: (c) => Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(c.plate, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(lookup.carTitle(c.modelId)),
          if (c.isDeleted) const DeletedBadge(),
        ],
      ),
      subtitle: (c) => Text(
        '${c.year} г. · ${formatMileage(c.mileage)} · ${c.fuel.title}\n'
        'Владелец: ${lookup.clientName(c.clientId)}',
      ),
    );
  }
}

/// Панель фильтров. Wrap переносит поля на новую строку; на узком окне
/// всё, кроме поиска, спрятано под кнопку «Фильтры», чтобы список не
/// уезжал за нижний край экрана.
class _CarFilters extends StatefulWidget {
  const _CarFilters({
    required this.query,
    required this.lookup,
    required this.compact,
    required this.sortLabels,
    required this.onChanged,
  });

  final CarQuery query;
  final LookupNotifier lookup;
  final bool compact;
  final Map<String, String> sortLabels;
  final ValueChanged<CarQuery> onChanged;

  @override
  State<_CarFilters> createState() => _CarFiltersState();
}

class _CarFiltersState extends State<_CarFilters> {
  /// Раскрыта ли панель на узком окне. Локальное состояние виджета —
  /// тот случай, когда setState уместен.
  bool _expanded = false;

  static final _maxYear = DateTime.now().year + 1;

  static String? _yearValidator(String value) {
    if (value.isEmpty) return null;
    final year = int.tryParse(value);
    if (year == null || value.length != 4) return 'Четыре цифры';
    if (year < 1950 || year > _maxYear) return '1950–$_maxYear';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.query;
    final lookup = widget.lookup;
    final compact = widget.compact;
    final onChanged = widget.onChanged;
    final owner = q.clientId == null ? null : lookup.client(q.clientId!);

    Widget sized(double width, Widget child) =>
        SizedBox(width: compact ? double.infinity : width, child: child);
    Widget half(Widget child) =>
        SizedBox(width: compact ? 150 : 110, child: child);

    final search = DebouncedTextField(
      value: q.search,
      label: 'Поиск',
      hint: 'Госномер или VIN',
      icon: Icons.search,
      onChanged: (v) => onChanged(q.copyWith(search: v)),
    );

    final filters = <Widget>[
      sized(
        190,
        DropdownButtonFormField<String?>(
          // Ключ по значению: при смене адреса поле пересоздаётся
          // и показывает значение из адреса, а не прежнее.
          key: ValueKey('brand-${q.brandId}-${lookup.brands.length}'),
          initialValue: lookup.brands.any((b) => b.id == q.brandId)
              ? q.brandId
              : null,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Марка',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Все марки'),
            ),
            for (final brand in lookup.brands)
              DropdownMenuItem<String?>(
                value: brand.id,
                child: Text(brand.name),
              ),
          ],
          onChanged: (v) => onChanged(q.copyWith(brandId: v)),
        ),
      ),
      sized(
        170,
        DropdownButtonFormField<FuelType?>(
          key: ValueKey('fuel-${q.fuel}'),
          initialValue: q.fuel,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Двигатель',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<FuelType?>(
              value: null,
              child: Text('Любой'),
            ),
            for (final fuel in FuelType.values)
              DropdownMenuItem<FuelType?>(value: fuel, child: Text(fuel.title)),
          ],
          onChanged: (v) => onChanged(q.copyWith(fuel: v)),
        ),
      ),
      half(
        DebouncedTextField(
          value: q.yearFrom?.toString() ?? '',
          label: 'Год от',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 4,
          clearable: false,
          validator: _yearValidator,
          onChanged: (v) => onChanged(q.copyWith(yearFrom: int.tryParse(v))),
        ),
      ),
      half(
        DebouncedTextField(
          value: q.yearTo?.toString() ?? '',
          label: 'Год до',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 4,
          clearable: false,
          validator: _yearValidator,
          onChanged: (v) => onChanged(q.copyWith(yearTo: int.tryParse(v))),
        ),
      ),
      if (q.clientId != null)
        InputChip(
          avatar: const Icon(Icons.person_outline, size: 18),
          label: Text('Владелец: ${owner?.shortName ?? 'клиент'}'),
          onDeleted: () => onChanged(q.copyWith(clientId: null)),
        ),
      if (q.mechanicId != null)
        InputChip(
          avatar: const Icon(Icons.engineering_outlined, size: 18),
          label: Text('Мастер: ${lookup.mechanicName(q.mechanicId!)}'),
          onDeleted: () => onChanged(q.copyWith(mechanicId: null)),
        ),
      if (compact)
        SortControl(
          fields: widget.sortLabels,
          field: q.sortField,
          ascending: q.sortAscending,
          onSort: (f) => onChanged(q.sortedBy(f)),
        ),
      if (q.hasFilters)
        TextButton.icon(
          onPressed: () => onChanged(q.cleared()),
          icon: const Icon(Icons.filter_alt_off),
          label: const Text('Сбросить'),
        ),
    ];

    if (!compact) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(width: 300, child: search),
          ...filters,
        ],
      );
    }

    final active = [
      q.brandId,
      q.fuel,
      q.yearFrom,
      q.yearTo,
      q.clientId,
      q.mechanicId,
    ].where((v) => v != null).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: search),
            const SizedBox(width: 8),
            Badge(
              isLabelVisible: active > 0,
              label: Text('$active'),
              child: IconButton.filledTonal(
                tooltip: _expanded ? 'Скрыть фильтры' : 'Фильтры и сортировка',
                isSelected: _expanded,
                icon: const Icon(Icons.tune),
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
            ),
          ],
        ),
        if (_expanded) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: filters,
          ),
        ],
      ],
    );
  }
}
