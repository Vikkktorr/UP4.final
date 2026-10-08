import 'dart:async';

import 'package:flutter/foundation.dart';

/// Откладывает действие до паузы во вводе.
///
/// Каждый новый вызов [run] отменяет предыдущий таймер, поэтому действие
/// выполняется один раз — через [delay] после последнего нажатия клавиши.
class Debouncer {
  Debouncer({this.delay = const Duration(milliseconds: 400)});

  final Duration delay;
  Timer? _timer;

  bool get isPending => _timer?.isActive ?? false;

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() => _timer?.cancel();

  void dispose() => cancel();
}
