import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/json.dart';
import '../../core/validators.dart';
import '../../models/brand.dart';
import '../../models/mechanic.dart';
import '../../models/service_category.dart';
import '../../models/service_item.dart';
import '../../repositories/brand_repository.dart';
import '../../repositories/category_repository.dart';
import '../../repositories/mechanic_repository.dart';
import '../../repositories/service_repository.dart';
import '../../state/lookup_notifier.dart';
import '../../widgets/entity_form/entity_form_screen.dart';
import '../../widgets/entity_form/form_spec.dart';

/// Формы справочников. Каждая — только описание полей и функции
/// загрузки и сохранения; экран, проверка и отправка общие.

class BrandFormScreen extends StatelessWidget {
  const BrandFormScreen({super.key, this.id});

  final String? id;

  bool get isEditing => id != null;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<BrandRepository>();
    return EntityFormScreen(
      title: isEditing ? 'Изменение марки' : 'Новая марка',
      submitLabel: isEditing ? 'Сохранить изменения' : 'Добавить марку',
      notFoundText: 'Марка №$id не найдена',
      onBack: () => context.go('/brands'),
      load: () async =>
          isEditing ? (await repository.findById(id!))?.toJson() : {'id': ''},
      fields: brandFields,
      save: (json) async {
        final brand = Brand.fromJson(json);
        final saved = isEditing
            ? await repository.update(brand)
            : await repository.create(brand);
        return saved.id;
      },
      onSaved: (savedId) => context.go('/brands/$savedId'),
    );
  }
}

List<FormItem> brandFields(FormValues values) => [
  TextSpec(
    path: 'name',
    label: 'Название',
    maxLength: 30,
    validator: all([requiredText(), minLength(2), maxLength(30)]),
  ),
  TextSpec(
    path: 'country',
    label: 'Страна',
    maxLength: 30,
    capitalization: TextCapitalization.sentences,
    validator: all([requiredText(), minLength(2), maxLength(30), personName()]),
  ),
];

class MechanicFormScreen extends StatelessWidget {
  const MechanicFormScreen({super.key, this.id});

  final String? id;

  bool get isEditing => id != null;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<MechanicRepository>();
    return EntityFormScreen(
      title: isEditing ? 'Изменение мастера' : 'Новый мастер',
      submitLabel: isEditing ? 'Сохранить изменения' : 'Добавить мастера',
      notFoundText: 'Мастер №$id не найден',
      onBack: () => context.go('/mechanics'),
      load: () async => isEditing
          ? (await repository.findById(id!))?.toJson()
          : {'id': '', 'grade': 3, 'hired_at': dateToJson(DateTime.now())},
      fields: mechanicFields,
      save: (json) async {
        final mechanic = Mechanic.fromJson(json);
        final saved = isEditing
            ? await repository.update(mechanic)
            : await repository.create(mechanic);
        return saved.id;
      },
      onSaved: (savedId) => context.go('/mechanics/$savedId'),
    );
  }
}

List<FormItem> mechanicFields(FormValues values) {
  final now = DateTime.now();
  return [
    TextSpec(
      path: 'last_name',
      label: 'Фамилия',
      maxLength: 40,
      capitalization: TextCapitalization.words,
      validator: all([
        requiredText(),
        minLength(2),
        maxLength(40),
        personName(),
      ]),
    ),
    TextSpec(
      path: 'first_name',
      label: 'Имя',
      maxLength: 30,
      capitalization: TextCapitalization.words,
      validator: all([requiredText(), maxLength(30), personName()]),
    ),
    TextSpec(
      path: 'middle_name',
      label: 'Отчество',
      helper: 'Необязательно',
      maxLength: 30,
      capitalization: TextCapitalization.words,
      validator: optional([maxLength(30), personName()]),
    ),
    TextSpec(
      path: 'phone',
      label: 'Телефон',
      hint: '+7 (916) 123-45-67',
      maxLength: 18,
      keyboardType: TextInputType.phone,
      formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d+()\- ]'))],
      validator: all([requiredText(), phone()]),
    ),
    ChoiceSpec(
      path: 'grade',
      label: 'Разряд',
      options: [for (var g = 1; g <= 6; g++) Option(g, '$g разряд')],
      validator: requiredChoice('Выберите разряд'),
    ),
    DateSpec(
      path: 'hired_at',
      label: 'Дата приёма',
      firstDate: DateTime(1980),
      lastDate: now,
      validator: notInFuture(),
    ),
    TextSpec(
      path: 'experience',
      label: 'Общий стаж',
      kind: TextKind.integer,
      suffix: 'лет',
      maxLength: 2,
      keyboardType: TextInputType.number,
      formatters: [FilteringTextInputFormatter.digitsOnly],
      validator: intRange(0, 60, unit: 'лет'),
    ),
  ];
}

class ServiceFormScreen extends StatelessWidget {
  const ServiceFormScreen({super.key, this.id});

  final String? id;

  bool get isEditing => id != null;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<ServiceRepository>();
    final lookup = context.watch<LookupNotifier>();
    return EntityFormScreen(
      ready: lookup.loaded,
      title: isEditing ? 'Изменение услуги' : 'Новая услуга',
      submitLabel: isEditing ? 'Сохранить изменения' : 'Добавить услугу',
      notFoundText: 'Услуга №$id не найдена',
      onBack: () => context.go('/services'),
      load: () async =>
          isEditing ? (await repository.findById(id!))?.toJson() : {'id': ''},
      fields: (values) => serviceFields(values, lookup),
      save: (json) async {
        final service = ServiceItem.fromJson(json);
        final saved = isEditing
            ? await repository.update(service)
            : await repository.create(service);
        return saved.id;
      },
      onSaved: (savedId) => context.go('/services/$savedId'),
    );
  }
}

List<FormItem> serviceFields(FormValues values, LookupNotifier lookup) => [
  TextSpec(
    path: 'name',
    label: 'Название',
    maxLength: 60,
    wide: true,
    capitalization: TextCapitalization.sentences,
    validator: all([requiredText(), minLength(3), maxLength(60)]),
  ),
  ChoiceSpec(
    path: 'category',
    label: 'Категория',
    // Категории — из справочника на сервере.
    options: [for (final c in lookup.categories) Option(c.id, c.name)],
    validator: requiredChoice('Выберите категорию'),
  ),
  TextSpec(
    path: 'price',
    label: 'Цена',
    kind: TextKind.integer,
    suffix: '₽',
    maxLength: 6,
    keyboardType: TextInputType.number,
    formatters: [FilteringTextInputFormatter.digitsOnly],
    validator: positive(max: 500000, unit: '₽'),
  ),
  TextSpec(
    path: 'duration',
    label: 'Норма времени',
    kind: TextKind.integer,
    suffix: 'мин',
    maxLength: 4,
    keyboardType: TextInputType.number,
    formatters: [FilteringTextInputFormatter.digitsOnly],
    validator: all([
      positive(max: 1440, unit: 'мин'),
      (v) => (int.tryParse(v) ?? 0) % 5 != 0 ? 'Кратно 5 минутам' : null,
    ]),
  ),
];

class CategoryFormScreen extends StatelessWidget {
  const CategoryFormScreen({super.key, this.id});

  final String? id;

  bool get isEditing => id != null;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<CategoryRepository>();
    return EntityFormScreen(
      title: isEditing ? 'Изменение категории' : 'Новая категория услуг',
      submitLabel: isEditing ? 'Сохранить изменения' : 'Добавить категорию',
      notFoundText: 'Категория не найдена',
      onBack: () => context.go('/categories'),
      load: () async =>
          isEditing ? (await repository.findById(id!))?.toJson() : {'id': ''},
      fields: categoryFields,
      save: (json) async {
        final category = ServiceCategory.fromJson(json);
        final saved = isEditing
            ? await repository.update(category)
            : await repository.create(category);
        return saved.id;
      },
      onSaved: (savedId) => context.go('/categories/$savedId'),
    );
  }
}

List<FormItem> categoryFields(FormValues values) => [
  TextSpec(
    path: 'name',
    label: 'Название',
    maxLength: 40,
    wide: true,
    capitalization: TextCapitalization.sentences,
    validator: all([requiredText(), minLength(3), maxLength(40)]),
  ),
];
