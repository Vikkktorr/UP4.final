import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/permissions.dart';
import '../core/validators.dart';
import '../models/car_model.dart';
import '../repositories/car_model_repository.dart';
import '../state/auth_notifier.dart';
import '../state/lookup_notifier.dart';
import 'detail_view.dart';
import 'list_toolbar.dart';

/// Модели марки на её карточке: марка → модели — связь «один ко многим».
/// Модель добавляется и переименовывается в диалоге, удаляется кнопкой:
/// мастер удаляет логически, администратор — насовсем (если автомобилей
/// этой модели нет, иначе сервер ответит 409).
class BrandModels extends StatelessWidget {
  const BrandModels({super.key, required this.brandId});

  final String brandId;

  Future<void> _edit(BuildContext context, [CarModel? model]) async {
    final repository = context.read<CarModelRepository>();
    final saved = await showDialog<String>(
      context: context,
      builder: (_) => _ModelDialog(
        initial: model?.name ?? '',
        save: (name) async {
          final next = CarModel(
            id: model?.id ?? '',
            brandId: brandId,
            name: name,
          );
          model == null
              ? await repository.create(next)
              : await repository.update(next);
        },
      ),
    );
    if (saved != null && context.mounted) {
      showMessage(
        context,
        model == null ? 'Модель «$saved» добавлена' : 'Модель переименована',
      );
    }
  }

  Future<void> _delete(BuildContext context, CarModel model) async {
    final repository = context.read<CarModelRepository>();
    final hard = context.read<AuthNotifier>().can(Operation.hardDelete);
    final ok = await confirmAction(
      context,
      title: 'Удалить модель?',
      message: hard
          ? 'Модель «${model.name}» будет стёрта. Если есть автомобили этой '
                'модели, сервер не разрешит удаление.'
          : 'Модель «${model.name}» пропадёт из списка моделей марки.',
      confirmLabel: 'Удалить',
    );
    if (!ok) return;
    try {
      hard
          ? await repository.hardDelete(model.id)
          : await repository.softDelete(model.id);
      if (context.mounted) {
        showMessage(context, 'Модель «${model.name}» удалена');
      }
    } on ApiException catch (e) {
      if (context.mounted) showMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lookup = context.watch<LookupNotifier>();
    final canEdit = context.watch<AuthNotifier>().can(Operation.editRecords);
    final models = lookup.modelsOf(brandId);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Модели (${models.length})',
          trailing: canEdit
              ? TextButton.icon(
                  onPressed: () => _edit(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить модель'),
                )
              : null,
        ),
        if (models.isEmpty)
          Text(
            'У марки пока нет моделей.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in models)
                canEdit
                    ? InputChip(
                        label: Text(m.name),
                        tooltip: 'Переименовать',
                        onPressed: () => _edit(context, m),
                        deleteButtonTooltipMessage: 'Удалить модель',
                        onDeleted: () => _delete(context, m),
                      )
                    : Chip(label: Text(m.name)),
            ],
          ),
      ],
    );
  }
}

class _ModelDialog extends StatefulWidget {
  const _ModelDialog({required this.initial, required this.save});

  final String initial;
  final Future<void> Function(String name) save;

  @override
  State<_ModelDialog> createState() => _ModelDialogState();
}

class _ModelDialogState extends State<_ModelDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial);
  String? _serverError;
  bool _saving = false;

  static final _validator = all([requiredText(), maxLength(40)]);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _serverError = null);
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final name = _name.text.trim();
    try {
      await widget.save(name);
      if (mounted) Navigator.of(context).pop(name);
    } on ValidationException catch (e) {
      // Например, такая модель у марки уже есть (уникальный индекс).
      setState(() => _serverError = e.errors['name'] ?? e.message);
    } on ApiException catch (e) {
      setState(() => _serverError = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial.isEmpty ? 'Новая модель' : 'Изменение модели'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, minWidth: 280),
        child: Form(
          key: _form,
          child: TextFormField(
            controller: _name,
            autofocus: true,
            maxLength: 40,
            decoration: InputDecoration(
              labelText: 'Название модели',
              border: const OutlineInputBorder(),
              errorText: _serverError,
            ),
            validator: (v) => _validator(v ?? ''),
            onFieldSubmitted: (_) => _submit(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
