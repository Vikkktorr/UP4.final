import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/formatting.dart';
import '../../core/validators.dart';
import '../../models/car.dart';
import '../../models/fuel_type.dart';
import '../../repositories/car_repository.dart';
import '../../state/lookup_notifier.dart';
import '../../widgets/entity_form/entity_form_screen.dart';
import '../../widgets/entity_form/form_spec.dart';

/// Форма автомобиля — один экран на создание (/cars/new) и изменение
/// (/cars/:id/edit). Различие только в том, передан ли [id].
class CarFormScreen extends StatelessWidget {
  const CarFormScreen({super.key, this.id});

  final String? id;

  bool get isEditing => id != null;

  @override
  Widget build(BuildContext context) {
    final lookup = context.watch<LookupNotifier>();
    final repository = context.read<CarRepository>();

    return Title(
      title:
          '${isEditing ? 'Изменение автомобиля' : 'Новый автомобиль'} — Автосервис',
      color: Theme.of(context).colorScheme.primary,
      child: EntityFormScreen(
        title: isEditing ? 'Изменение автомобиля' : 'Новый автомобиль',
        submitLabel: isEditing ? 'Сохранить изменения' : 'Добавить автомобиль',
        ready: lookup.loaded,
        notFoundText: 'Автомобиль №$id не найден',
        onBack: () => context.go('/cars'),
        load: () async {
          if (!isEditing) {
            return {
              'id': '',
              'fuel': FuelType.petrol.code,
              'mechanics': <String>[],
            };
          }
          final car = await repository.findById(id!);
          if (car == null) return null;
          // Марки в записи автомобиля нет — она определяется моделью.
          // В форме она нужна, чтобы сузить список моделей.
          return {...car.toJson(), 'brand': lookup.brandIdOfModel(car.modelId)};
        },
        fields: (values) => carFields(values, lookup),
        save: (json) async {
          final car = Car.fromJson(json);
          final saved = isEditing
              ? await repository.update(car)
              : await repository.create(car);
          return saved.id;
        },
        onSaved: (savedId) => context.go('/cars/$savedId'),
      ),
    );
  }
}

/// Описание полей формы автомобиля.
///
/// Вынесено в функцию верхнего уровня: так его можно проверить в тесте
/// без экрана.
List<FormItem> carFields(FormValues values, LookupNotifier lookup) {
  final brandId = values['brand'] as String?;
  final brand = brandId == null ? null : lookup.brand(brandId);
  final clientId = values['client'] as String?;
  final client = clientId == null ? null : lookup.client(clientId);

  // Каскад: список моделей зависит от выбранной марки. Пока марка не
  // выбрана, выбирать модель не из чего; при смене марки модель прежней
  // марки исчезает из вариантов, и форма сбрасывает её.
  final models = brand == null ? const [] : lookup.modelsOf(brand.id);

  return [
    TextSpec(
      path: 'plate',
      label: 'Госномер',
      hint: 'А123ВС77',
      maxLength: 9,
      capitalization: TextCapitalization.characters,
      normalize: normalizePlate,
      validator: all([requiredText(), plate()]),
    ),
    TextSpec(
      path: 'vin',
      label: 'VIN',
      hint: '17 знаков',
      maxLength: 17,
      capitalization: TextCapitalization.characters,
      formatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]'))],
      normalize: (v) => v.toUpperCase(),
      validator: all([requiredText(), vin()]),
    ),
    ChoiceSpec(
      path: 'brand',
      label: 'Марка',
      options: [
        for (final b in lookup.brands) Option(b.id, b.name, hint: b.country),
        // Марка, выбранная раньше и с тех пор удалённая, остаётся в списке
        // с пометкой — иначе значение пропало бы из вариантов молча.
        if (brand != null && brand.isDeleted)
          Option(brand.id, '${brand.name} (удалена)'),
      ],
      validator: requiredChoice('Выберите марку'),
    ),
    ChoiceSpec(
      path: 'model',
      label: 'Модель',
      hint: brand == null ? 'Сначала выберите марку' : null,
      helper: brand == null
          ? null
          : '${models.length} ${plural(models.length, 'модель', 'модели', 'моделей')} марки ${brand.name}',
      options: [for (final m in models) Option(m.id, m.name)],
      validator: requiredChoice(
        brand == null ? 'Сначала выберите марку' : 'Выберите модель',
      ),
    ),
    TextSpec(
      path: 'year',
      label: 'Год выпуска',
      kind: TextKind.integer,
      maxLength: 4,
      keyboardType: TextInputType.number,
      formatters: [FilteringTextInputFormatter.digitsOnly],
      validator: year(),
    ),
    TextSpec(
      path: 'mileage',
      label: 'Пробег',
      kind: TextKind.integer,
      suffix: 'км',
      maxLength: 7,
      keyboardType: TextInputType.number,
      formatters: [FilteringTextInputFormatter.digitsOnly],
      validator: nonNegative(max: 2000000),
    ),
    ChoiceSpec(
      path: 'fuel',
      label: 'Двигатель',
      options: [for (final f in FuelType.values) Option(f.code, f.title)],
      validator: requiredChoice('Выберите тип двигателя'),
    ),
    ChoiceSpec(
      path: 'client',
      label: 'Владелец',
      options: [
        for (final c in lookup.clients) Option(c.id, c.fullName, hint: c.phone),
        if (client != null && client.isDeleted)
          Option(client.id, '${client.fullName} (удалён)'),
      ],
      validator: requiredChoice('Выберите владельца'),
    ),
    MultiChoiceSpec(
      path: 'mechanics',
      label: 'Закреплённые мастера',
      helper: 'От одного до трёх мастеров',
      options: [
        for (final m in lookup.mechanics)
          Option(m.id, m.shortName, hint: '${m.grade} разряд'),
        for (final id in values['mechanics'] as List<String>? ?? const [])
          if (lookup.mechanic(id) case final m? when m.isDeleted)
            Option(m.id, '${m.shortName} (удалён)'),
      ],
      validator: allList([
        atLeastOne('Закрепите хотя бы одного мастера'),
        atMost(3, 'мастеров'),
      ]),
    ),
  ];
}
