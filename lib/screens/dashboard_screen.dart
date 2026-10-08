import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/breakpoints.dart';
import '../models/app_user.dart';
import '../state/auth_notifier.dart';
import '../widgets/app_shell.dart';

/// Главный экран: приветствие и разделы, доступные роли.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const _roleAbout = {
    Role.client:
        'Вы можете смотреть каталог услуг, свои автомобили и историю '
        'обслуживания, записываться к мастеру на удобное время и отменять '
        'свои записи.',
    Role.mechanic:
        'Вы ведёте записи на обслуживание, автомобили, клиентов и '
        'справочники: создаёте, изменяете и удаляете записи. В разделе '
        '«Мой график» — ваша занятость на неделю.',
    Role.admin:
        'Вам доступно всё, что мастеру, кроме личного графика, а также '
        'пользователи и роли, статистика, восстановление и физическое '
        'удаление записей (переключатель «Показать удалённые» в списках).',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthNotifier>();
    final user = auth.user;
    // Сразу после выхода экран ещё может перестроиться — до того, как
    // redirect уведёт на форму входа.
    if (user == null) return const SizedBox.shrink();
    final compact = screenSizeOf(context) == ScreenSize.compact;
    final sections = [
      for (final s in appSections)
        if (s.operation != null && auth.can(s.operation!)) s,
    ];

    return Title(
      title: 'Главная — Автосервис',
      color: theme.colorScheme.primary,
      child: ListView(
        children: [
          Text(
            'Здравствуйте, ${user.firstName}!',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(
                avatar: const Icon(Icons.verified_user_outlined, size: 18),
                label: Text('Роль: ${user.role.title}'),
              ),
              Text(
                'Логин: ${user.username}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_roleAbout[user.role]!, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          Text('Доступные разделы', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final s in sections)
                SizedBox(
                  // На телефоне карточки идут одной колонкой во всю ширину.
                  width: compact ? double.infinity : 260,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => context.go(s.path),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(s.icon, color: theme.colorScheme.primary),
                            const SizedBox(height: 12),
                            Text(s.title, style: theme.textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              s.about,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
