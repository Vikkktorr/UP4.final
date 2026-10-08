import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/permissions.dart';
import '../models/entity.dart';
import '../models/entity_query.dart';
import '../models/with_cars.dart';
import '../state/auth_notifier.dart';
import '../state/detail_notifier.dart';
import '../state/entity_list_notifier.dart';
import '../widgets/detail_view.dart';
import '../widgets/list_toolbar.dart';
import '../widgets/related_cars.dart';

/// Общая карточка справочника: марки, мастера, услуги, категории. Сверху
/// поля записи, ниже — то, что на неё ссылается: модели марки, автомобили.
class ReferenceDetailScreen<
  T extends Entity,
  N extends EntityListNotifier<T, EntityQuery>
>
    extends StatelessWidget {
  const ReferenceDetailScreen({
    super.key,
    required this.id,
    required this.pageTitle,
    required this.backLabel,
    required this.notFoundText,
    required this.heading,
    required this.tiles,
    required this.labelOf,
    this.relatedTitle,
    this.relatedLocation,
    this.relatedEmpty = '',
    this.extra,
    this.hardDeleteNote,
  });

  final String id;
  final String pageTitle;
  final String backLabel;
  final String notFoundText;
  final String Function(T item) heading;
  final List<Widget> Function(T item) tiles;
  final String Function(T item) labelOf;

  /// Автомобили, ссылающиеся на запись; null — блока нет.
  final String? relatedTitle;
  final String Function(T item)? relatedLocation;
  final String relatedEmpty;

  /// Дополнительный блок под полями записи — например, модели марки.
  final Widget Function(T item)? extra;
  final String Function(T item)? hardDeleteNote;

  void _back(BuildContext context) =>
      context.go(context.read<N>().query.toLocation());

  Future<void> _act(
    BuildContext context,
    Future<void> Function(String id) action,
    String done, {
    bool leave = false,
  }) async {
    final detail = context.read<DetailNotifier<WithCars<T>>>();
    try {
      await action(id);
      if (!context.mounted) return;
      showMessage(context, done);
      leave ? _back(context) : await detail.load();
    } catch (e) {
      // Отказ в удалении (на марку ссылаются автомобили) — сообщением.
      if (context.mounted) showMessage(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = context.watch<DetailNotifier<WithCars<T>>>();
    final list = context.read<N>();
    final base = list.query.spec.path;
    // Кнопки, которыми роль всё равно не сможет воспользоваться, не
    // показываются. Это уборка интерфейса, а не защита.
    final auth = context.watch<AuthNotifier>();

    return Title(
      title: '$pageTitle — Автосервис',
      color: Theme.of(context).colorScheme.primary,
      child: DetailStateView<WithCars<T>>(
        state: detail.state,
        onRetry: detail.load,
        onBack: () => _back(context),
        notFoundText: notFoundText,
        builder: (data) {
          final theme = Theme.of(context);
          final item = data.item;
          final note = hardDeleteNote?.call(item);
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: () => _back(context),
                  icon: const Icon(Icons.arrow_back),
                  label: Text(backLabel),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(heading(item), style: theme.textTheme.headlineMedium),
                    if (item.isDeleted) const DeletedBadge(),
                  ],
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 16,
                      children: tiles(item),
                    ),
                  ),
                ),
                if (extra != null) ...[
                  const SizedBox(height: 16),
                  extra!(item),
                ],
                if (relatedTitle != null &&
                    auth.can(Operation.viewWorkshop)) ...[
                  const SizedBox(height: 16),
                  RelatedCars(
                    title: relatedTitle!,
                    cars: data.cars,
                    total: data.total,
                    listLocation: relatedLocation!(item),
                    emptyText: relatedEmpty,
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: item.isDeleted
                      ? [
                          if (auth.can(Operation.restore))
                            FilledButton.icon(
                              onPressed: () => _act(
                                context,
                                list.restore,
                                '«${labelOf(item)}» восстановлено',
                              ),
                              icon: const Icon(Icons.restore_from_trash),
                              label: const Text('Восстановить'),
                            ),
                          if (auth.can(Operation.hardDelete))
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.colorScheme.error,
                              ),
                              onPressed: () async {
                                final ok = await confirmAction(
                                  context,
                                  title: 'Удалить навсегда?',
                                  message:
                                      '«${labelOf(item)}» будет стёрто без '
                                      'возможности восстановления.'
                                      '${note == null ? '' : '\n\n$note'}',
                                  confirmLabel: 'Удалить навсегда',
                                );
                                if (ok && context.mounted) {
                                  await _act(
                                    context,
                                    list.hardDelete,
                                    '«${labelOf(item)}» стёрто',
                                    leave: true,
                                  );
                                }
                              },
                              icon: const Icon(Icons.delete_forever),
                              label: const Text('Удалить навсегда'),
                            ),
                        ]
                      : [
                          if (auth.can(Operation.editRecords))
                            FilledButton.icon(
                              onPressed: () => context.go('$base/$id/edit'),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Изменить'),
                            ),
                          if (auth.can(Operation.softDelete))
                            OutlinedButton.icon(
                              onPressed: () => _act(
                                context,
                                list.softDelete,
                                '«${labelOf(item)}» удалено',
                              ),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Удалить'),
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
