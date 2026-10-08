import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/breakpoints.dart';
import '../core/formatting.dart';
import '../core/permissions.dart';
import '../models/appointment.dart';
import '../models/appointment_query.dart';
import '../repositories/appointment_repository.dart';
import '../state/appointment_list_notifier.dart';
import '../state/auth_notifier.dart';
import '../state/detail_notifier.dart';
import '../state/lookup_notifier.dart';
import '../widgets/debounced_text_field.dart';
import '../widgets/detail_view.dart';
import '../widgets/entity_card_list.dart';
import '../widgets/entity_table.dart';
import '../widgets/list_state_view.dart';
import '../widgets/list_toolbar.dart';
import '../widgets/pagination_bar.dart';

/// Записи на обслуживание: /appointments. Мастер и администратор.
///
/// Отбор — по госномеру, статусу, мастеру и датам; всё отражается в адресе.
class AppointmentListScreen extends StatefulWidget {
  const AppointmentListScreen({super.key, required this.query});

  final AppointmentQuery query;

  @override
  State<AppointmentListScreen> createState() => _AppointmentListScreenState();
}

class _AppointmentListScreenState extends State<AppointmentListScreen> {
  static const _sortLabels = {'starts': 'Начало', 'total': 'Сумма'};

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(AppointmentListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) _sync();
  }

  void _sync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AppointmentListNotifier>().applyQuery(widget.query);
      }
    });
  }

  void _go(AppointmentQuery next) => context.go(next.toLocation());

  bool _can(Operation operation) =>
      Provider.of<AuthNotifier>(context, listen: false).can(operation);

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (mounted) showMessage(context, done);
    } catch (e) {
      if (mounted) showMessage(context, '$e');
    }
  }

  List<Widget> _actions(Appointment a) {
    final notifier = context.read<AppointmentListNotifier>();
    return a.isDeleted
        ? [
            if (_can(Operation.restore))
              IconButton(
                tooltip: 'Восстановить',
                icon: const Icon(Icons.restore_from_trash),
                onPressed: () =>
                    _run(() => notifier.restore(a.id), 'Запись восстановлена'),
              ),
            if (_can(Operation.hardDelete))
              IconButton(
                tooltip: 'Удалить навсегда',
                icon: const Icon(Icons.delete_forever),
                color: Theme.of(context).colorScheme.error,
                onPressed: () async {
                  final ok = await confirmAction(
                    context,
                    title: 'Удалить навсегда?',
                    message:
                        'Запись будет стёрта без возможности восстановления.',
                    confirmLabel: 'Удалить навсегда',
                  );
                  if (ok) {
                    await _run(
                      () => notifier.hardDelete(a.id),
                      'Запись стёрта',
                    );
                  }
                },
              ),
          ]
        : [
            IconButton(
              tooltip: 'Изменить',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.go('/appointments/${a.id}/edit'),
            ),
            IconButton(
              tooltip: 'Удалить',
              icon: const Icon(Icons.delete_outline),
              onPressed: () =>
                  _run(() => notifier.softDelete(a.id), 'Запись удалена'),
            ),
          ];
  }

  Future<void> _deleteSelected() async {
    final notifier = context.read<AppointmentListNotifier>();
    final count = notifier.selected.length;
    final ok = await confirmAction(
      context,
      title: 'Удалить выбранные?',
      message:
          'Будет удалено $count ${plural(count, 'запись', 'записи', 'записей')}. '
          'Их можно будет восстановить, включив показ удалённых.',
      confirmLabel: 'Удалить',
    );
    if (ok) await _run(notifier.deleteSelected, 'Удалено записей: $count');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final notifier = context.watch<AppointmentListNotifier>();
    final lookup = context.watch<LookupNotifier>();
    final q = widget.query;
    final compact = screenSizeOf(context) == ScreenSize.compact;
    final page = notifier.page;

    String carLabel(Appointment a) => a.car == null
        ? 'Автомобиль'
        : '${a.car!.plate} · ${lookup.carTitle(a.car!.modelId)}';
    String when(Appointment a) =>
        '${formatDateTime(a.startsAt)}–${formatTime(a.endsAt ?? a.startsAt)}';

    return Title(
      title: 'Записи — Автосервис',
      color: Theme.of(context).colorScheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListHeader(
            title: 'Записи на обслуживание',
            total: page?.total,
            showDeleted: q.includeDeleted,
            onShowDeleted: auth.can(Operation.restore)
                ? (v) => _go(q.copyWith(includeDeleted: v))
                : null,
            onAdd: () => context.go('/appointments/new'),
            addLabel: 'Записать',
          ),
          const SizedBox(height: 12),
          _Filters(
            query: q,
            lookup: lookup,
            compact: compact,
            sortLabels: _sortLabels,
            onChanged: _go,
          ),
          if (notifier.hasSelection) ...[
            const SizedBox(height: 8),
            SelectionBar(
              count: notifier.selected.length,
              onDelete: _deleteSelected,
              onClear: notifier.clearSelection,
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: ListStateView<Appointment>(
              state: notifier.state,
              onRetry: notifier.load,
              emptyTitle: 'Записей не найдено',
              emptyHint: q.hasFilters
                  ? 'Под условия отбора не подходит ни одна запись.'
                  : 'Записей на обслуживание пока нет.',
              onResetFilters: q.hasFilters ? () => _go(q.cleared()) : null,
              onFirstPage: () => _go(q.copyWith(page: 1)),
              builder: (page) => compact
                  ? EntityCardList<Appointment>(
                      items: page.items,
                      idOf: (a) => a.id,
                      selected: notifier.selected,
                      onToggleSelect: notifier.toggleSelection,
                      onOpen: (a) => context.go('/appointments/${a.id}'),
                      isDeleted: (a) => a.isDeleted,
                      actions: _actions,
                      title: (a) => Text(carLabel(a)),
                      subtitle: (a) => Text(
                        '${when(a)}\n${lookup.mechanicName(a.mechanicId)} · '
                        '${a.status.title} · ${formatMoney(a.total)}',
                      ),
                    )
                  : EntityTable<Appointment>(
                      items: page.items,
                      idOf: (a) => a.id,
                      selected: notifier.selected,
                      onToggleSelect: notifier.toggleSelection,
                      onSelectAll: notifier.setPageSelection,
                      sortField: q.sortField,
                      sortAscending: q.sortAscending,
                      onSort: (f) => _go(q.sortedBy(f)),
                      onOpen: (a) => context.go('/appointments/${a.id}'),
                      isDeleted: (a) => a.isDeleted,
                      actions: _actions,
                      columns: [
                        TableColumnSpec(
                          label: 'Начало',
                          sortField: 'starts',
                          build: (a) => Text(when(a)),
                        ),
                        TableColumnSpec(
                          label: 'Автомобиль',
                          build: (a) => Text(carLabel(a)),
                        ),
                        TableColumnSpec(
                          label: 'Мастер',
                          build: (a) => Text(lookup.mechanicName(a.mechanicId)),
                        ),
                        TableColumnSpec(
                          label: 'Услуг',
                          numeric: true,
                          build: (a) => Text('${a.serviceIds.length}'),
                        ),
                        TableColumnSpec(
                          label: 'Статус',
                          build: (a) => StatusChip(status: a.status),
                        ),
                        TableColumnSpec(
                          label: 'К оплате',
                          sortField: 'total',
                          numeric: true,
                          build: (a) => Text(formatMoney(a.total)),
                        ),
                      ],
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

class _Filters extends StatelessWidget {
  const _Filters({
    required this.query,
    required this.lookup,
    required this.compact,
    required this.sortLabels,
    required this.onChanged,
  });

  final AppointmentQuery query;
  final LookupNotifier lookup;
  final bool compact;
  final Map<String, String> sortLabels;
  final ValueChanged<AppointmentQuery> onChanged;

  Future<void> _pickDate(
    BuildContext context,
    DateTime? current,
    ValueChanged<DateTime?> done,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (picked != null) done(picked);
  }

  @override
  Widget build(BuildContext context) {
    final q = query;
    Widget sized(double width, Widget child) =>
        SizedBox(width: compact ? double.infinity : width, child: child);

    Widget dateButton(
      String label,
      DateTime? value,
      ValueChanged<DateTime?> set,
    ) => sized(
      150,
      OutlinedButton.icon(
        onPressed: () => _pickDate(context, value, set),
        icon: const Icon(Icons.event_outlined, size: 18),
        label: Text(value == null ? label : '$label ${formatDate(value)}'),
      ),
    );

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        sized(
          240,
          DebouncedTextField(
            value: q.search,
            label: 'Поиск',
            hint: 'Госномер',
            icon: Icons.search,
            onChanged: (v) => onChanged(q.copyWith(search: v)),
          ),
        ),
        sized(
          180,
          DropdownButtonFormField<AppointmentStatus?>(
            key: ValueKey('status-${q.status}'),
            initialValue: q.status,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Статус',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Любой')),
              for (final s in AppointmentStatus.values)
                DropdownMenuItem(value: s, child: Text(s.title)),
            ],
            onChanged: (v) => onChanged(q.copyWith(status: v)),
          ),
        ),
        sized(
          200,
          DropdownButtonFormField<String?>(
            key: ValueKey(
              'mechanic-${q.mechanicId}-${lookup.mechanics.length}',
            ),
            initialValue: lookup.mechanics.any((m) => m.id == q.mechanicId)
                ? q.mechanicId
                : null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Мастер',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Все мастера')),
              for (final m in lookup.mechanics)
                DropdownMenuItem(value: m.id, child: Text(m.shortName)),
            ],
            onChanged: (v) => onChanged(q.copyWith(mechanicId: v)),
          ),
        ),
        dateButton('С', q.from, (d) => onChanged(q.copyWith(from: d))),
        dateButton('По', q.to, (d) => onChanged(q.copyWith(to: d))),
        if (compact)
          SortControl(
            fields: sortLabels,
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
      ],
    );
  }
}

/// Статус записи цветной меткой.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      AppointmentStatus.planned => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      AppointmentStatus.inProgress => (
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
      ),
      AppointmentStatus.done => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
      AppointmentStatus.cancelled => (
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(status.title, style: TextStyle(color: fg, fontSize: 12)),
    );
  }
}

/// Карточка записи: автомобиль, мастер, время, услуги и разбор стоимости.
class AppointmentDetailScreen extends StatelessWidget {
  const AppointmentDetailScreen({
    super.key,
    required this.id,
    required this.backLocation,
  });

  final String id;

  /// Куда вести «назад»: в общий список или на «Мои автомобили».
  final String backLocation;

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
    String done,
  ) async {
    try {
      await action();
      if (context.mounted) showMessage(context, done);
    } catch (e) {
      if (context.mounted) showMessage(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = context.watch<DetailNotifier<Appointment>>();
    final lookup = context.watch<LookupNotifier>();
    final auth = context.watch<AuthNotifier>();
    final repository = context.read<AppointmentRepository>();
    final staff = auth.can(Operation.manageAppointments);
    final theme = Theme.of(context);

    return Title(
      title: 'Запись на обслуживание — Автосервис',
      color: theme.colorScheme.primary,
      child: DetailStateView<Appointment>(
        state: detail.state,
        onRetry: detail.load,
        onBack: () => context.go(backLocation),
        notFoundText: 'Запись не найдена',
        builder: (a) {
          final car = a.car;
          Future<void> setStatus(AppointmentStatus status) => _run(
            context,
            () => repository.update(
              Appointment(
                id: a.id,
                carId: a.carId,
                mechanicId: a.mechanicId,
                serviceIds: a.serviceIds,
                startsAt: a.startsAt,
                status: status,
                comment: a.comment,
              ),
            ),
            'Статус: ${status.title}',
          );

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: () => context.go(backLocation),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Назад'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      car == null
                          ? 'Запись на обслуживание'
                          : '${car.plate} · ${lookup.carTitle(car.modelId)}',
                      style: theme.textTheme.headlineSmall,
                    ),
                    StatusChip(status: a.status),
                    if (a.isDeleted) const DeletedBadge(),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 16,
                      children: [
                        InfoTile(
                          label: 'Дата',
                          value: Text(formatDate(a.startsAt)),
                        ),
                        InfoTile(
                          label: 'Время',
                          value: Text(
                            '${formatTime(a.startsAt)}–'
                            '${formatTime(a.endsAt ?? a.startsAt)} '
                            '(${formatDuration(a.duration.inMinutes)})',
                          ),
                        ),
                        InfoTile(
                          label: 'Мастер',
                          value: Text(lookup.mechanicName(a.mechanicId)),
                        ),
                        if (staff && car != null)
                          InfoTile(
                            label: 'Владелец',
                            value: Text(lookup.clientName(car.clientId)),
                          ),
                        if (a.comment.isNotEmpty)
                          SizedBox(
                            width: 480,
                            child: InfoTile(
                              label: 'Комментарий',
                              value: Text(a.comment),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const SectionTitle('Стоимость'),
                Card(
                  child: Column(
                    children: [
                      for (final sid in a.serviceIds)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.build_outlined),
                          title: Text(lookup.serviceName(sid)),
                          subtitle: Text(
                            formatDuration(lookup.service(sid)?.duration ?? 0),
                          ),
                          trailing: Text(
                            formatMoney(lookup.service(sid)?.price ?? 0),
                          ),
                        ),
                      const Divider(height: 1),
                      ListTile(
                        dense: true,
                        title: const Text('Сумма услуг'),
                        trailing: Text(formatMoney(a.subtotal)),
                      ),
                      ListTile(
                        dense: true,
                        title: Text(
                          'Скидка ${a.discountPercent} % — ${a.discountSource.title}',
                        ),
                        subtitle: const Text(
                          'Большая из персональной скидки и скидки по клубной '
                          'карте, не больше 15 %',
                        ),
                        trailing: Text('−${formatMoney(a.subtotal - a.total)}'),
                      ),
                      ListTile(
                        title: Text(
                          'К оплате',
                          style: theme.textTheme.titleMedium,
                        ),
                        trailing: Text(
                          formatMoney(a.total),
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (staff && !a.isDeleted) ...[
                      if (a.status == AppointmentStatus.planned)
                        FilledButton.icon(
                          onPressed: () =>
                              setStatus(AppointmentStatus.inProgress),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Начать работу'),
                        ),
                      if (a.status == AppointmentStatus.inProgress)
                        FilledButton.icon(
                          onPressed: () => setStatus(AppointmentStatus.done),
                          icon: const Icon(Icons.check),
                          label: const Text('Работы выполнены'),
                        ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            context.go('/appointments/${a.id}/edit'),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Изменить'),
                      ),
                    ],
                    if (a.status == AppointmentStatus.planned && !a.isDeleted)
                      OutlinedButton.icon(
                        onPressed: () async {
                          final ok = await confirmAction(
                            context,
                            title: 'Отменить запись?',
                            message:
                                'Время у мастера освободится. Восстановить '
                                'отменённую запись нельзя — только записаться заново.',
                            confirmLabel: 'Отменить запись',
                            cancelLabel: 'Не отменять',
                          );
                          if (ok && context.mounted) {
                            await _run(
                              context,
                              () => repository.cancel(a.id),
                              'Запись отменена',
                            );
                          }
                        },
                        icon: const Icon(Icons.event_busy_outlined),
                        label: const Text('Отменить запись'),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
