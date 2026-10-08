import 'package:flutter/material.dart';

/// Общая разметка экранов входа и регистрации: карточка по центру.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.child,
    this.notice,
  });

  final String title;
  final Widget child;

  /// Сообщение над формой: например, почему завершилась сессия.
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Title(
      title: '$title — Автосервис',
      color: theme.colorScheme.primary,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surfaceContainerLow,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.car_repair,
                        size: 32,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text('Автосервис', style: theme.textTheme.headlineSmall),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (notice != null) ...[
                    Material(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: theme.colorScheme.onTertiaryContainer,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                notice!,
                                style: TextStyle(
                                  color: theme.colorScheme.onTertiaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(title, style: theme.textTheme.titleLarge),
                          const SizedBox(height: 20),
                          child,
                        ],
                      ),
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

/// Текст ошибки формы целиком: неверный пароль, сервер недоступен.
class FormError extends StatelessWidget {
  const FormError(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(color: colors.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}
