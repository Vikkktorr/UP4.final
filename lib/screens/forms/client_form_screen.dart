import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_exceptions.dart';
import '../../core/json.dart';
import '../../core/validators.dart';
import '../../models/client.dart';
import '../../models/club_card.dart';
import '../../repositories/client_repository.dart';
import '../../repositories/club_card_repository.dart';
import '../../widgets/entity_form/entity_form_screen.dart';
import '../../widgets/entity_form/form_spec.dart';

/// Форма клиента вместе с клубной картой. Карта — отдельная запись
/// club_cards, связанная с клиентом «один к одному»; в форме её поля —
/// вложенная группа. Сохраняется сначала клиент, затем его карта.
class ClientFormScreen extends StatelessWidget {
  const ClientFormScreen({super.key, this.id});

  final String? id;

  bool get isEditing => id != null;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<ClientRepository>();
    final cards = context.read<ClubCardRepository>();
    final today = DateTime.now();

    return Title(
      title: '${isEditing ? 'Изменение клиента' : 'Новый клиент'} — Автосервис',
      color: Theme.of(context).colorScheme.primary,
      child: EntityFormScreen(
        title: isEditing ? 'Изменение клиента' : 'Новый клиент',
        submitLabel: isEditing ? 'Сохранить изменения' : 'Добавить клиента',
        notFoundText: 'Клиент №$id не найден',
        onBack: () => context.go('/clients'),
        load: () async {
          final newCard = {
            'id': '',
            'level': CardLevel.standard.code,
            'issued_at': dateToJson(today),
            'expires_at': dateToJson(
              DateTime(today.year + 3, today.month, today.day),
            ),
            'bonus_points': 0,
          };
          if (!isEditing) {
            return {
              'id': '',
              'discount': 0,
              'registered_at': dateToJson(today),
              'card': newCard,
            };
          }
          final client = await repository.findById(id!);
          if (client == null) return null;
          // Карты у клиента может не быть (зарегистрировался сам) —
          // тогда форма предложит выдать новую.
          return {...client.toJson(), 'card': client.card?.toJson() ?? newCard};
        },
        fields: clientFields,
        save: (json) async {
          final client = Client.fromJson(json);
          final saved = isEditing
              ? await repository.update(client)
              : await repository.create(client);
          final card = ClubCard.fromJson({
            ...(json['card'] as Map).cast<String, dynamic>(),
            'client': saved.id,
          });
          try {
            await cards.save(card);
          } on ValidationException catch (e) {
            // Ошибки карты приходят с именами полей карты — показываем их
            // у полей вложенной группы.
            throw ValidationException(e.message, {
              for (final MapEntry(:key, :value) in e.errors.entries)
                'card.$key': value,
            });
          }
          return saved.id;
        },
        onSaved: (savedId) => context.go('/clients/$savedId'),
      ),
    );
  }
}

List<FormItem> clientFields(FormValues values) {
  final issued = values['card.issued_at'] as DateTime?;
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
    TextSpec(
      path: 'email',
      label: 'E-mail',
      hint: 'name@example.ru',
      maxLength: 60,
      keyboardType: TextInputType.emailAddress,
      normalize: (v) => v.toLowerCase(),
      validator: all([requiredText(), maxLength(60), email()]),
    ),
    TextSpec(
      path: 'discount',
      label: 'Персональная скидка',
      kind: TextKind.integer,
      suffix: '%',
      maxLength: 2,
      keyboardType: TextInputType.number,
      formatters: [FilteringTextInputFormatter.digitsOnly],
      validator: intRange(0, 30, unit: '%'),
    ),
    DateSpec(
      path: 'registered_at',
      label: 'Клиент с',
      firstDate: DateTime(2000),
      lastDate: now,
      validator: notInFuture(),
    ),
    FormGroup(
      title: 'Клубная карта',
      subtitle: 'Одна карта на одного клиента',
      icon: Icons.card_membership_outlined,
      fields: [
        TextSpec(
          path: 'card.number',
          label: 'Номер карты',
          hint: 'AS-000123',
          maxLength: 9,
          capitalization: TextCapitalization.characters,
          normalize: (v) => v.toUpperCase(),
          validator: all([
            requiredText(),
            pattern(RegExp(r'^[Aa][Ss]-\d{6}$'), 'Формат AS-000123'),
          ]),
        ),
        ChoiceSpec(
          path: 'card.level',
          label: 'Уровень',
          options: [for (final l in CardLevel.values) Option(l.code, l.title)],
          validator: requiredChoice('Выберите уровень карты'),
        ),
        DateSpec(
          path: 'card.issued_at',
          label: 'Дата выдачи',
          firstDate: DateTime(2000),
          lastDate: now,
          validator: notInFuture(),
        ),
        DateSpec(
          path: 'card.expires_at',
          label: 'Действует до',
          firstDate: DateTime(2000),
          lastDate: DateTime(now.year + 15),
          validator: after(issued, 'Позже даты выдачи'),
        ),
        TextSpec(
          path: 'card.bonus_points',
          label: 'Бонусные баллы',
          kind: TextKind.integer,
          maxLength: 6,
          keyboardType: TextInputType.number,
          formatters: [FilteringTextInputFormatter.digitsOnly],
          validator: nonNegative(max: 100000),
        ),
      ],
    ),
  ];
}
