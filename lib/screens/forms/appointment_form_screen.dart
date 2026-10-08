import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_exceptions.dart';
import '../../core/formatting.dart';
import '../../core/permissions.dart';
import '../../core/pricing.dart';
import '../../core/schedule.dart';
import '../../models/appointment.dart';
import '../../models/car.dart';
import '../../models/client.dart';
import '../../repositories/appointment_repository.dart';
import '../../repositories/car_repository.dart';
import '../../repositories/client_repository.dart';
import '../../state/auth_notifier.dart';
import '../../state/lookup_notifier.dart';
import '../../widgets/entity_form/leave_guard.dart';
import '../../widgets/list_toolbar.dart';

/// Запись автомобиля к мастеру — создание и изменение.
///
/// Под формой по мере выбора видно: когда мастер уже занят в выбранный
/// день, сколько займут работы, когда они закончатся и сколько будут стоить
/// с учётом скидки. Расчёт здесь — предпросмотр по тем же правилам, что на
/// сервере; окончательную сумму и проверку занятости выполняет сервер
/// (409 — время занято, 422 — вне рабочих часов).
class AppointmentFormScreen extends StatefulWidget {
  const AppointmentFormScreen({
    super.key,
    this.id,
    this.carId,
    this.mechanicId,
    required this.backLocation,
  });

  /// null — новая запись.
  final String? id;

  /// Автомобиль и мастер, выбранные заранее (из карточки, из графика).
  final String? carId;
  final String? mechanicId;
  final String backLocation;

  @override
  State<AppointmentFormScreen> createState() => _AppointmentFormScreenState();
}

/// Время начала с шагом в полчаса в пределах рабочего дня.
final List<({int hour, int minute})> startSlots = [
  for (var h = Schedule.openHour; h < Schedule.closeHour; h++)
    for (final m in const [0, 30]) (hour: h, minute: m),
];

class _AppointmentFormScreenState extends State<AppointmentFormScreen> {
  final _form = GlobalKey<FormState>();
  late final LeaveGuard _guard;

  List<Car>? _cars;
  Appointment? _original;
  String? _loadError;

  String? _carId;
  String? _mechanicId;
  final Set<String> _serviceIds = {};
  DateTime? _day;
  ({int hour, int minute})? _slot;
  final _comment = TextEditingController();

  Client? _client;
  List<BusySlot> _busy = const [];
  bool _saving = false;
  bool _dirty = false;

  /// Ошибки сервера: общая (409) и по полям (422/400).
  String? _conflict;
  Map<String, String> _fieldErrors = const {};

  bool get _isEditing => widget.id != null;

  @override
  void initState() {
    super.initState();
    _guard = context.read<LeaveGuard>();
    _guard.register(_canLeave);
    _load();
  }

  @override
  void dispose() {
    _guard.unregister(_canLeave);
    _comment.dispose();
    super.dispose();
  }

  Future<bool> _canLeave() async {
    if (!_dirty || _saving) return true;
    return confirmAction(
      context,
      title: 'Уйти без сохранения?',
      message: 'Запись не сохранена.',
      confirmLabel: 'Уйти',
      cancelLabel: 'Остаться',
    );
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      // Клиенту правило PocketBase отдаёт только его автомобили.
      final cars = (await context.read<CarRepository>().findAll())
          .where((c) => !c.isDeleted)
          .toList();
      Appointment? original;
      if (_isEditing && mounted) {
        original = await context.read<AppointmentRepository>().findById(
          widget.id!,
        );
      }
      if (!mounted) return;
      setState(() {
        _cars = cars;
        _original = original;
        if (original != null) {
          _carId = original.carId;
          _mechanicId = original.mechanicId;
          _serviceIds.addAll(original.serviceIds);
          _day = DateTime(
            original.startsAt.year,
            original.startsAt.month,
            original.startsAt.day,
          );
          _slot = (
            hour: original.startsAt.hour,
            minute: original.startsAt.minute,
          );
          _comment.text = original.comment;
        } else {
          _carId = widget.carId ?? (cars.length == 1 ? cars.single.id : null);
          _mechanicId = widget.mechanicId ?? _defaultMechanic();
        }
      });
      await _loadClient();
      await _loadBusy();
    } catch (e) {
      if (mounted) setState(() => _loadError = '$e');
    }
  }

  /// По умолчанию — первый из мастеров, закреплённых за автомобилем.
  String? _defaultMechanic() {
    final car = _car;
    return car == null || car.mechanicIds.isEmpty
        ? null
        : car.mechanicIds.first;
  }

  Car? get _car {
    for (final c in _cars ?? const <Car>[]) {
      if (c.id == _carId) return c;
    }
    return null;
  }

  /// Владелец нужен для предпросмотра скидки: персональная и по карте.
  Future<void> _loadClient() async {
    final car = _car;
    if (car == null) return;
    final client = await context.read<ClientRepository>().findById(
      car.clientId,
    );
    if (mounted) setState(() => _client = client);
  }

  /// Занятость мастера в выбранный день.
  Future<void> _loadBusy() async {
    final mechanic = _mechanicId;
    final day = _day;
    if (mechanic == null || day == null) {
      setState(() => _busy = const []);
      return;
    }
    try {
      final busy = await context.read<AppointmentRepository>().busy(
        mechanic,
        day,
        day.add(const Duration(days: 1)),
      );
      if (mounted) {
        setState(
          () => _busy = [
            for (final b in busy)
              if (b.id != widget.id) b,
          ],
        );
      }
    } catch (_) {
      // Занятость — подсказка; без неё сервер всё равно проверит время.
    }
  }

  void _changed(VoidCallback update) {
    setState(() {
      update();
      _dirty = true;
      _conflict = null;
      _fieldErrors = const {};
    });
  }

  int get _minutes {
    final lookup = context.read<LookupNotifier>();
    return _serviceIds.fold(
      0,
      (sum, id) => sum + (lookup.service(id)?.duration ?? 0),
    );
  }

  int get _subtotal {
    final lookup = context.read<LookupNotifier>();
    return _serviceIds.fold(
      0,
      (sum, id) => sum + (lookup.service(id)?.price ?? 0),
    );
  }

  DateTime? get _start {
    final day = _day;
    final slot = _slot;
    if (day == null || slot == null) return null;
    return DateTime(day.year, day.month, day.day, slot.hour, slot.minute);
  }

  /// Занят ли мастер, если начать в [slot].
  bool _slotBusy(({int hour, int minute}) slot) {
    final day = _day;
    if (day == null) return false;
    final start = DateTime(
      day.year,
      day.month,
      day.day,
      slot.hour,
      slot.minute,
    );
    final end = start.add(Duration(minutes: _minutes == 0 ? 30 : _minutes));
    return _busy.any((b) => Schedule.overlaps(start, end, b.start, b.end));
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day ?? now,
      firstDate: _isEditing ? DateTime(now.year - 1) : now,
      lastDate: DateTime(now.year + 1, now.month, now.day),
    );
    if (picked == null) return;
    _changed(() => _day = picked);
    await _loadBusy();
  }

  Future<void> _submit() async {
    setState(() {
      _conflict = null;
      _fieldErrors = const {};
    });
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final repository = context.read<AppointmentRepository>();
    final appointment = Appointment(
      id: widget.id ?? '',
      carId: _carId!,
      mechanicId: _mechanicId!,
      serviceIds: _serviceIds.toList(),
      startsAt: _start!,
      status: _original?.status ?? AppointmentStatus.planned,
      comment: _comment.text.trim(),
    );
    try {
      final saved = _isEditing
          ? await repository.update(appointment)
          : await repository.create(appointment);
      _dirty = false;
      if (!mounted) return;
      showMessage(
        context,
        'Записано на ${formatDateTime(saved.startsAt)}, '
        'к оплате ${formatMoney(saved.total)}',
      );
      final base = widget.backLocation == '/my'
          ? '/my/appointments'
          : '/appointments';
      context.go('$base/${saved.id}');
    } on ConflictException catch (e) {
      // Мастер занят: пока форма была открыта, это время могли занять.
      setState(() => _conflict = e.message);
      await _loadBusy();
    } on ValidationException catch (e) {
      setState(() => _fieldErrors = e.errors);
      _form.currentState!.validate();
    } on ApiException catch (e) {
      setState(() => _conflict = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lookup = context.watch<LookupNotifier>();
    final auth = context.watch<AuthNotifier>();
    final theme = Theme.of(context);
    final title = _isEditing ? 'Изменение записи' : 'Запись на обслуживание';

    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      );
    }
    if (_cars == null || !lookup.loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    final cars = _cars!;
    final staff = auth.can(Operation.manageAppointments);
    final start = _start;
    final minutes = _minutes;
    final discount = start == null
        ? null
        : Pricing.discount(
            personal: _client?.discount ?? 0,
            card: _client?.card,
            date: start,
          );

    InputDecoration deco(String label, {String? field}) => InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      errorText: field == null ? null : _fieldErrors[field],
    );

    return Title(
      title: '$title — Автосервис',
      color: theme.colorScheme.primary,
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Назад',
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => context.go(widget.backLocation),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (cars.isEmpty)
                    Text(
                      staff
                          ? 'Нет автомобилей — сначала добавьте автомобиль.'
                          : 'За вами пока не записано ни одного автомобиля. '
                                'Обратитесь к мастеру автосервиса.',
                    ),
                  DropdownButtonFormField<String>(
                    key: ValueKey('car-$_carId'),
                    initialValue: _car?.id,
                    isExpanded: true,
                    decoration: deco('Автомобиль', field: 'car'),
                    items: [
                      for (final c in cars)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            '${c.plate} · ${lookup.carTitle(c.modelId)}'
                            '${staff ? ' · ${lookup.clientName(c.clientId)}' : ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    validator: (v) => v == null ? 'Выберите автомобиль' : null,
                    onChanged: (v) async {
                      _changed(() {
                        _carId = v;
                        _mechanicId ??= _defaultMechanic();
                      });
                      await _loadClient();
                      await _loadBusy();
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey('mechanic-$_mechanicId'),
                    initialValue:
                        lookup.mechanics.any((m) => m.id == _mechanicId)
                        ? _mechanicId
                        : null,
                    isExpanded: true,
                    decoration: deco('Мастер', field: 'mechanic'),
                    items: [
                      for (final m in lookup.mechanics)
                        DropdownMenuItem(
                          value: m.id,
                          child: Text(
                            '${m.shortName} · ${m.grade} разряд'
                            '${_car?.mechanicIds.contains(m.id) ?? false ? ' · закреплён' : ''}',
                          ),
                        ),
                    ],
                    validator: (v) => v == null ? 'Выберите мастера' : null,
                    onChanged: (v) async {
                      _changed(() => _mechanicId = v);
                      await _loadBusy();
                    },
                  ),
                  const SizedBox(height: 16),
                  FormField<Set<String>>(
                    validator: (_) => _serviceIds.isEmpty
                        ? 'Выберите хотя бы одну услугу'
                        : _fieldErrors['services'],
                    builder: (field) => InputDecorator(
                      decoration: deco(
                        'Услуги',
                      ).copyWith(errorText: field.errorText),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in lookup.services)
                            FilterChip(
                              label: Text(s.name),
                              tooltip:
                                  '${formatMoney(s.price)} · ${formatDuration(s.duration)}',
                              selected: _serviceIds.contains(s.id),
                              onSelected: (on) {
                                _changed(
                                  () => on
                                      ? _serviceIds.add(s.id)
                                      : _serviceIds.remove(s.id),
                                );
                                field.didChange(_serviceIds);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: 220,
                        child: FormField<DateTime>(
                          validator: (_) =>
                              _day == null ? 'Выберите день' : null,
                          builder: (field) => InkWell(
                            onTap: _pickDay,
                            child: InputDecorator(
                              decoration: deco('День').copyWith(
                                errorText: field.errorText,
                                suffixIcon: const Icon(
                                  Icons.calendar_today_outlined,
                                ),
                              ),
                              child: Text(
                                _day == null ? '' : formatDate(_day!),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<({int hour, int minute})>(
                          key: ValueKey('slot-$_slot-${_busy.length}-$minutes'),
                          initialValue: _slot,
                          isExpanded: true,
                          decoration: deco('Начало', field: 'starts_at'),
                          items: [
                            for (final s in startSlots)
                              DropdownMenuItem(
                                value: s,
                                child: Text(
                                  '${s.hour.toString().padLeft(2, '0')}:'
                                  '${s.minute.toString().padLeft(2, '0')}'
                                  '${_slotBusy(s) ? ' — занято' : ''}',
                                  style: _slotBusy(s)
                                      ? TextStyle(
                                          color: theme.colorScheme.error,
                                        )
                                      : null,
                                ),
                              ),
                          ],
                          validator: (v) {
                            if (v == null) return 'Выберите время';
                            final s = _start;
                            if (s != null &&
                                minutes > 0 &&
                                !Schedule.withinHours(
                                  s,
                                  Duration(minutes: minutes),
                                )) {
                              return 'Работы не успеют закончиться до 20:00';
                            }
                            return null;
                          },
                          onChanged: (v) => _changed(() => _slot = v),
                        ),
                      ),
                    ],
                  ),
                  if (_day != null) ...[
                    const SizedBox(height: 12),
                    _BusyLine(busy: _busy, day: _day!),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _comment,
                    maxLength: 300,
                    maxLines: 2,
                    decoration: deco('Комментарий', field: 'comment'),
                    onChanged: (_) => _dirty = true,
                  ),
                  const SizedBox(height: 8),
                  _Preview(
                    minutes: minutes,
                    start: start,
                    subtotal: _subtotal,
                    discount: discount,
                  ),
                  if (_conflict != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: theme.colorScheme.errorContainer,
                      child: ListTile(
                        leading: Icon(
                          Icons.event_busy,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                        title: Text(
                          _conflict!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 12,
                      children: [
                        TextButton(
                          onPressed: () => context.go(widget.backLocation),
                          child: const Text('Отмена'),
                        ),
                        FilledButton.icon(
                          onPressed: _saving || cars.isEmpty ? null : _submit,
                          icon: _saving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.event_available),
                          label: Text(_isEditing ? 'Сохранить' : 'Записать'),
                        ),
                      ],
                    ),
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

/// Когда мастер уже занят в выбранный день.
class _BusyLine extends StatelessWidget {
  const _BusyLine({required this.busy, required this.day});

  final List<BusySlot> busy;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (busy.isEmpty) {
      return Text(
        'Мастер свободен весь день ${formatDate(day)} (9:00–20:00).',
        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Мастер занят:', style: theme.textTheme.bodyMedium),
        for (final b in busy)
          Chip(
            avatar: const Icon(Icons.schedule, size: 16),
            label: Text('${formatTime(b.start)}–${formatTime(b.end)}'),
          ),
      ],
    );
  }
}

/// Предварительный расчёт: длительность, окончание, стоимость со скидкой.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.minutes,
    required this.start,
    required this.subtotal,
    required this.discount,
  });

  final int minutes;
  final DateTime? start;
  final int subtotal;
  final ({int percent, DiscountSource source})? discount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (minutes == 0) return const SizedBox.shrink();
    final d = discount;
    final total = Pricing.total(subtotal, d?.percent ?? 0);
    final end = start?.add(Duration(minutes: minutes));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 32,
          runSpacing: 12,
          children: [
            _Fact('Работы займут', formatDuration(minutes)),
            if (end != null) _Fact('Окончание', formatTime(end)),
            _Fact('Сумма услуг', formatMoney(subtotal)),
            _Fact(
              'Скидка',
              d == null ? '—' : '${d.percent} % (${d.source.title})',
            ),
            _Fact(
              'К оплате',
              formatMoney(total),
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, {this.style});

  final String label;
  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: style ?? theme.textTheme.bodyLarge),
      ],
    );
  }
}
