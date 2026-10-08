import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exceptions.dart';
import '../../core/breakpoints.dart';
import '../../core/formatting.dart';
import '../list_toolbar.dart';
import 'form_spec.dart';
import 'leave_guard.dart';

typedef FormValues = Map<String, Object?>;

/// Общий экран формы создания и изменения записи.
///
/// Разметка, проверка, отправка, показ ошибок уникальности под полем
/// и предупреждение о несохранённых изменениях — здесь. Экран сущности
/// передаёт только описание полей [fields] и функции загрузки и сохранения.
class EntityFormScreen extends StatefulWidget {
  const EntityFormScreen({
    super.key,
    required this.title,
    required this.submitLabel,
    required this.load,
    required this.fields,
    required this.save,
    required this.onSaved,
    required this.onBack,
    this.ready = true,
    this.notFoundText = 'Запись не найдена',
  });

  final String title;
  final String submitLabel;

  /// JSON записи: при изменении — загруженной, при создании — заготовка.
  /// null — записи с таким номером нет.
  final Future<Map<String, dynamic>?> Function() load;

  /// Описание полей. Вызывается при каждой перестройке с текущими
  /// значениями — так варианты одного поля зависят от другого.
  final List<FormItem> Function(FormValues values) fields;

  /// Сохраняет JSON и возвращает идентификатор записи.
  final Future<String> Function(Map<String, dynamic> json) save;
  final void Function(String id) onSaved;
  final VoidCallback onBack;

  /// Справочники для выпадающих списков загружены.
  final bool ready;
  final String notFoundText;

  @override
  State<EntityFormScreen> createState() => _EntityFormScreenState();
}

class _EntityFormScreenState extends State<EntityFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};

  /// Ошибки, которые вернул сервер с кодом 422 (дубликат VIN, почты).
  /// Показываются через validator своего поля, пока пользователь не
  /// изменит значение.
  final _serverErrors = <String, String>{};

  Map<String, dynamic>? _json;
  FormValues _values = {};
  FormValues _initial = {};
  bool _loading = true;
  bool _notFound = false;
  String? _loadError;
  bool _saving = false;
  bool _allowLeave = false;
  var _autovalidate = AutovalidateMode.disabled;

  late final LeaveGuard _guard;

  @override
  void initState() {
    super.initState();
    _guard = context.read<LeaveGuard>();
    _guard.register(_canLeave);
    if (widget.ready) _load();
  }

  @override
  void didUpdateWidget(EntityFormScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Справочники догрузились после открытия формы.
    if (widget.ready && !oldWidget.ready && _json == null) _load();
  }

  @override
  void dispose() {
    _guard.unregister(_canLeave);
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Поля заполняются только после загрузки записи. Если создать
  /// контроллеры раньше, форма редактирования откроется пустой.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final json = await widget.load();
      if (!mounted) return;
      if (json == null) {
        setState(() {
          _notFound = true;
          _loading = false;
        });
        return;
      }
      final values = <String, Object?>{};
      for (final spec in flattenFields(widget.fields(const {}))) {
        values[spec.path] = spec.toUi(readPath(json, spec.path));
      }
      for (final entry in values.entries) {
        final value = entry.value;
        if (value is String) {
          _controllers[entry.key]?.dispose();
          _controllers[entry.key] = TextEditingController(text: value);
        }
      }
      setState(() {
        _json = json;
        _values = values;
        _initial = _copy(values);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = 'Не удалось загрузить запись: $e';
          _loading = false;
        });
      }
    }
  }

  static FormValues _copy(FormValues v) => {
    for (final e in v.entries)
      e.key: e.value is List ? List.of(e.value as List) : e.value,
  };

  bool get _dirty =>
      !_allowLeave && !const DeepCollectionEquality().equals(_values, _initial);

  void _set(String path, Object? value) {
    setState(() {
      _values[path] = value;
      _serverErrors.remove(path);
      _dropUnavailable();
    });
  }

  /// Каскад: если после изменения одного поля выбранное значение другого
  /// исчезло из вариантов (сменили марку — модель прежней марки больше не
  /// подходит), значение сбрасывается, и поле требует выбрать заново.
  void _dropUnavailable() {
    for (final spec in flattenFields(widget.fields(_values))) {
      final value = _values[spec.path];
      switch (spec) {
        case ChoiceSpec(:final options) when value != null:
          if (!options.any((o) => o.value == value)) _values[spec.path] = null;
        case MultiChoiceSpec(:final options):
          final ids = (value as List<String>?) ?? const [];
          final kept = ids.where((id) => options.any((o) => o.value == id));
          if (kept.length != ids.length) _values[spec.path] = kept.toList();
        default:
          break;
      }
    }
  }

  Future<bool> _confirmDiscard() => confirmAction(
    context,
    title: 'Уйти без сохранения?',
    message: 'В форме есть несохранённые изменения. Если уйти, они пропадут.',
    confirmLabel: 'Уйти',
    cancelLabel: 'Остаться',
  );

  Future<bool> _canLeave() async {
    if (!_dirty || !mounted) return true;
    final ok = await _confirmDiscard();
    if (ok) _allowLeave = true;
    return ok;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    _serverErrors.clear();
    setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
    if (!_formKey.currentState!.validate()) return;

    // Копия исходного JSON: поля, которых нет в форме (id, deletedAt),
    // сохраняются как были.
    final json = jsonDecode(jsonEncode(_json)) as Map<String, dynamic>;
    for (final spec in flattenFields(widget.fields(_values))) {
      writePath(json, spec.path, spec.toJson(_values[spec.path]));
    }

    setState(() => _saving = true);
    try {
      final id = await widget.save(json);
      if (!mounted) return;
      _allowLeave = true;
      widget.onSaved(id);
    } on ValidationException catch (e) {
      if (!mounted) return;
      // Ключи errors совпадают с именами полей формы — ошибки раскладываются
      // по полям без сопоставления вручную. Результат передаётся в validator
      // поля, и ошибка появляется под ним, как любая другая.
      final paths = {
        for (final s in flattenFields(widget.fields(_values))) s.path,
      };
      setState(() => _serverErrors.addAll(e.errors));
      _formKey.currentState!.validate(); // перерисовать поля с новыми ошибками
      // Ошибка поля, которого нет в форме, показывается общим сообщением.
      final other = e.errors.entries.where((x) => !paths.contains(x.key));
      if (e.errors.isEmpty || other.isNotEmpty) {
        showMessage(context, other.isEmpty ? e.message : other.first.value);
      }
    } on ConflictException catch (e) {
      // 409: у мастера нет свободных мест и подобные конфликты.
      if (mounted) showMessage(context, e.message);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!widget.ready || _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_notFound || _loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _notFound ? Icons.help_outline : Icons.cloud_off,
              size: 56,
              color: _notFound
                  ? theme.colorScheme.outline
                  : theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              _loadError ?? widget.notFoundText,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Назад'),
                ),
                if (_loadError != null)
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Повторить'),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    final items = widget.fields(_values);
    final dirty = _dirty;

    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard()) {
          _allowLeave = true;
          navigator.pop();
        }
      },
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Form(
            key: _formKey,
            autovalidateMode: _autovalidate,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Назад',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) =>
                        _layout(items, constraints.maxWidth),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).maybePop(),
                        child: const Text('Отмена'),
                      ),
                      FilledButton.icon(
                        onPressed: _saving ? null : _submit,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(widget.submitLabel),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Поля выстраиваются в две колонки на широком окне и в одну на узком.
  Widget _layout(List<FormItem> items, double width) {
    const gap = 16.0;
    final twoColumns = width >= Breakpoints.compact - 40;

    List<Widget> place(List<FieldSpec> fields, double available) {
      final half = twoColumns ? (available - gap) / 2 : available;
      return [
        for (final spec in fields)
          SizedBox(width: spec.wide ? available : half, child: _field(spec)),
      ];
    }

    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final item in items)
          switch (item) {
            FieldSpec() => SizedBox(
              width: item.wide || !twoColumns ? width : (width - gap) / 2,
              child: _field(item),
            ),
            FormGroup() => _group(item, width, place),
          },
      ],
    );
  }

  Widget _group(
    FormGroup group,
    double width,
    List<Widget> Function(List<FieldSpec>, double) place,
  ) {
    final theme = Theme.of(context);
    const padding = 16.0;
    return SizedBox(
      width: width,
      child: Card.outlined(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (group.icon != null) ...[
                    Icon(group.icon, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                  ],
                  Text(group.title, style: theme.textTheme.titleMedium),
                ],
              ),
              if (group.subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  group.subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: place(group.fields, width - padding * 2 - 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _serverOr(String path, String? Function() check) =>
      _serverErrors[path] ?? check();

  Widget _field(FieldSpec spec) {
    final path = spec.path;
    return switch (spec) {
      TextSpec() => TextFormField(
        key: ValueKey('field-$path'),
        // Только controller, без initialValue: вместе их задавать нельзя.
        controller: _controllers.putIfAbsent(
          path,
          () => TextEditingController(text: _values[path] as String? ?? ''),
        ),
        decoration: InputDecoration(
          labelText: spec.label,
          hintText: spec.hint,
          helperText: spec.helper,
          suffixText: spec.suffix,
          border: const OutlineInputBorder(),
          counterText: '',
        ),
        maxLength: spec.maxLength,
        keyboardType: spec.keyboardType,
        inputFormatters: spec.formatters,
        textCapitalization: spec.capitalization,
        enabled: !_saving,
        onChanged: (v) => _set(path, v),
        validator: (v) => _serverOr(path, () => spec.validator?.call(v ?? '')),
      ),
      ChoiceSpec() => _choice(spec),
      MultiChoiceSpec() => _multi(spec),
      DateSpec() => _date(spec),
    };
  }

  Widget _choice(ChoiceSpec spec) {
    final path = spec.path;
    final value = _values[path];
    // Значение обязано быть среди вариантов, иначе DropdownButton бросит
    // исключение. Ключ зависит от набора вариантов: при каскадной смене
    // поле пересоздаётся с актуальным значением.
    final present = spec.options.any((o) => o.value == value);
    return DropdownButtonFormField<Object>(
      key: ValueKey(
        'field-$path-${spec.options.map((o) => o.value).join(',')}',
      ),
      initialValue: present ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: spec.label,
        helperText: spec.helper,
        border: const OutlineInputBorder(),
      ),
      hint: spec.hint == null ? null : Text(spec.hint!),
      items: [
        for (final o in spec.options)
          DropdownMenuItem<Object>(
            value: o.value,
            child: Text(
              o.hint == null ? o.label : '${o.label} · ${o.hint}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: _saving ? null : (v) => _set(path, v),
      validator: (v) => _serverOr(path, () => spec.validator?.call(v)),
    );
  }

  Widget _multi(MultiChoiceSpec spec) {
    final path = spec.path;
    final theme = Theme.of(context);
    return FormField<List<String>>(
      key: ValueKey('field-$path'),
      initialValue: List.of(_values[path] as List<String>? ?? const []),
      // Проверяется общее значение: каскад мог сузить выбор без участия
      // самого поля.
      validator: (_) => _serverOr(
        path,
        () => spec.validator?.call(_values[path] as List<String>? ?? const []),
      ),
      builder: (field) {
        // Значение поля берётся из общего состояния: каскад мог его сузить.
        final selected = _values[path] as List<String>? ?? const [];
        return InputDecorator(
          decoration: InputDecoration(
            labelText: '${spec.label} (выбрано: ${selected.length})',
            helperText: spec.helper,
            border: const OutlineInputBorder(),
            errorText: field.errorText,
          ),
          child: spec.options.isEmpty
              ? Text(
                  spec.emptyText,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final o in spec.options)
                      FilterChip(
                        label: Text(o.label),
                        tooltip: o.hint,
                        selected: selected.contains(o.value),
                        onSelected: _saving
                            ? null
                            : (_) {
                                final next = [...selected];
                                selected.contains(o.value)
                                    ? next.remove(o.value)
                                    : next.add(o.value as String);
                                // Без didChange форма не узнает о новом
                                // значении и проверит старое.
                                field.didChange(next);
                                _set(path, next);
                              },
                      ),
                  ],
                ),
        );
      },
    );
  }

  Widget _date(DateSpec spec) {
    final path = spec.path;
    return FormField<DateTime>(
      key: ValueKey('field-$path'),
      initialValue: _values[path] as DateTime?,
      validator: (_) => _serverOr(
        path,
        () => spec.validator?.call(_values[path] as DateTime?),
      ),
      builder: (field) {
        final value = _values[path] as DateTime?;
        return InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: _saving
              ? null
              : () async {
                  final initial = value ?? DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial.isBefore(spec.firstDate)
                        ? spec.firstDate
                        : initial.isAfter(spec.lastDate)
                        ? spec.lastDate
                        : initial,
                    firstDate: spec.firstDate,
                    lastDate: spec.lastDate,
                  );
                  if (picked == null) return;
                  field.didChange(picked);
                  _set(path, picked);
                },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: spec.label,
              helperText: spec.helper,
              border: const OutlineInputBorder(),
              errorText: field.errorText,
              suffixIcon: const Icon(Icons.calendar_today_outlined),
            ),
            child: Text(value == null ? '' : formatDate(value)),
          ),
        );
      },
    );
  }
}
