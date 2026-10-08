import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/formatting.dart';
import '../core/permissions.dart';
import '../models/client.dart';
import '../models/with_cars.dart';
import '../state/client_list_notifier.dart';
import '../state/auth_notifier.dart';
import '../state/detail_notifier.dart';
import '../widgets/detail_view.dart';
import '../widgets/list_toolbar.dart';
import '../repositories/club_card_repository.dart';
import '../widgets/related_cars.dart';

/// Карточка клиента: /clients/:id. Показывает клубную карту (один к одному)
/// и автомобили клиента (один ко многим со стороны владельца).
class ClientDetailScreen extends StatelessWidget {
  const ClientDetailScreen({super.key, required this.id});

  final String id;

  void _back(BuildContext context) =>
      context.go(context.read<ClientListNotifier>().query.toLocation());

  Future<void> _act(
    BuildContext context,
    Future<void> Function(String id) action,
    String done, {
    bool leave = false,
  }) async {
    final detail = context.read<DetailNotifier<WithCars<Client>>>();
    try {
      await action(id);
      if (!context.mounted) return;
      showMessage(context, done);
      leave ? _back(context) : await detail.load();
    } catch (e) {
      if (context.mounted) showMessage(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final detail = context.watch<DetailNotifier<WithCars<Client>>>();
    final list = context.read<ClientListNotifier>();

    return Title(
      title: 'Клиент — Автосервис',
      color: Theme.of(context).colorScheme.primary,
      child: DetailStateView<WithCars<Client>>(
        state: detail.state,
        onRetry: detail.load,
        onBack: () => _back(context),
        notFoundText: 'Клиент не найден',
        builder: (details) {
          final theme = Theme.of(context);
          final c = details.item;
          final card = c.card;
          final valid = card?.isValidAt(DateTime.now()) ?? false;
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: () => _back(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('К списку клиентов'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(c.fullName, style: theme.textTheme.headlineMedium),
                    if (c.isDeleted) const DeletedBadge(),
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
                        InfoTile(
                          label: 'Телефон',
                          value: SelectableText(c.phone),
                        ),
                        InfoTile(
                          label: 'E-mail',
                          value: SelectableText(c.email),
                        ),
                        InfoTile(
                          label: 'Персональная скидка',
                          value: Text(
                            c.discount == 0 ? 'нет' : '${c.discount} %',
                          ),
                        ),
                        InfoTile(
                          label: 'Клиент с',
                          value: Text(formatDate(c.registeredAt)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SectionTitle(
                  'Клубная карта',
                  trailing: card != null && auth.can(Operation.editRecords)
                      ? TextButton.icon(
                          onPressed: () async {
                            final ok = await confirmAction(
                              context,
                              title: 'Снять карту?',
                              message:
                                  'Карта ${card.number} будет удалена. Скидка '
                                  'по карте в новых записях действовать не будет.',
                              confirmLabel: 'Снять карту',
                            );
                            if (ok && context.mounted) {
                              await _act(
                                context,
                                (_) => context
                                    .read<ClubCardRepository>()
                                    .delete(card.id),
                                'Карта снята',
                              );
                            }
                          },
                          icon: const Icon(Icons.credit_card_off_outlined),
                          label: const Text('Снять карту'),
                        )
                      : null,
                ),
                if (card == null)
                  Wrap(
                    spacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Карты нет.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (auth.can(Operation.editRecords) && !c.isDeleted)
                        OutlinedButton.icon(
                          onPressed: () => context.go('/clients/${c.id}/edit'),
                          icon: const Icon(Icons.add_card),
                          label: const Text('Выдать карту'),
                        ),
                    ],
                  )
                else
                  Card.outlined(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Wrap(
                        spacing: 24,
                        runSpacing: 16,
                        children: [
                          InfoTile(
                            label: 'Номер',
                            value: SelectableText(card.number),
                          ),
                          InfoTile(
                            label: 'Уровень',
                            value: Text(
                              '${card.level.title} · скидка ${card.level.discount} %',
                            ),
                          ),
                          InfoTile(
                            label: 'Срок действия',
                            value: Text(
                              '${formatDate(card.issuedAt)} — '
                              '${formatDate(card.expiresAt)}'
                              '${valid ? '' : ' (не действует)'}',
                              style: valid
                                  ? null
                                  : TextStyle(color: theme.colorScheme.error),
                            ),
                          ),
                          InfoTile(
                            label: 'Бонусные баллы',
                            value: Text('${card.bonusPoints}'),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                RelatedCars(
                  title: 'Автомобили',
                  cars: details.cars,
                  total: details.total,
                  listLocation: '/cars?clientId=${c.id}',
                  emptyText: 'За клиентом не числится ни одного автомобиля.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: c.isDeleted
                      ? [
                          if (auth.can(Operation.restore))
                            FilledButton.icon(
                              onPressed: () => _act(
                                context,
                                list.restore,
                                'Клиент восстановлен',
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
                                      'Клиент ${c.fullName} и его клубная карта '
                                      'будут стёрты без возможности восстановления.',
                                  confirmLabel: 'Удалить навсегда',
                                );
                                if (ok && context.mounted) {
                                  await _act(
                                    context,
                                    list.hardDelete,
                                    'Клиент стёрт',
                                    leave: true,
                                  );
                                }
                              },
                              icon: const Icon(Icons.delete_forever),
                              label: const Text('Удалить навсегда'),
                            ),
                        ]
                      : [
                          FilledButton.icon(
                            onPressed: () =>
                                context.go('/clients/${c.id}/edit'),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Изменить'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _act(context, list.softDelete, 'Клиент удалён'),
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
