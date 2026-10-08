import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatting.dart';
import '../models/brand.dart';
import '../models/entity_query.dart';
import '../models/mechanic.dart';
import '../models/service_category.dart';
import '../models/service_item.dart';
import '../state/lookup_notifier.dart';
import '../state/reference_list_notifiers.dart';
import '../widgets/brand_models.dart';
import '../widgets/detail_view.dart';
import '../widgets/entity_form/form_spec.dart';
import '../widgets/entity_table.dart';
import 'reference_detail_screen.dart';
import 'reference_list_screen.dart';

/// Списки и карточки справочников — настройки общих экранов.

// ---- марки ----

class BrandListScreen extends StatelessWidget {
  const BrandListScreen({super.key, required this.query});

  final EntityQuery query;

  @override
  Widget build(BuildContext context) {
    final lookup = context.watch<LookupNotifier>();
    return ReferenceListScreen<Brand, BrandListNotifier>(
      query: query,
      title: 'Марки',
      addLabel: 'Добавить марку',
      searchHint: 'Марка или страна',
      sortLabels: const {'name': 'Название', 'country': 'Страна'},
      filters: [
        ListFilter(
          key: 'country',
          label: 'Страна',
          allLabel: 'Все страны',
          options: [for (final c in lookup.countries) Option(c, c)],
        ),
      ],
      nouns: ('марка', 'марки', 'марок'),
      labelOf: (b) => b.name,
      cardTitle: (b) => b.name,
      cardSubtitle: (b) =>
          '${b.country} · моделей: ${lookup.modelsOf(b.id).length}',
      columns: [
        nameColumn<Brand>('Марка', (b) => b.name, sortField: 'name'),
        TableColumnSpec(
          label: 'Страна',
          sortField: 'country',
          build: (b) => Text(b.country),
        ),
        TableColumnSpec(
          label: 'Моделей',
          numeric: true,
          build: (b) => Text('${lookup.modelsOf(b.id).length}'),
        ),
        TableColumnSpec(
          label: 'Модели',
          build: (b) =>
              Text(lookup.modelsOf(b.id).map((m) => m.name).join(', ')),
        ),
      ],
    );
  }
}

class BrandDetailScreen extends StatelessWidget {
  const BrandDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return ReferenceDetailScreen<Brand, BrandListNotifier>(
      id: id,
      pageTitle: 'Марка',
      backLabel: 'К списку марок',
      notFoundText: 'Марка не найдена',
      heading: (b) => b.name,
      labelOf: (b) => b.name,
      tiles: (b) => [InfoTile(label: 'Страна', value: Text(b.country))],
      extra: (b) => BrandModels(brandId: b.id),
      relatedTitle: 'Автомобили марки',
      relatedLocation: (b) => '/cars?brandId=${b.id}',
      relatedEmpty: 'Автомобилей этой марки нет.',
    );
  }
}

// ---- мастера ----

class MechanicListScreen extends StatelessWidget {
  const MechanicListScreen({super.key, required this.query});

  final EntityQuery query;

  @override
  Widget build(BuildContext context) {
    return ReferenceListScreen<Mechanic, MechanicListNotifier>(
      query: query,
      title: 'Мастера',
      addLabel: 'Добавить мастера',
      searchHint: 'ФИО или телефон',
      sortLabels: const {
        'name': 'ФИО',
        'grade': 'Разряд',
        'experience': 'Стаж',
      },
      filters: [
        ListFilter(
          key: 'grade',
          label: 'Разряд',
          allLabel: 'Любой',
          options: [for (var g = 1; g <= 6; g++) Option('$g', '$g разряд')],
        ),
      ],
      nouns: ('мастер', 'мастера', 'мастеров'),
      labelOf: (m) => m.shortName,
      cardTitle: (m) => m.fullName,
      cardSubtitle: (m) =>
          '${m.grade} разряд · стаж ${m.experience} '
          '${plural(m.experience, 'год', 'года', 'лет')}\n${m.phone}',
      hardDeleteNote: (m) =>
          'Мастер будет откреплён от всех автомобилей, сами автомобили останутся.',
      columns: [
        nameColumn<Mechanic>('ФИО', (m) => m.fullName, sortField: 'name'),
        TableColumnSpec(label: 'Телефон', build: (m) => Text(m.phone)),
        TableColumnSpec(
          label: 'Разряд',
          sortField: 'grade',
          numeric: true,
          build: (m) => Text('${m.grade}'),
        ),
        TableColumnSpec(
          label: 'Стаж',
          sortField: 'experience',
          numeric: true,
          build: (m) => Text(
            '${m.experience} ${plural(m.experience, 'год', 'года', 'лет')}',
          ),
        ),
        TableColumnSpec(
          label: 'В сервисе с',
          build: (m) => Text(formatDate(m.hiredAt)),
        ),
      ],
    );
  }
}

class MechanicDetailScreen extends StatelessWidget {
  const MechanicDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return ReferenceDetailScreen<Mechanic, MechanicListNotifier>(
      id: id,
      pageTitle: 'Мастер',
      backLabel: 'К списку мастеров',
      notFoundText: 'Мастер не найден',
      heading: (m) => m.fullName,
      labelOf: (m) => m.shortName,
      tiles: (m) => [
        InfoTile(label: 'Телефон', value: SelectableText(m.phone)),
        InfoTile(label: 'Разряд', value: Text('${m.grade}')),
        InfoTile(
          label: 'Общий стаж',
          value: Text(
            '${m.experience} ${plural(m.experience, 'год', 'года', 'лет')}',
          ),
        ),
        InfoTile(label: 'В сервисе с', value: Text(formatDate(m.hiredAt))),
      ],
      relatedTitle: 'Закреплённые автомобили',
      relatedLocation: (m) => '/cars?mechanicId=${m.id}',
      relatedEmpty: 'За мастером пока не закреплено ни одного автомобиля.',
      hardDeleteNote: (m) =>
          'Мастер будет откреплён от всех автомобилей, сами автомобили останутся.',
    );
  }
}

// ---- услуги ----

class ServiceListScreen extends StatelessWidget {
  const ServiceListScreen({super.key, required this.query});

  final EntityQuery query;

  @override
  Widget build(BuildContext context) {
    final lookup = context.watch<LookupNotifier>();
    return ReferenceListScreen<ServiceItem, ServiceListNotifier>(
      query: query,
      title: 'Услуги',
      addLabel: 'Добавить услугу',
      searchHint: 'Название услуги',
      sortLabels: const {
        'name': 'Название',
        'price': 'Цена',
        'duration': 'Время',
      },
      filters: [
        ListFilter(
          key: 'category',
          label: 'Категория',
          allLabel: 'Все категории',
          options: [for (final c in lookup.categories) Option(c.id, c.name)],
        ),
      ],
      nouns: ('услуга', 'услуги', 'услуг'),
      labelOf: (s) => s.name,
      cardTitle: (s) => s.name,
      cardSubtitle: (s) =>
          '${lookup.categoryName(s.categoryId)} · ${formatMoney(s.price)} · '
          '${formatDuration(s.duration)}',
      columns: [
        nameColumn<ServiceItem>('Услуга', (s) => s.name, sortField: 'name'),
        TableColumnSpec(
          label: 'Категория',
          build: (s) => Text(lookup.categoryName(s.categoryId)),
        ),
        TableColumnSpec(
          label: 'Цена',
          sortField: 'price',
          numeric: true,
          build: (s) => Text(formatMoney(s.price)),
        ),
        TableColumnSpec(
          label: 'Норма времени',
          sortField: 'duration',
          numeric: true,
          build: (s) => Text(formatDuration(s.duration)),
        ),
      ],
    );
  }
}

class ServiceDetailScreen extends StatelessWidget {
  const ServiceDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final lookup = context.watch<LookupNotifier>();
    return ReferenceDetailScreen<ServiceItem, ServiceListNotifier>(
      id: id,
      pageTitle: 'Услуга',
      backLabel: 'К списку услуг',
      notFoundText: 'Услуга не найдена',
      heading: (s) => s.name,
      labelOf: (s) => s.name,
      tiles: (s) => [
        InfoTile(
          label: 'Категория',
          value: Text(lookup.categoryName(s.categoryId)),
        ),
        InfoTile(label: 'Цена', value: Text(formatMoney(s.price))),
        InfoTile(
          label: 'Норма времени',
          value: Text(formatDuration(s.duration)),
        ),
      ],
    );
  }
}

// ---- категории услуг ----

class CategoryListScreen extends StatelessWidget {
  const CategoryListScreen({super.key, required this.query});

  final EntityQuery query;

  @override
  Widget build(BuildContext context) {
    final lookup = context.watch<LookupNotifier>();
    int count(ServiceCategory c) =>
        lookup.services.where((s) => s.categoryId == c.id).length;
    return ReferenceListScreen<ServiceCategory, CategoryListNotifier>(
      query: query,
      title: 'Категории услуг',
      addLabel: 'Добавить категорию',
      searchHint: 'Название категории',
      sortLabels: const {'name': 'Название'},
      nouns: ('категория', 'категории', 'категорий'),
      labelOf: (c) => c.name,
      cardTitle: (c) => c.name,
      cardSubtitle: (c) => 'услуг: ${count(c)}',
      columns: [
        nameColumn<ServiceCategory>(
          'Категория',
          (c) => c.name,
          sortField: 'name',
        ),
        TableColumnSpec(
          label: 'Услуг',
          numeric: true,
          build: (c) => Text('${count(c)}'),
        ),
      ],
    );
  }
}

class CategoryDetailScreen extends StatelessWidget {
  const CategoryDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final lookup = context.watch<LookupNotifier>();
    return ReferenceDetailScreen<ServiceCategory, CategoryListNotifier>(
      id: id,
      pageTitle: 'Категория услуг',
      backLabel: 'К списку категорий',
      notFoundText: 'Категория не найдена',
      heading: (c) => c.name,
      labelOf: (c) => c.name,
      tiles: (c) => [
        SizedBox(
          width: 560,
          child: InfoTile(
            label: 'Услуги категории',
            value: Text(
              lookup.services
                  .where((s) => s.categoryId == c.id)
                  .map((s) => s.name)
                  .join(', '),
            ),
          ),
        ),
      ],
    );
  }
}
