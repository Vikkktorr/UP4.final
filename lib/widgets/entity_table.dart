import 'package:flutter/material.dart';

class TableColumnSpec<T> {
  final String label;

  final String? sortField;
  final bool numeric;
  final Widget Function(T item) build;

  const TableColumnSpec({
    required this.label,
    required this.build,
    this.sortField,
    this.numeric = false,
  });
}

class EntityTable<T> extends StatelessWidget {
  final List<TableColumnSpec<T>> columns;
  final List<T> items;
  final String Function(T item) idOf;
  final Set<String> selected;
  final ValueChanged<String>? onToggleSelect;
  final ValueChanged<bool>? onSelectAll;
  final String? sortField;
  final bool sortAscending;
  final void Function(String field)? onSort;
  final ValueChanged<T>? onOpen;
  final List<Widget> Function(T item)? actions;
  final bool Function(T item)? isDeleted;

  const EntityTable({
    super.key,
    required this.columns,
    required this.items,
    required this.idOf,
    this.selected = const {},
    this.onToggleSelect,
    this.onSelectAll,
    this.sortField,
    this.sortAscending = true,
    this.onSort,
    this.onOpen,
    this.actions,
    this.isDeleted,
  });

  static const double _cellMaxWidth = 320;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortIndex = columns.indexWhere(
      (c) => c.sortField != null && c.sortField == sortField,
    );

    final table = DataTable(
      showCheckboxColumn: onToggleSelect != null,
      // Стрелка направления рисуется в колонке с этим индексом.
      sortColumnIndex: sortIndex == -1 ? null : sortIndex,
      sortAscending: sortAscending,
      onSelectAll: onSelectAll == null ? null : (v) => onSelectAll!(v ?? false),
      headingTextStyle: theme.textTheme.titleSmall,
      columnSpacing: 24,
      horizontalMargin: 12,
      columns: [
        for (final column in columns)
          DataColumn(
            label: Text(column.label),
            numeric: column.numeric,
            onSort: column.sortField == null || onSort == null
                ? null
                : (_, _) => onSort!(column.sortField!),
          ),
        if (actions != null) const DataColumn(label: Text('Действия')),
      ],
      rows: [for (final item in items) _row(context, item)],
    );

    return TwoWayScroll(child: table);
  }

  DataRow _row(BuildContext context, T item) {
    final id = idOf(item);
    final deleted = isDeleted?.call(item) ?? false;
    final colors = Theme.of(context).colorScheme;

    DataCell cell(Widget child) {
      // Длинное значение обрезается многоточием, а не раздвигает таблицу.
      final limited = ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _cellMaxWidth),
        child: DefaultTextStyle.merge(
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          child: child,
        ),
      );
      return DataCell(
        // Удалённая запись приглушена, но остаётся читаемой.
        deleted ? Opacity(opacity: 0.55, child: limited) : limited,
        onTap: onOpen == null ? null : () => onOpen!(item),
      );
    }

    return DataRow(
      key: ValueKey(id),
      selected: selected.contains(id),
      onSelectChanged: onToggleSelect == null
          ? null
          : (_) => onToggleSelect!(id),
      color: deleted
          ? WidgetStatePropertyAll(
              colors.errorContainer.withValues(alpha: 0.35),
            )
          : null,
      cells: [
        for (final column in columns) cell(column.build(item)),
        if (actions != null)
          DataCell(
            Row(mainAxisSize: MainAxisSize.min, children: actions!(item)),
          ),
      ],
    );
  }
}

/// Прокрутка по обеим осям с видимыми полосами.
///
/// DataTable сам не прокручивается и не сжимается: на узком окне он вылез
/// бы за край. minWidth растягивает таблицу на всю ширину широкого окна,
/// чтобы она не жалась к левому краю.
class TwoWayScroll extends StatefulWidget {
  const TwoWayScroll({super.key, required this.child});

  final Widget child;

  @override
  State<TwoWayScroll> createState() => _TwoWayScrollState();
}

class _TwoWayScrollState extends State<TwoWayScroll> {
  final _vertical = ScrollController();
  final _horizontal = ScrollController();

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Scrollbar(
        controller: _vertical,
        child: SingleChildScrollView(
          controller: _vertical,
          child: Scrollbar(
            controller: _horizontal,
            thumbVisibility: true,
            // Полоса горизонтальной прокрутки должна реагировать только
            // на свою прокрутку, а не на вертикальную снаружи.
            notificationPredicate: (n) => n.depth == 0,
            child: SingleChildScrollView(
              controller: _horizontal,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
