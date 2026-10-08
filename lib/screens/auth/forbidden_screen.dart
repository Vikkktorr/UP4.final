import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../state/auth_notifier.dart';

/// Экран отказа: сюда redirect отправляет, если роль не позволяет открыть
/// адрес. Проверка выполняется в redirect маршрута, а не в build экрана,
/// поэтому чужой экран не успевает мелькнуть.
class ForbiddenScreen extends StatelessWidget {
  const ForbiddenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = context.watch<AuthNotifier>().user?.role;
    return Title(
      title: 'Доступ запрещён — Автосервис',
      color: theme.colorScheme.primary,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text('Доступ запрещён', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                role == null
                    ? 'У вас нет прав на просмотр этой страницы.'
                    : 'Роли «${role.title}» этот раздел недоступен.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home_outlined),
                label: const Text('На главную'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
