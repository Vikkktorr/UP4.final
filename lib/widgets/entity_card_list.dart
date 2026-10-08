import 'package:flutter/material.dart';

/// Список карточек — замена таблицы на узком окне.
///
/// Настраивается так же, как [EntityTable]: заголовок, подпись и действия
/// передаются функциями, поэтому виджет общий для всех сущностей.
class EntityCardList<T> extends StatelessWidget {
  final List<T> items;
  final String Function(T item) idOf;
  final Widget Function(T item) title;
  final Widget Function(T item) subtitle;
  final Set<String> selected;
  final ValueChanged<String>? onToggleSelect;
  final ValueChanged<T>? onOpen;
  final List<Widget> Function(T item)? actions;
  final bool Function(T item)? isDeleted;

  const EntityCardList({
    super.key,
    required this.items,
    required this.idOf,
    required this.title,
    required this.subtitle,
    this.selected = const {},
    this.onToggleSelect,
    this.onOpen,
    this.actions,
    this.isDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListView.separated(
      primary: true,
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        final id = idOf(item);
        final deleted = isDeleted?.call(item) ?? false;
        final isSelected = selected.contains(id);

        return Card(
          key: ValueKey(id),
          margin: EdgeInsets.zero,
          color: deleted
              ? colors.errorContainer.withValues(alpha: 0.35)
              : isSelected
              ? colors.secondaryContainer
              : null,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen == null ? null : () => onOpen!(item),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (onToggleSelect != null)
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => onToggleSelect!(id),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10, left: 4),
                      child: Opacity(
                        opacity: deleted ? 0.6 : 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Длинное название — в одну строку с многоточием.
                            DefaultTextStyle.merge(
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              child: title(item),
                            ),
                            const SizedBox(height: 4),
                            subtitle(item),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (actions != null)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: actions!(item),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
