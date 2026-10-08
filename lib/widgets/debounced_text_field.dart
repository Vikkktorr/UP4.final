import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/debouncer.dart';

/// Поле ввода, которое сообщает о новом значении только после паузы.
///
/// Без задержки каждый символ запускал бы новую выборку и новую запись
/// в истории браузера. [value] приходит из адреса: при нажатии «назад»
/// текст в поле обновляется сам.
class DebouncedTextField extends StatefulWidget {
  const DebouncedTextField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.icon,
    this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.maxLength,
    this.clearable = true,
    this.delay = const Duration(milliseconds: 400),
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String label;
  final IconData? icon;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  /// Неверное значение не уходит наружу, а подсвечивается под полем.
  final String? Function(String value)? validator;
  final int? maxLength;

  /// Кнопка очистки в конце поля. В узких полях года она лишь отнимает
  /// место у подписи.
  final bool clearable;
  final Duration delay;

  @override
  State<DebouncedTextField> createState() => _DebouncedTextFieldState();
}

class _DebouncedTextFieldState extends State<DebouncedTextField> {
  late final TextEditingController _controller;
  late final Debouncer _debouncer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _debouncer = Debouncer(delay: widget.delay);
  }

  @override
  void didUpdateWidget(DebouncedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Значение сменилось снаружи (кнопка «назад», сброс фильтров) —
    // переносим его в поле, если пользователь не печатает прямо сейчас.
    if (widget.value != _controller.text.trim() && !_debouncer.isPending) {
      _controller.text = widget.value;
      _error = null;
    }
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String text) {
    final error = widget.validator?.call(text.trim());
    // setState здесь уместен: ошибка поля — локальное состояние виджета.
    if (error != _error) setState(() => _error = error);
    if (error != null) {
      _debouncer.cancel();
      return;
    }
    _debouncer.run(() => widget.onChanged(text.trim()));
  }

  void _clear() {
    _debouncer.cancel();
    _controller.clear();
    setState(() => _error = null);
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _handleChanged,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      maxLength: widget.maxLength,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        errorText: _error,
        counterText: '',
        isDense: true,
        border: const OutlineInputBorder(),
        prefixIcon: widget.icon == null ? null : Icon(widget.icon),
        suffixIcon: !widget.clearable
            ? null
            : ListenableBuilder(
                listenable: _controller,
                builder: (context, _) => _controller.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        tooltip: 'Очистить',
                        icon: const Icon(Icons.close),
                        onPressed: _clear,
                      ),
              ),
      ),
    );
  }
}
