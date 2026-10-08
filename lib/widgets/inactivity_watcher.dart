import 'dart:async'; // Timer

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // HardwareKeyboard, KeyEvent

/// Выход по неактивности. Таймер сбрасывается при любом действии
/// пользователя: нажатии, движении мыши, прокрутке, клавише.
///
/// За [warning] до выхода поверх приложения появляется предупреждение
/// с обратным отсчётом; любое действие убирает его и запускает отсчёт заново.
class InactivityWatcher extends StatefulWidget {
  const InactivityWatcher({
    super.key,
    required this.timeout,
    required this.warning,
    required this.onTimeout,
    required this.child,
    this.onActivity,
  });

  final Duration timeout;
  final Duration warning;
  final VoidCallback onTimeout;

  /// Вызывается при каждом действии — чтобы сохранить его время
  /// в localStorage и проверить неактивность после перезагрузки.
  final VoidCallback? onActivity;
  final Widget child;

  @override
  State<InactivityWatcher> createState() => _InactivityWatcherState();
}

class _InactivityWatcherState extends State<InactivityWatcher> {
  Timer? _warningTimer;
  Timer? _timeoutTimer;
  Timer? _ticker;
  DateTime? _deadline;

  bool get _warning => _deadline != null;

  @override
  void initState() {
    super.initState();
    // Клавиатуру слушаем глобально. Виджет KeyboardListener здесь не подошёл бы:
    // он сообщает о нажатиях, только когда его FocusNode в фокусе, а у обёртки
    // над всем приложением фокуса нет — набор текста в форме не сбрасывал бы
    // таймер, и пользователя выбросило бы прямо посреди заполнения.
    HardwareKeyboard.instance.addHandler(_onKey);
    _restart();
  }

  // false означает «событие не обработано, передайте его дальше».
  bool _onKey(KeyEvent event) {
    _restart();
    return false;
  }

  void _restart() {
    widget.onActivity?.call();
    _warningTimer?.cancel();
    _timeoutTimer?.cancel();
    _ticker?.cancel();
    if (_warning) setState(() => _deadline = null);

    _warningTimer = Timer(widget.timeout - widget.warning, _showWarning);
    _timeoutTimer = Timer(widget.timeout, widget.onTimeout);
  }

  void _showWarning() {
    setState(() => _deadline = DateTime.now().add(widget.warning));
    // Раз в секунду перерисовываем обратный отсчёт.
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _warningTimer?.cancel();
    _timeoutTimer?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // Перехват без поглощения: событие идёт дальше к виджетам.
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _restart(),
      onPointerMove: (_) => _restart(),
      onPointerHover: (_) => _restart(),
      onPointerSignal: (_) => _restart(),
      child: Stack(
        children: [
          widget.child,
          if (_warning)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: _WarningBanner(
                secondsLeft: _deadline!
                    .difference(DateTime.now())
                    .inSeconds
                    .clamp(0, widget.warning.inSeconds),
                onStay: _restart,
              ),
            ),
        ],
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.secondsLeft, required this.onStay});

  final int secondsLeft;
  final VoidCallback onStay;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.errorContainer,
      elevation: 4,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.timer_outlined, color: colors.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Нет действий почти три минуты. Сессия будет завершена '
                  'через $secondsLeft с.',
                  style: TextStyle(
                    color: colors.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              FilledButton(
                onPressed: onStay,
                child: const Text('Продолжить работу'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
