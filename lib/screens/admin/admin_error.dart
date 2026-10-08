import 'package:flutter/material.dart';

import '../../core/api_exceptions.dart';

/// Ошибка загрузки на экранах администратора. Ответ 403 показывается
/// отдельно: так выглядит отказ сервера, если интерфейс обманули
/// и открыли экран без прав администратора.
class AdminError extends StatelessWidget {
  const AdminError({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final forbidden = error is ForbiddenException;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              forbidden ? Icons.gpp_bad_outlined : Icons.cloud_off,
              size: 56,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              forbidden ? 'Сервер отказал в доступе (403)' : 'Ошибка загрузки',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
