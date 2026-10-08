import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/breakpoints.dart';
import '../core/permissions.dart';
import '../core/formatting.dart';
import '../models/entity.dart';
import '../models/entity_query.dart';
import '../state/auth_notifier.dart';
import '../state/entity_list_notifier.dart';
import '../widgets/debounced_text_field.dart';
import '../widgets/entity_card_list.dart';
import '../widgets/entity_table.dart';
import '../widgets/entity_form/form_spec.dart';
import '../widgets/list_state_view.dart';
import '../widgets/list_toolbar.dart';
import '../widgets/pagination_bar.dart';

/// Фильтр списка справочника — выпадающий список по одному параметру.
class ListFilter {
  const ListFilter({
    required this.key,
    required this.label,
    required this.allLabel,
    required this.options,
  });

  final String key;
  final String label;
  final String allLabel;
  final List<Option> options;
}

/// Общий экран списка для марок, мастеров и услуг.
///
/// Поиск, фильтр, сортировка, страницы, выделение, логическое
/// и физическое удаление работают так же, как у автомобилей и клиентов;
/// отличаются только колонки и подписи, они передаются параметрами.
class ReferenceListScreen<
  T extends Entity,
  N extends EntityListNotifier<T, EntityQuery>
>
    extends StatefulWidget {
  const ReferenceListScreen({
    super.key,
    required this.query,
    required this.title,
    required this.addLabel,
    required this.searchHint,
    required this.sortLabels,
    required this.columns,
    required this.cardTitle,
    required this.cardSubtitle,
    required this.labelOf,
    required this.nouns,
    this.filters = const [],
    this.hardDeleteNote,
  });

  final EntityQuery query;
  final String title;
  final String addLabel;
  final String searchHint;
  final Map<String, String> sortLabels;
  final List<TableColumnSpec<T>> columns;
  final String Function(T item) cardTitle;
  final String Function(T item) cardSubtitle;

  /// Как назвать запись в сообщениях: «Lada», «Громов В. А.».
  final String Function(T item) labelOf;

  /// Формы слова для «Будет удалено 5 марок»: (одна, две, пять).
  final (String, String, String) nouns;
  final List<ListFilter> filters;

  /// Что ещё произойдёт при физическом удалении — для текста подтверждения.
  final String Function(T item)? hardDeleteNote;

  @override
  State<ReferenceListScreen<T, N>> createState() =>
      _ReferenceListScreenState<T, N>();
}

class _ReferenceListScreenState<
  T extends Entity,
  N extends EntityListNotifier<T, EntityQuery>
>
    extends State<ReferenceListScreen<T, N>> {
  EntityQuery get q => widget.query;
  String get _base => q.spec.path;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(ReferenceListScreen<T, N> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) _sync();
  }

  void _sync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<N>().applyQuery(widget.query);
    });
  }

  void _go(EntityQuery next) => context.go(next.toLocation());

  Future<void> _run(
    Future<void> Function() action,
    String done, {
    SnackBarAction? undo,
  }) async {
    try {
      await action();
      if (mounted) showMessage(context, done, action: undo);
    } catch (e) {
      // Например, отказ удалить марку, на которую ссылаются автомобили.
      if (mounted) showMessage(context, '$e');
    }
  }

  Future<void> _softDelete(T item) {
    final notifier = context.read<N>();
    return _run(
      () => notifier.softDelete(item.id),
      '«${widget.labelOf(item)}» удалено',
      undo: SnackBarAction(
        label: 'Отменить',
        onPressed: () => notifier.restore(item.id),
      ),
    );
  }

  Future<void> _hardDelete(T item) async {
    final notifier = context.read<N>();
    final note = widget.hardDeleteNote?.call(item);
    final ok = await confirmAction(
      context,
      title: 'Удалить навсегда?',
      message:
          '«${widget.labelOf(item)}» будет стёрто без возможности '
          'восстановления.${note == null ? '' : '\n\n$note'}',
      confirmLabel: 'Удалить навсегда',
    );
    if (ok) {
      await _run(
        () => notifier.hardDelete(item.id),
        '«${widget.labelOf(item)}» стёрто',
      );
    }
  }

  Future<void> _deleteSelected() async {
    final notifier = context.read<N>();
    final count = notifier.selected.length;
    final (one, few, many) = widget.nouns;
    final ok = await confirmAction(
      context,
      title: 'Удалить выбранные?',
      message:
          'Будет удалено $count ${plural(count, one, few, many)}. '
          'Их можно будет восстановить, включив показ удалённых.',
      confirmLabel: 'Удалить',
    );
    if (ok) {
      await _run(notifier.deleteSelected, 'Удалено записей: $count');
    }
  }

  // Недоступные роли кнопки не показываются. Это уборка интерфейса:
  // запрос всё равно проверит сервер.
  bool _can(Operation operation) =>
      Provider.of<AuthNotifier>(context, listen: false).can(operation);

  List<Widget> _actions(T item) => item.isDeleted
      ? [
          if (_can(Operation.restore))
            IconButton(
              tooltip: 'Восстановить',
              icon: const Icon(Icons.restore_from_trash),
              onPressed: () => _run(
                () => context.read<N>().restore(item.id),
                '«${widget.labelOf(item)}» восстановлено',
              ),
            ),
          if (_can(Operation.hardDelete))
            IconButton(
              tooltip: 'Удалить навсегда',
              icon: const Icon(Icons.delete_forever),
              color: Theme.of(context).colorScheme.error,
              onPressed: () => _hardDelete(item),
            ),
        ]
      : [
          if (_can(Operation.editRecords))
            IconButton(
              tooltip: 'Изменить',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.go('$_base/${item.id}/edit'),
            ),
          if (_can(Operation.softDelete))
            IconButton(
              tooltip: 'Удалить',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _softDelete(item),
            ),
        ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final notifier = context.watch<N>();
    final compact = screenSizeOf(context) == ScreenSize.compact;
    final page = notifier.page;

    return Title(
      title: '${widget.title} — Автосервис',
      color: Theme.of(context).colorScheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListHeader(
            title: widget.title,
            total: page?.total,
            showDeleted: q.includeDeleted,
            onShowDeleted: auth.can(Operation.restore)
                ? (v) => _go(q.copyWith(includeDeleted: v))
                : null,
            onAdd: auth.can(Operation.editRecords)
                ? () => context.go('$_base/new')
                : null,
            addLabel: widget.addLabel,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: compact ? double.infinity : 300,
                child: DebouncedTextField(
                  value: q.search,
                  label: 'Поиск',
                  hint: widget.searchHint,
                  icon: Icons.search,
                  onChanged: (v) => _go(q.copyWith(search: v)),
                ),
              ),
              for (final f in widget.filters)
                SizedBox(
                  width: compact ? double.infinity : 200,
                  child: DropdownButtonFormField<String?>(
                    key: ValueKey(
                      '${f.key}-${q.filter(f.key)}-${f.options.length}',
                    ),
                    initialValue:
                        f.options.any((o) => o.value == q.filter(f.key))
                        ? q.filter(f.key)
                        : null,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: f.label,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(f.allLabel),
                      ),
                      for (final o in f.options)
                        DropdownMenuItem<String?>(
                          value: o.value as String,
                          child: Text(o.label),
                        ),
                    ],
                    onChanged: (v) => _go(q.withFilter(f.key, v)),
                  ),
                ),
              if (compact)
                SortControl(
                  fields: widget.sortLabels,
                  field: q.sortField,
                  ascending: q.sortAscending,
                  onSort: (f) => _go(q.sortedBy(f)),
                ),
              if (q.hasFilters)
                TextButton.icon(
                  onPressed: () => _go(q.cleared()),
                  icon: const Icon(Icons.filter_alt_off),
                  label: const Text('Сбросить'),
                ),
            ],
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
            child: ListStateView<T>(
              state: notifier.state,
              onRetry: notifier.load,
              emptyTitle: 'Ничего не найдено',
              emptyHint: q.hasFilters
                  ? 'Под условия отбора не подходит ни одна запись.'
                  : 'Записей пока нет.',
              onResetFilters: q.hasFilters ? () => _go(q.cleared()) : null,
              onFirstPage: () => _go(q.copyWith(page: 1)),
              builder: (page) => compact
                  ? EntityCardList<T>(
                      items: page.items,
                      idOf: (e) => e.id,
                      selected: notifier.selected,
                      onToggleSelect: _can(Operation.softDelete)
                          ? notifier.toggleSelection
                          : null,
                      onOpen: (e) => context.go('$_base/${e.id}'),
                      isDeleted: (e) => e.isDeleted,
                      // Клиенту действия недоступны — колонки «Действия» нет.
                      actions: _can(Operation.editRecords) ? _actions : null,
                      title: (e) => Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(widget.cardTitle(e)),
                          if (e.isDeleted) const DeletedBadge(),
                        ],
                      ),
                      subtitle: (e) => Text(widget.cardSubtitle(e)),
                    )
                  : EntityTable<T>(
                      items: page.items,
                      idOf: (e) => e.id,
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
                      onOpen: (e) => context.go('$_base/${e.id}'),
                      isDeleted: (e) => e.isDeleted,
                      // Клиенту действия недоступны — колонки «Действия» нет.
                      actions: _can(Operation.editRecords) ? _actions : null,
                      columns: widget.columns,
                    ),
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
}

/// Первая колонка с названием и отметкой «удалена».
TableColumnSpec<T> nameColumn<T extends Entity>(
  String label,
  String Function(T) text, {
  String? sortField,
}) => TableColumnSpec<T>(
  label: label,
  sortField: sortField,
  build: (e) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(text(e), style: const TextStyle(fontWeight: FontWeight.w600)),
      if (e.isDeleted) ...[const SizedBox(width: 8), const DeletedBadge()],
    ],
  ),
);
