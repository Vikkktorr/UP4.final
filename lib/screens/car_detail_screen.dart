import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/formatting.dart';
import '../core/permissions.dart';
import '../models/appointment.dart';
import '../models/car.dart';
import '../repositories/appointment_repository.dart';
import '../state/car_list_notifier.dart';
import '../state/auth_notifier.dart';
import '../state/detail_notifier.dart';
import '../state/lookup_notifier.dart';
import '../widgets/detail_view.dart';
import '../widgets/list_toolbar.dart';
import 'appointment_screens.dart';

/// Карточка автомобиля: /cars/:id. Показывает связи: модель и владельца
/// (многие к одному), закреплённых мастеров (многие ко многим) и записи
/// на обслуживание (один ко многим).
class CarDetailScreen extends StatelessWidget {
  const CarDetailScreen({super.key, required this.id});

  final String id;

  /// Возврат к списку с теми же условиями отбора, с которыми его покинули.
  void _back(BuildContext context) =>
      context.go(context.read<CarListNotifier>().query.toLocation());

  Future<void> _act(
    BuildContext context,
    Future<void> Function(String id) action,
    String done,
  ) async {
    final detail = context.read<DetailNotifier<Car>>();
    try {
      await action(id);
      if (!context.mounted) return;
      showMessage(context, done);
      await detail.load();
    } catch (e) {
      if (context.mounted) showMessage(context, '$e');
    }
  }

  Future<void> _hardDelete(BuildContext context, Car car) async {
    final list = context.read<CarListNotifier>();
    final ok = await confirmAction(
      context,
      title: 'Удалить навсегда?',
      message:
          'Автомобиль ${car.plate} будет стёрт без возможности '
          'восстановления.',
      confirmLabel: 'Удалить навсегда',
    );
    if (!ok || !context.mounted) return;
    try {
      await list.hardDelete(car.id);
      if (!context.mounted) return;
      showMessage(context, 'Автомобиль ${car.plate} стёрт');
      _back(context);
    } catch (e) {
      if (context.mounted) showMessage(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final detail = context.watch<DetailNotifier<Car>>();
    final lookup = context.watch<LookupNotifier>();
    final list = context.read<CarListNotifier>();

    return Title(
      title: 'Автомобиль — Автосервис',
      color: Theme.of(context).colorScheme.primary,
      child: DetailStateView<Car>(
        state: detail.state,
        onRetry: detail.load,
        onBack: () => _back(context),
        notFoundText: 'Автомобиль не найден',
        builder: (car) {
          final theme = Theme.of(context);
          final brandId = lookup.brandIdOfModel(car.modelId);
          final brand = brandId == null ? null : lookup.brand(brandId);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: () => _back(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('К списку автомобилей'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(car.plate, style: theme.textTheme.headlineMedium),
                    Text(
                      lookup.carTitle(car.modelId),
                      style: theme.textTheme.titleLarge,
                    ),
                    if (car.isDeleted) const DeletedBadge(),
                  ],
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 16,
                      children: [
                        InfoTile(label: 'VIN', value: SelectableText(car.vin)),
                        InfoTile(
                          label: 'Марка',
                          value: LinkText(
                            brand == null
                                ? '—'
                                : '${brand.name} (${brand.country})',
                            onTap: brand == null
                                ? null
                                : () => context.go('/brands/${brand.id}'),
                          ),
                        ),
                        InfoTile(
                          label: 'Модель',
                          value: Text(lookup.modelName(car.modelId)),
                        ),
                        InfoTile(
                          label: 'Год выпуска',
                          value: Text('${car.year}'),
                        ),
                        InfoTile(
                          label: 'Пробег',
                          value: Text(formatMileage(car.mileage)),
                        ),
                        InfoTile(
                          label: 'Двигатель',
                          value: Text(car.fuel.title),
                        ),
                        InfoTile(
                          label: 'Владелец',
                          value: LinkText(
                            lookup.client(car.clientId)?.fullName ?? 'Клиент',
                            onTap: () => context.go('/clients/${car.clientId}'),
                          ),
                        ),
                        if (car.deletedAt != null)
                          InfoTile(
                            label: 'Удалён',
                            value: Text(formatDate(car.deletedAt!)),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SectionTitle('Мастера (${car.mechanicIds.length})'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final mid in car.mechanicIds)
                      ActionChip(
                        avatar: const Icon(
                          Icons.engineering_outlined,
                          size: 18,
                        ),
                        label: Text(
                          lookup.mechanic(mid) == null
                              ? 'Мастер'
                              : '${lookup.mechanicName(mid)} · '
                                    '${lookup.mechanic(mid)!.grade} разряд',
                        ),
                        onPressed: () => context.go('/mechanics/$mid'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _CarVisits(car: car),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: car.isDeleted
                      ? [
                          if (auth.can(Operation.restore))
                            FilledButton.icon(
                              onPressed: () => _act(
                                context,
                                list.restore,
                                'Автомобиль восстановлен',
                              ),
                              icon: const Icon(Icons.restore_from_trash),
                              label: const Text('Восстановить'),
                            ),
                          if (auth.can(Operation.hardDelete))
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.colorScheme.error,
                              ),
                              onPressed: () => _hardDelete(context, car),
                              icon: const Icon(Icons.delete_forever),
                              label: const Text('Удалить навсегда'),
                            ),
                        ]
                      : [
                          FilledButton.icon(
                            onPressed: () => context.go('/cars/${car.id}/edit'),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Изменить'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _act(
                              context,
                              list.softDelete,
                              'Автомобиль удалён',
                            ),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Удалить'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                context.go('/appointments/new?car=${car.id}'),
                            icon: const Icon(Icons.event_available),
                            label: const Text('Записать на обслуживание'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                context.go('/cars?clientId=${car.clientId}'),
                            icon: const Icon(Icons.garage_outlined),
                            label: const Text('Все автомобили владельца'),
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

/// Записи автомобиля на обслуживание — обратная сторона связи
/// «автомобиль → записи».
class _CarVisits extends StatefulWidget {
  const _CarVisits({required this.car});

  final Car car;

  @override
  State<_CarVisits> createState() => _CarVisitsState();
}

class _CarVisitsState extends State<_CarVisits> {
  late Future<List<Appointment>> _visits = context
      .read<AppointmentRepository>()
      .forCar(widget.car.id);

  @override
  Widget build(BuildContext context) {
    final lookup = context.watch<LookupNotifier>();
    final theme = Theme.of(context);
    return FutureBuilder<List<Appointment>>(
      future: _visits,
      builder: (context, snapshot) {
        final visits = snapshot.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              'Записи на обслуживание${visits == null ? '' : ' (${visits.length})'}',
              trailing: TextButton.icon(
                onPressed: () => context.go(
                  '/appointments?search=${Uri.encodeQueryComponent(widget.car.plate)}',
                ),
                icon: const Icon(Icons.filter_list),
                label: const Text('Открыть в списке записей'),
              ),
            ),
            if (snapshot.hasError)
              Row(
                children: [
                  Expanded(child: Text('${snapshot.error}')),
                  TextButton(
                    onPressed: () => setState(
                      () => _visits = context
                          .read<AppointmentRepository>()
                          .forCar(widget.car.id),
                    ),
                    child: const Text('Повторить'),
                  ),
                ],
              )
            else if (visits == null)
              const LinearProgressIndicator()
            else if (visits.isEmpty)
              Text(
                'Записей пока нет.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              )
            else
              Card(
                child: Column(
                  children: [
                    for (final v in visits.take(10))
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.event_note_outlined),
                        title: Text(
                          '${formatDateTime(v.startsAt)} · '
                          '${lookup.mechanicName(v.mechanicId)}',
                        ),
                        subtitle: Text(
                          v.serviceIds.map(lookup.serviceName).join(', '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(formatMoney(v.total)),
                            StatusChip(status: v.status),
                          ],
                        ),
                        onTap: () => context.go('/appointments/${v.id}'),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
