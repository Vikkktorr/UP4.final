import 'package:flutter/material.dart';

import '../core/query_params.dart';
import '../models/page_result.dart';

/// Переходы по страницам и выбор размера страницы.
///
/// Сам номер страницы не хранит: он приходит из [page], а изменения уходят
/// наружу через [onPage] и [onSize] — экран кладёт их в адрес.
class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.page,
    required this.onPage,
    required this.onSize,
  });

  final PageResult<Object?> page;
  final ValueChanged<int> onPage;
  final ValueChanged<int> onSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = page;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 4,
        children: [
          Text(
            p.total == 0
                ? 'Записей нет'
                : 'Записи ${p.firstIndex}–${p.lastIndex} из ${p.total}',
            style: theme.textTheme.bodyMedium,
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Строк на странице:', style: theme.textTheme.bodyMedium),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: p.size,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final size in pageSizes)
                        DropdownMenuItem(value: size, child: Text('$size')),
                    ],
                    onChanged: (value) {
                      if (value != null && value != p.size) onSize(value);
                    },
                  ),
                ],
              ),
              // Кнопки перехода — отдельный элемент Wrap: на узком окне
              // они уходят на свою строку, а не вылезают за край.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Первая страница',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.first_page),
                    onPressed: p.hasPrevious ? () => onPage(1) : null,
                  ),
                  IconButton(
                    tooltip: 'Предыдущая страница',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.chevron_left),
                    onPressed: p.hasPrevious ? () => onPage(p.page - 1) : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Стр. ${p.page} из ${p.totalPages}',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Следующая страница',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.chevron_right),
                    onPressed: p.hasNext ? () => onPage(p.page + 1) : null,
                  ),
                  IconButton(
                    tooltip: 'Последняя страница',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.last_page),
                    onPressed: p.hasNext ? () => onPage(p.totalPages) : null,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
