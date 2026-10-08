import 'package:flutter/material.dart';

import '../state/detail_notifier.dart';

/// Состояния экрана карточки: загрузка, запись, «не найдено», ошибка.
class DetailStateView<T> extends StatelessWidget {
  const DetailStateView({
    super.key,
    required this.state,
    required this.builder,
    required this.onRetry,
    required this.notFoundText,
    required this.onBack,
  });

  final DetailState<T> state;
  final Widget Function(T item) builder;
  final VoidCallback onRetry;
  final String notFoundText;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return switch (state) {
      DetailLoading() => const Center(child: CircularProgressIndicator()),
      DetailLoaded(:final item) => builder(item),
      DetailNotFound() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.help_outline,
              size: 56,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(notFoundText, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('К списку'),
            ),
          ],
        ),
      ),
      DetailFailed(:final message) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    };
  }
}

/// Подпись и значение поля в карточке. Плитки выстраиваются в Wrap:
/// на широком окне в несколько колонок, на узком — одна под другой.
class InfoTile extends StatelessWidget {
  const InfoTile({super.key, required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          DefaultTextStyle.merge(
            style: theme.textTheme.bodyLarge,
            child: value,
          ),
        ],
      ),
    );
  }
}

/// Значение-ссылка в карточке: переход к связанной записи.
class LinkText extends StatelessWidget {
  const LinkText(this.text, {super.key, required this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(text, style: Theme.of(context).textTheme.titleLarge),
          ?trailing,
        ],
      ),
    );
  }
}
