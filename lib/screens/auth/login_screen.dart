import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_exceptions.dart';
import '../../core/validators.dart';
import '../../state/auth_notifier.dart';
import 'auth_layout.dart';

/// Экран входа: /login. Аналог formLogin().loginPage("/login").
///
/// После успешного входа никуда переходить не нужно: AuthNotifier
/// сообщит об изменении, маршрутизатор пересчитает redirect и вернёт
/// пользователя на адрес из параметра from.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _hidden = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthNotifier>().login(
        _username.text.trim(),
        _password.text,
      );
    } on UnauthorizedException catch (e) {
      // 401 на /auth/login — неверный логин или пароль. Интерсептор
      // обновления токена такие адреса не трогает, цикла нет.
      setState(() => _error = e.message);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final from = GoRouterState.of(context).uri.queryParameters['from'];

    return AuthLayout(
      title: 'Вход в систему',
      notice: auth.endReason,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _username,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Логин',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) => requiredText('Укажите логин')(v ?? ''),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              obscureText: _hidden,
              decoration: InputDecoration(
                labelText: 'Пароль',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _hidden ? 'Показать пароль' : 'Скрыть пароль',
                  icon: Icon(
                    _hidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _hidden = !_hidden),
                ),
              ),
              onFieldSubmitted: (_) => _submit(),
              validator: (v) => requiredText('Укажите пароль')(v ?? ''),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              FormError(_error!),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Войти'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go(
                Uri(
                  path: '/register',
                  queryParameters: from == null ? null : {'from': from},
                ).toString(),
              ),
              child: const Text('Нет учётной записи? Зарегистрироваться'),
            ),
          ],
        ),
      ),
    );
  }
}
