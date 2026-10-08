import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatting.dart';
import '../../models/app_user.dart';
import '../../repositories/admin_api.dart';
import 'admin_error.dart';

/// Статистика: /admin/stats. Только администратор.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late Future<Stats> _stats;

  static const _titles = {
    'cars': 'Автомобили',
    'clients': 'Клиенты',
    'brands': 'Марки',
    'car_models': 'Модели',
    'mechanics': 'Мастера',
    'services': 'Услуги',
    'service_categories': 'Категории услуг',
    'appointments': 'Записи на обслуживание',
  };

  @override
  void initState() {
    super.initState();
    _stats = context.read<AdminApi>().stats();
  }

  void _reload() => setState(() => _stats = context.read<AdminApi>().stats());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Title(
      title: 'Статистика — Автосервис',
      color: theme.colorScheme.primary,
      child: FutureBuilder<Stats>(
        future: _stats,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return AdminError(error: snapshot.error!, onRetry: _reload);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final stats = snapshot.data!;
          return ListView(
            children: [
              Text('Статистика', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final e in _titles.entries)
                    _Tile(
                      title: e.value,
                      value: '${stats.counts[e.key] ?? 0}',
                      note: 'удалено: ${stats.deleted[e.key] ?? 0}',
                    ),
                  _Tile(
                    title: 'Выручка',
                    value: formatMoney(stats.revenue),
                    note: 'по выполненным записям',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Пользователи по ролям', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final role in Role.values)
                    _Tile(
                      title: role.title,
                      value: '${stats.users[role.name] ?? 0}',
                      note: 'учётных записей',
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.title, required this.value, required this.note});

  final String title;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 200,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(value, style: theme.textTheme.headlineSmall),
              Text(
                note,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
