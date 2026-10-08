import 'package:flutter/material.dart';

import '../core/formatting.dart';

/// Заголовок экрана списка: название, число найденных записей
/// и переключатель показа удалённых.
class ListHeader extends StatelessWidget {
  const ListHeader({
    super.key,
    required this.title,
    required this.total,
    required this.showDeleted,
    this.onShowDeleted,
    this.onAdd,
    this.addLabel = 'Добавить',
  });

  final String title;
  final int? total;
  final bool showDeleted;

  /// null — переключатель не показывается (удалённые видит только
  /// администратор).
  final ValueChanged<bool>? onShowDeleted;

  /// Кнопка создания записи — ведёт на форму.
  final VoidCallback? onAdd;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 4,
      children: [
        Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            Text(title, style: theme.textTheme.headlineSmall),
            if (total != null)
              Text(
                'найдено $total ${plural(total!, 'запись', 'записи', 'записей')}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        // Wrap: на узком окне кнопка переносится под переключатель.
        Wrap(
          spacing: 16,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (onShowDeleted != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Показать удалённые'),
                  const SizedBox(width: 8),
                  Switch(value: showDeleted, onChanged: onShowDeleted),
                ],
              ),
            if (onAdd != null)
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: Text(addLabel),
              ),
          ],
        ),
      ],
    );
  }
}

/// Полоса над списком, когда выделены строки: счётчик и массовое удаление.
class SelectionBar extends StatelessWidget {
  const SelectionBar({
    super.key,
    required this.count,
    required this.onDelete,
    required this.onClear,
  });

  final int count;
  final VoidCallback onDelete;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Снять выделение',
              icon: const Icon(Icons.close),
              onPressed: onClear,
            ),
            Expanded(
              child: Text(
                'Выбрано: $count',
                style: TextStyle(
                  color: colors.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Удалить выбранные'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Выбор сортировки для узкого окна, где нет заголовков колонок.
class SortControl extends StatelessWidget {
  const SortControl({
    super.key,
    required this.fields,
    required this.field,
    required this.ascending,
    required this.onSort,
  });

  /// Поле сортировки → подпись.
  final Map<String, String> fields;
  final String field;
  final bool ascending;

  /// Повторный выбор того же поля меняет направление.
  final ValueChanged<String> onSort;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.sort, size: 20),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: field,
          underline: const SizedBox.shrink(),
          items: [
            for (final entry in fields.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: (value) {
            if (value != null && value != field) onSort(value);
          },
        ),
        IconButton(
          tooltip: ascending ? 'По возрастанию' : 'По убыванию',
          icon: Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward),
          onPressed: () => onSort(field),
        ),
      ],
    );
  }
}

/// Отметка «удалена» рядом с записью.
class DeletedBadge extends StatelessWidget {
  const DeletedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.error,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'удалена',
        style: TextStyle(color: colors.onError, fontSize: 12),
      ),
    );
  }
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Отмена',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      // Диалог не растягивается вслед за длинным текстом на широком мониторе.
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Text(message),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showMessage(BuildContext context, String text, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), action: action));
}
