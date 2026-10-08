import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/formatting.dart';
import '../models/car.dart';
import '../state/lookup_notifier.dart';
import 'detail_view.dart';

/// Автомобили, которые ссылаются на запись, — в карточках клиента,
/// марки и мастера. Обратная сторона связей.
class RelatedCars extends StatelessWidget {
  const RelatedCars({
    super.key,
    required this.title,
    required this.cars,
    required this.total,
    required this.listLocation,
    required this.emptyText,
  });

  final String title;
  final List<Car> cars;
  final int total;

  /// Адрес списка автомобилей с фильтром по этой записи.
  final String listLocation;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lookup = context.watch<LookupNotifier>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          '$title ($total)',
          trailing: total == 0
              ? null
              : TextButton.icon(
                  onPressed: () => context.go(listLocation),
                  icon: const Icon(Icons.filter_list),
                  label: const Text('Открыть в списке автомобилей'),
                ),
        ),
        if (cars.isEmpty)
          Text(
            emptyText,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          )
        else
          Card(
            child: Column(
              children: [
                for (final car in cars)
                  ListTile(
                    leading: const Icon(Icons.directions_car_outlined),
                    title: Text(
                      '${car.plate} · ${lookup.carTitle(car.modelId)}',
                    ),
                    subtitle: Text(
                      '${car.year} г. · ${formatMileage(car.mileage)} · '
                      '${lookup.clientName(car.clientId)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/cars/${car.id}'),
                  ),
                if (total > cars.length)
                  ListTile(
                    dense: true,
                    title: Text('…и ещё ${total - cars.length}'),
                    onTap: () => context.go(listLocation),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
