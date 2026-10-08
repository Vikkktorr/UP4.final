import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Title(
      title: 'Страница не найдена — Автосервис',
      color: theme.colorScheme.primary,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('404', style: theme.textTheme.displayLarge),
                const SizedBox(height: 8),
                Text('Страница не найдена', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  location,
                  style: theme.textTheme.bodyMedium?.copyWith(
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
      ),
    );
  }
}
