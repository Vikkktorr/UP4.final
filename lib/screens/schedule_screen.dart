import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/breakpoints.dart';
import '../core/formatting.dart';
import '../core/query_params.dart';
import '../core/schedule.dart';
import '../models/appointment.dart';
import '../repositories/appointment_repository.dart';
import '../repositories/data_changes.dart';
import '../state/lookup_notifier.dart';
import 'appointment_screens.dart';

/// «Мой график»: календарь занятости мастера на неделю.
///
/// Неделя отражается в адресе (`/work?week=2026-10-05`), поэтому ссылку на
/// неделю можно передать. На широком окне — сетка «дни × часы» с записями
/// блоками по времени, на узком — список по дням.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, required this.mechanicId, this.week});

  final String mechanicId;

  /// Любой день недели; null — текущая неделя.
  final DateTime? week;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late Future<List<Appointment>> _items;
  late final DataChanges _changes;

  DateTime get _monday => Schedule.weekStart(widget.week ?? DateTime.now());

  @override
  void initState() {
    super.initState();
    _changes = context.read<DataChanges>()..addListener(_reload);
    _items = _load();
  }

  @override
  void didUpdateWidget(ScheduleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.week != widget.week) _reload();
  }

  @override
  void dispose() {
    _changes.removeListener(_reload);
    super.dispose();
  }

  Future<List<Appointment>> _load() =>
      context.read<AppointmentRepository>().forMechanic(
        widget.mechanicId,
        _monday,
        _monday.add(const Duration(days: 7)),
      );

  void _reload() {
    if (mounted) setState(() => _items = _load());
  }

  void _goWeek(int delta) => context.go(
    Uri(
      path: '/work',
      queryParameters: {
        'week': formatDateParam(_monday.add(Duration(days: 7 * delta))),
      },
    ).toString(),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = screenSizeOf(context) == ScreenSize.compact;
    final monday = _monday;
    final sunday = monday.add(const Duration(days: 6));
    final lookup = context.watch<LookupNotifier>();

    return Title(
      title: 'Мой график — Автосервис',
      color: theme.colorScheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Мой график', style: theme.textTheme.headlineSmall),
              Text(
                lookup.mechanic(widget.mechanicId)?.fullName ?? '',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: 'Предыдущая неделя',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _goWeek(-1),
              ),
              Expanded(
                child: Text(
                  '${formatDate(monday)} — ${formatDate(sunday)}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Следующая неделя',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _goWeek(1),
              ),
              TextButton(
                onPressed: () => context.go('/work'),
                child: const Text('Сегодня'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<Appointment>>(
              future: _items,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  final e = snapshot.error;
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_off,
                          size: 48,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          e is ApiException ? e.message : '$e',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _reload,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Повторить'),
                        ),
                      ],
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = [
                  for (final a in snapshot.data!)
                    if (a.status != AppointmentStatus.cancelled) a,
                ];
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      'На этой неделе записей нет.',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return compact
                    ? _DayList(monday: monday, items: items)
                    : _WeekGrid(monday: monday, items: items);
              },
            ),
          ),
        ],
      ),
    );
  }
}

List<Appointment> _ofDay(List<Appointment> items, DateTime day) => [
  for (final a in items)
    if (a.startsAt.year == day.year &&
        a.startsAt.month == day.month &&
        a.startsAt.day == day.day)
      a,
];

/// Сетка недели: дни столбцами, часы строками, запись — блок по времени.
class _WeekGrid extends StatelessWidget {
  const _WeekGrid({required this.monday, required this.items});

  final DateTime monday;
  final List<Appointment> items;

  static const _hourHeight = 52.0;
  static const _hours = Schedule.closeHour - Schedule.openHour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lookup = context.watch<LookupNotifier>();
    final today = DateTime.now();
    final days = [for (var i = 0; i < 7; i++) monday.add(Duration(days: i))];

    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Подписи часов
          SizedBox(
            width: 48,
            child: Column(
              children: [
                const SizedBox(height: 32),
                for (var h = Schedule.openHour; h < Schedule.closeHour; h++)
                  SizedBox(
                    height: _hourHeight,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text('$h:00', style: theme.textTheme.bodySmall),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (final day in days)
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    height: 32,
                    child: Center(
                      child: Text(
                        formatDayShort(day),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: DateUtils.isSameDay(day, today)
                              ? theme.colorScheme.primary
                              : null,
                          fontWeight: DateUtils.isSameDay(day, today)
                              ? FontWeight.bold
                              : null,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    height: _hourHeight * _hours,
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: theme.dividerColor),
                      ),
                    ),
                    child: Stack(
                      children: [
                        for (var h = 0; h < _hours; h++)
                          Positioned(
                            top: h * _hourHeight,
                            left: 0,
                            right: 0,
                            child: Divider(
                              height: 1,
                              color: theme.dividerColor,
                            ),
                          ),
                        for (final a in _ofDay(items, day))
                          _block(context, a, lookup),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _block(BuildContext context, Appointment a, LookupNotifier lookup) {
    final theme = Theme.of(context);
    final startMin =
        (a.startsAt.hour - Schedule.openHour) * 60 + a.startsAt.minute;
    final minutes = a.duration.inMinutes.clamp(20, 11 * 60);
    final done = a.status == AppointmentStatus.done;
    return Positioned(
      top: startMin / 60 * _hourHeight,
      height: minutes / 60 * _hourHeight - 2,
      left: 2,
      right: 2,
      child: Tooltip(
        message:
            '${formatTime(a.startsAt)}–${formatTime(a.endsAt ?? a.startsAt)}\n'
            '${a.car?.plate ?? ''} ${a.car == null ? '' : lookup.carTitle(a.car!.modelId)}\n'
            '${a.serviceIds.map(lookup.serviceName).join(', ')}',
        child: Material(
          color: done
              ? theme.colorScheme.secondaryContainer
              : theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => context.go('/appointments/${a.id}'),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                '${formatTime(a.startsAt)} ${a.car?.plate ?? ''}\n'
                '${a.serviceIds.map(lookup.serviceName).join(', ')}',
                overflow: TextOverflow.fade,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Узкое окно: записи списком по дням.
class _DayList extends StatelessWidget {
  const _DayList({required this.monday, required this.items});

  final DateTime monday;
  final List<Appointment> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lookup = context.watch<LookupNotifier>();
    return ListView(
      children: [
        for (var i = 0; i < 7; i++)
          if (_ofDay(items, monday.add(Duration(days: i))) case final day
              when day.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                formatDayShort(monday.add(Duration(days: i))),
                style: theme.textTheme.titleSmall,
              ),
            ),
            for (final a in day)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => context.go('/appointments/${a.id}'),
                  title: Text(
                    '${formatTime(a.startsAt)}–${formatTime(a.endsAt ?? a.startsAt)} · '
                    '${a.car?.plate ?? ''}',
                  ),
                  subtitle: Text(
                    a.serviceIds.map(lookup.serviceName).join(', '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: StatusChip(status: a.status),
                ),
              ),
          ],
      ],
    );
  }
}

/// Учётная запись мастера не связана с карточкой мастера.
class ScheduleUnlinked extends StatelessWidget {
  const ScheduleUnlinked({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Text(
      'Учётная запись не связана с карточкой мастера — обратитесь к администратору.',
      textAlign: TextAlign.center,
    ),
  );
}
