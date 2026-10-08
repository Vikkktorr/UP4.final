import 'package:flutter/widgets.dart';

/// Границы, на которых меняется раскладка. Описаны один раз, чтобы во всех
/// экранах переключение происходило на одной и той же ширине.
class Breakpoints {
  const Breakpoints._();

  /// Уже этой ширины вместо таблицы показывается список карточек.
  static const double compact = 600;

  /// С этой ширины боковая панель раскрывается и показывает подписи.
  static const double expanded = 1200;

  /// Дальше этой ширины содержимое не растягивается.
  static const double contentMaxWidth = 1400;
}

enum ScreenSize { compact, medium, expanded }

ScreenSize screenSizeOf(BuildContext context) {
  // sizeOf подписывает виджет только на размер окна, а не на все
  // параметры MediaQuery сразу.
  final width = MediaQuery.sizeOf(context).width;
  if (width < Breakpoints.compact) return ScreenSize.compact;
  if (width < Breakpoints.expanded) return ScreenSize.medium;
  return ScreenSize.expanded;
}
