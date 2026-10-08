import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/formatting.dart';
import '../models/app_user.dart';
import '../models/appointment.dart';
import '../models/car.dart';
import '../models/client.dart';
import '../repositories/appointment_repository.dart';
import '../repositories/car_repository.dart';
import '../repositories/client_repository.dart';
import '../repositories/data_changes.dart';
import '../state/lookup_notifier.dart';
import 'appointment_screens.dart';

/// «Мои автомобили» — личный экран клиента (/my).
///
/// Здесь клиент видит свою клубную карту, свои автомобили с историей
/// записей и записывается к мастеру. Правила PocketBase отдают клиенту
/// только его записи — чужие автомобили сервер просто не вернёт.
class MyCarsScreen extends StatefulWidget {
  const MyCarsScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<MyCarsScreen> createState() => _MyCarsScreenState();
}

typedef _MyData = ({Client? client, List<Car> cars, List<Appointment> visits});

class _MyCarsScreenState extends State<MyCarsScreen> {
  late Future<_MyData> _data;
  late final DataChanges _changes;

  @override
  void initState() {
    super.initState();
    _changes = context.read<DataChanges>()..addListener(_reload);
    _data = _load();
  }

  @override
  void dispose() {
    _changes.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (mounted) setState(() => _data = _load());
  }

  Future<_MyData> _load() async {
    const none = <Appointment>[];
    final clientId = widget.user.clientId;
    if (clientId == null) return (client: null, cars: <Car>[], visits: none);
    final client = await context.read<ClientRepository>().findById(clientId);
    if (!mounted) return (client: client, cars: <Car>[], visits: none);
    final cars = (await context.read<CarRepository>().findAll())
        .where((c) => !c.isDeleted)
        .toList();
    if (!mounted) return (client: client, cars: cars, visits: none);
    final appointments = context.read<AppointmentRepository>();
    final visits = <Appointment>[
      for (final car in cars) ...await appointments.forCar(car.id),
    ];
    return (client: client, cars: cars, visits: visits);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Title(
      title: 'Мои автомобили — Автосервис',
      color: theme.colorScheme.primary,
      child: FutureBuilder<_MyData>(
        future: _data,
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
          final data = snapshot.data!;
          return ListView(
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Мои автомобили', style: theme.textTheme.headlineSmall),
                  if (data.cars.isNotEmpty)
                    FilledButton.icon(
                      onPressed: () => context.go('/my/book'),
                      icon: const Icon(Icons.event_available),
                      label: const Text('Записаться'),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Ваши автомобили, записи на обслуживание и клубная карта.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              if (widget.user.clientId == null)
                const Text(
                  'Учётная запись не связана с карточкой клиента. '
                  'Обратитесь к администратору.',
                )
              else ...[
                _CardPanel(client: data.client),
                const SizedBox(height: 16),
                if (data.cars.isEmpty)
                  const Text(
                    'За вами пока не записано ни одного автомобиля — его '
                    'добавит мастер при первом визите.',
                  )
                else
                  _CarGrid(cars: data.cars, visits: data.visits),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Сетка карточек: столько колонок, сколько помещается карточек шириной
/// от 300 — одна на телефоне, две на планшете.
class _CarGrid extends StatelessWidget {
  const _CarGrid({required this.cars, required this.visits});

  final List<Car> cars;
  final List<Appointment> visits;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 16.0;
        final columns = ((constraints.maxWidth + gap) ~/ (300 + gap)).clamp(
          1,
          6,
        );
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final car in cars)
              SizedBox(
                width: width,
                child: _CarCard(
                  car: car,
                  visits: [
                    for (final v in visits)
                      if (v.carId == car.id) v,
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CarCard extends StatelessWidget {
  const _CarCard({required this.car, required this.visits});

  final Car car;
  final List<Appointment> visits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lookup = context.watch<LookupNotifier>();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_car_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lookup.carTitle(car.modelId),
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  car.plate,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${car.year} г. · ${formatMileage(car.mileage)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (visits.isEmpty)
              Text(
                'Записей на обслуживание пока нет.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              )
            else
              for (final v in visits.take(4))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  onTap: () => context.go('/my/appointments/${v.id}'),
                  title: Text(
                    '${formatDateTime(v.startsAt)} · ${lookup.mechanicName(v.mechanicId)}',
                  ),
                  subtitle: Text(
                    '${v.serviceIds.map(lookup.serviceName).join(', ')}\n'
                    '${formatMoney(v.total)}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: StatusChip(status: v.status),
                ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => context.go('/my/book?car=${car.id}'),
                icon: const Icon(Icons.add),
                label: const Text('Записать этот автомобиль'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Клубная карта клиента: уровень, срок и скидка по ней.
class _CardPanel extends StatelessWidget {
  const _CardPanel({required this.client});

  final Client? client;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = client?.card;
    final personal = client?.discount ?? 0;
    if (card == null) {
      return Text(
        'Клубной карты нет${personal > 0 ? ' · персональная скидка $personal %' : ''}.',
        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
      );
    }
    final valid = card.isValidAt(DateTime.now());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 24,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Icon(Icons.card_membership_outlined),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Клубная карта ${card.number} · ${card.level.title}',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  '${valid ? 'Действует до' : 'Не действует, срок до'} '
                  '${formatDate(card.expiresAt)} · бонусов: ${card.bonusPoints}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: valid
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.error,
                  ),
                ),
                Text(
                  'Скидка по карте ${card.level.discount} %, персональная '
                  '$personal % — применяется большая, не больше 15 %.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
