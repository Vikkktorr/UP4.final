import 'package:flutter/material.dart';

import '../models/page_result.dart';
import '../state/list_state.dart';

/// Выбирает, что показать по состоянию списка: индикатор, данные,
/// сообщение о пустом результате или ошибку.
class ListStateView<T> extends StatelessWidget {
  const ListStateView({
    super.key,
    required this.state,
    required this.builder,
    required this.onRetry,
    this.emptyTitle = 'Ничего не найдено',
    this.emptyHint = 'Измените условия поиска или сбросьте фильтры.',
    this.onResetFilters,
    this.onFirstPage,
  });

  final ListState<T> state;
  final Widget Function(PageResult<T> page) builder;
  final VoidCallback onRetry;
  final String emptyTitle;
  final String emptyHint;
  final VoidCallback? onResetFilters;
  final VoidCallback? onFirstPage;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      // Первая загрузка: показывать нечего, кроме индикатора.
      ListLoading(previous: null) => const _Loading(),
      ListLoading(:final previous?) when previous.items.isEmpty =>
        const _Loading(),
      // Повторная загрузка: прежние строки остаются, сверху тонкая полоса.
      ListLoading(:final previous?) => Column(
        children: [
          const LinearProgressIndicator(),
          Expanded(child: AbsorbPointer(child: builder(previous))),
        ],
      ),
      ListLoaded(:final page) when page.items.isEmpty => _Empty(
        title: page.total > 0 ? 'На этой странице записей нет' : emptyTitle,
        hint: page.total > 0
            ? 'Всего записей: ${page.total}, страниц: ${page.totalPages}.'
            : emptyHint,
        onResetFilters: page.total > 0 ? null : onResetFilters,
        onFirstPage: page.total > 0 ? onFirstPage : null,
      ),
      ListLoaded(:final page) => builder(page),
      ListFailed(:final message) => _Failure(
        message: message,
        onRetry: onRetry,
      ),
    };
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Загрузка…'),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.title,
    required this.hint,
    this.onResetFilters,
    this.onFirstPage,
  });

  final String title;
  final String hint;
  final VoidCallback? onResetFilters;
  final VoidCallback? onFirstPage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onResetFilters != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onResetFilters,
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('Сбросить фильтры'),
              ),
            ],
            if (onFirstPage != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onFirstPage,
                icon: const Icon(Icons.first_page),
                label: const Text('На первую страницу'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off,
                    size: 48,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ошибка загрузки',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
