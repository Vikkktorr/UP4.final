import 'package:flutter/material.dart';

/// Экран из библиотеки, подключённой через `import ... deferred as`.
///
/// Код такого раздела не входит в main.dart.js: браузер скачивает его
/// отдельным файлом при первом открытии раздела. Так первая загрузка
/// приложения меньше на код форм, пользователей и статистики, которые
/// нужны не каждому и не сразу.
class DeferredScreen extends StatefulWidget {
  const DeferredScreen({super.key, required this.load, required this.build});

  /// `библиотека.loadLibrary` — повторный вызов после загрузки мгновенный.
  final Future<void> Function() load;

  /// Создаёт экран, когда код библиотеки уже загружен.
  final Widget Function() build;

  @override
  State<DeferredScreen> createState() => _DeferredScreenState();
}

class _DeferredScreenState extends State<DeferredScreen> {
  late Future<void> _loading = widget.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // Связь пропала как раз при открытии раздела.
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Не удалось загрузить раздел. Проверьте соединение.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => setState(() => _loading = widget.load()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Повторить'),
                ),
              ],
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return widget.build();
      },
    );
  }
}
