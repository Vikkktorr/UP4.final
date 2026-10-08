import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/breakpoints.dart';
import '../core/permissions.dart';
import '../core/formatting.dart';
import '../models/client.dart';
import '../models/club_card.dart';
import '../models/client_query.dart';
import '../state/auth_notifier.dart';
import '../state/client_list_notifier.dart';
import '../state/lookup_notifier.dart';
import '../widgets/debounced_text_field.dart';
import '../widgets/entity_card_list.dart';
import '../widgets/entity_table.dart';
import '../widgets/list_state_view.dart';
import '../widgets/list_toolbar.dart';
import '../widgets/pagination_bar.dart';

/// Список клиентов. Устроен так же, как список автомобилей: таблица,
/// карточки и пагинация — те же обобщённые виджеты с другими колонками.
class ClientListScreen extends StatefulWidget {
  const ClientListScreen({super.key, required this.query});

  final ClientQuery query;

  @override
  State<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends State<ClientListScreen> {
  static const _sortLabels = {
    'name': 'ФИО',
    'registeredAt': 'Дата регистрации',
    'discount': 'Скидка',
  };

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(ClientListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) _sync();
  }

  void _sync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ClientListNotifier>().applyQuery(widget.query);
    });
  }

  void _go(ClientQuery next) => context.go(next.toLocation());

  /// После изменений в клиентах обновляются подписи в списке автомобилей.
  void _refreshLookup() => context.read<LookupNotifier>().load();

  Future<void> _run(
    Future<void> Function() action,
    String done, {
    SnackBarAction? undo,
  }) async {
    try {
      await action();
      if (!mounted) return;
      _refreshLookup();
      showMessage(context, done, action: undo);
    } catch (e) {
      if (mounted) showMessage(context, '$e');
    }
  }

  Future<void> _softDelete(Client c) {
    final notifier = context.read<ClientListNotifier>();
    return _run(
      () => notifier.softDelete(c.id),
      'Клиент ${c.shortName} удалён',
      undo: SnackBarAction(
        label: 'Отменить',
        onPressed: () => notifier.restore(c.id),
      ),
    );
  }

  Future<void> _hardDelete(Client c) async {
    final notifier = context.read<ClientListNotifier>();
    final ok = await confirmAction(
      context,
      title: 'Удалить навсегда?',
      message:
          'Клиент ${c.fullName} будет стёрт без возможности '
          'восстановления.',
      confirmLabel: 'Удалить навсегда',
    );
    if (ok) await _run(() => notifier.hardDelete(c.id), 'Клиент стёрт');
  }

  Future<void> _deleteSelected() async {
    final notifier = context.read<ClientListNotifier>();
    final count = notifier.selected.length;
    final ok = await confirmAction(
      context,
      title: 'Удалить выбранных?',
      message:
          'Будет удалено $count '
          '${plural(count, 'клиент', 'клиента', 'клиентов')}. '
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

  List<Widget> _actions(Client c) => c.isDeleted
      ? [
          if (_can(Operation.restore))
            IconButton(
              tooltip: 'Восстановить',
              icon: const Icon(Icons.restore_from_trash),
              onPressed: () => _run(
                () => context.read<ClientListNotifier>().restore(c.id),
                'Клиент ${c.shortName} восстановлен',
              ),
            ),
          if (_can(Operation.hardDelete))
            IconButton(
              tooltip: 'Удалить навсегда',
              icon: const Icon(Icons.delete_forever),
              color: Theme.of(context).colorScheme.error,
              onPressed: () => _hardDelete(c),
            ),
        ]
      : [
          if (_can(Operation.editRecords))
            IconButton(
              tooltip: 'Изменить',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.go('/clients/${c.id}/edit'),
            ),
          if (_can(Operation.softDelete))
            IconButton(
              tooltip: 'Удалить',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _softDelete(c),
            ),
        ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final notifier = context.watch<ClientListNotifier>();
    final q = widget.query;
    final compact = screenSizeOf(context) == ScreenSize.compact;
    final page = notifier.page;

    return Title(
      title: 'Клиенты — Автосервис',
      color: Theme.of(context).colorScheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListHeader(
            title: 'Клиенты',
            total: page?.total,
            showDeleted: q.includeDeleted,
            onShowDeleted: auth.can(Operation.restore)
                ? (v) => _go(q.copyWith(includeDeleted: v))
                : null,
            onAdd: auth.can(Operation.editRecords)
                ? () => context.go('/clients/new')
                : null,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: compact ? double.infinity : 320,
                child: DebouncedTextField(
                  value: q.search,
                  label: 'Поиск',
                  hint: 'ФИО, телефон или почта',
                  icon: Icons.search,
                  onChanged: (v) => _go(q.copyWith(search: v)),
                ),
              ),
              SizedBox(
                width: compact ? double.infinity : 200,
                child: DropdownButtonFormField<CardLevel?>(
                  key: ValueKey('level-${q.level}'),
                  initialValue: q.level,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Клубная карта',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<CardLevel?>(
                      value: null,
                      child: Text('Любая'),
                    ),
                    for (final l in CardLevel.values)
                      DropdownMenuItem<CardLevel?>(
                        value: l,
                        child: Text(l.title),
                      ),
                  ],
                  onChanged: (v) => _go(q.copyWith(level: v)),
                ),
              ),
              // Ещё три критерия: персональная скидка и год, с которого
              // человек стал клиентом, — от и до.
              SizedBox(
                width: compact ? 150 : 130,
                child: DebouncedTextField(
                  value: q.discountFrom?.toString() ?? '',
                  label: 'Скидка от, %',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 2,
                  clearable: false,
                  onChanged: (v) =>
                      _go(q.copyWith(discountFrom: int.tryParse(v))),
                ),
              ),
              SizedBox(
                width: compact ? 150 : 130,
                child: DebouncedTextField(
                  value: q.sinceFrom?.toString() ?? '',
                  label: 'Клиент с, год',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 4,
                  clearable: false,
                  validator: _yearValidator,
                  onChanged: (v) => _go(q.copyWith(sinceFrom: int.tryParse(v))),
                ),
              ),
              SizedBox(
                width: compact ? 150 : 130,
                child: DebouncedTextField(
                  value: q.sinceTo?.toString() ?? '',
                  label: 'по, год',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 4,
                  clearable: false,
                  validator: _yearValidator,
                  onChanged: (v) => _go(q.copyWith(sinceTo: int.tryParse(v))),
                ),
              ),
              if (q.hasFilters)
                TextButton.icon(
                  onPressed: () => _go(q.cleared()),
                  icon: const Icon(Icons.filter_alt_off),
                  label: const Text('Сбросить'),
                ),
              if (compact)
                SortControl(
                  fields: _sortLabels,
                  field: q.sortField,
                  ascending: q.sortAscending,
                  onSort: (f) => _go(q.sortedBy(f)),
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
            child: ListStateView<Client>(
              state: notifier.state,
              onRetry: notifier.load,
              emptyTitle: 'Клиенты не найдены',
              emptyHint: q.hasFilters
                  ? 'Под условия отбора не подходит ни один клиент.'
                  : 'В базе пока нет клиентов.',
              onResetFilters: q.hasFilters ? () => _go(q.cleared()) : null,
              onFirstPage: () => _go(q.copyWith(page: 1)),
              builder: (page) => compact
                  ? _cards(page.items, notifier)
                  : _table(page.items, notifier),
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

  Widget _table(List<Client> clients, ClientListNotifier notifier) {
    final q = widget.query;
    return EntityTable<Client>(
      items: clients,
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
      onOpen: (c) => context.go('/clients/${c.id}'),
      isDeleted: (c) => c.isDeleted,
      actions: _actions,
      columns: [
        TableColumnSpec(
          label: 'ФИО',
          sortField: 'name',
          build: (c) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(c.fullName),
              if (c.isDeleted) ...[
                const SizedBox(width: 8),
                const DeletedBadge(),
              ],
            ],
          ),
        ),
        TableColumnSpec(label: 'Телефон', build: (c) => Text(c.phone)),
        TableColumnSpec(label: 'E-mail', build: (c) => Text(c.email)),
        TableColumnSpec(
          label: 'Карта',
          build: (c) => Text(
            c.card == null ? '—' : '${c.card!.number} · ${c.card!.level.title}',
          ),
        ),
        TableColumnSpec(
          label: 'Скидка',
          sortField: 'discount',
          numeric: true,
          build: (c) => Text(c.discount == 0 ? '—' : '${c.discount} %'),
        ),
        TableColumnSpec(
          label: 'Клиент с',
          sortField: 'registeredAt',
          build: (c) => Text(formatDate(c.registeredAt)),
        ),
      ],
    );
  }

  Widget _cards(List<Client> clients, ClientListNotifier notifier) {
    return EntityCardList<Client>(
      items: clients,
      idOf: (c) => c.id,
      selected: notifier.selected,
      onToggleSelect: _can(Operation.softDelete)
          ? notifier.toggleSelection
          : null,
      onOpen: (c) => context.go('/clients/${c.id}'),
      isDeleted: (c) => c.isDeleted,
      actions: _actions,
      title: (c) => Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [Text(c.fullName), if (c.isDeleted) const DeletedBadge()],
      ),
      subtitle: (c) => Text(
        '${c.phone}\n${c.email}\n'
        '${c.card == null ? 'Без карты' : 'Карта ${c.card!.number} · ${c.card!.level.title}'}'
        '${c.discount > 0 ? ' · скидка ${c.discount} %' : ''}',
      ),
    );
  }
}

/// Год из поля фильтра: четыре цифры, от 2000 до текущего.
String? _yearValidator(String value) {
  if (value.isEmpty) return null;
  final year = int.tryParse(value);
  final now = DateTime.now().year;
  if (year == null || value.length != 4) return 'Четыре цифры';
  if (year < 2000 || year > now) return '2000–$now';
  return null;
}
