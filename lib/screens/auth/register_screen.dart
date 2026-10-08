import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_exceptions.dart';
import '../../core/validators.dart';
import '../../state/auth_notifier.dart';
import 'auth_layout.dart';

/// Регистрация: /register. Новый пользователь получает роль «клиент» —
/// её назначает сервер, выбрать роль в форме нельзя.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _lastName = TextEditingController();
  final _firstName = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  bool _hidden = true;
  bool _busy = false;
  String? _error;

  /// Ошибки 422 от сервера по полям: username, password…
  Map<String, String> _serverErrors = const {};

  @override
  void initState() {
    super.initState();
    // Список требований к паролю перерисовывается на каждый символ.
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_lastName, _firstName, _username, _password, _repeat]) {
      c.dispose();
    }
    super.dispose();
  }

  FormFieldValidator<String> _check(String field, Validator rule) =>
      (value) => _serverErrors[field] ?? rule(value ?? '');

  void _clearServerError(String field) {
    if (_serverErrors.containsKey(field)) {
      setState(() => _serverErrors = {..._serverErrors}..remove(field));
    }
  }

  Future<void> _submit() async {
    setState(() => _serverErrors = const {});
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthNotifier>().register(
        username: _username.text.trim(),
        password: _password.text,
        lastName: _lastName.text.trim(),
        firstName: _firstName.text.trim(),
      );
    } on ValidationException catch (e) {
      // Например, «Такой логин уже занят» — под полем логина.
      setState(() => _serverErrors = e.errors);
      _form.currentState!.validate();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    border: const OutlineInputBorder(),
  );

  @override
  Widget build(BuildContext context) {
    final from = GoRouterState.of(context).uri.queryParameters['from'];
    final password = _password.text;

    return AuthLayout(
      title: 'Регистрация',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              // Ошибка появляется по мере ввода в этом поле, а не только
              // по нажатию кнопки.
              autovalidateMode: AutovalidateMode.onUserInteraction,
              controller: _lastName,
              decoration: _decoration('Фамилия', Icons.badge_outlined),
              onChanged: (_) => _clearServerError('lastName'),
              validator: _check(
                'lastName',
                all([requiredText('Укажите фамилию'), personName()]),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              controller: _firstName,
              decoration: _decoration('Имя', Icons.badge_outlined),
              onChanged: (_) => _clearServerError('firstName'),
              validator: _check(
                'firstName',
                all([requiredText('Укажите имя'), personName()]),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              controller: _username,
              decoration: _decoration('Логин', Icons.person_outline),
              onChanged: (_) => _clearServerError('username'),
              validator: _check('username', username()),
            ),
            const SizedBox(height: 16),
            TextFormField(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              controller: _password,
              obscureText: _hidden,
              decoration: _decoration('Пароль', Icons.lock_outline).copyWith(
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
              onChanged: (_) => _clearServerError('password'),
              validator: _check('password', strongPassword()),
            ),
            const SizedBox(height: 8),
            for (final rule in passwordRules)
              _RuleLine(label: rule.label, ok: rule.test(password)),
            const SizedBox(height: 16),
            TextFormField(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              controller: _repeat,
              obscureText: _hidden,
              decoration: _decoration('Повторите пароль', Icons.lock_outline),
              onFieldSubmitted: (_) => _submit(),
              validator: (v) => (v ?? '').isEmpty
                  ? 'Повторите пароль'
                  : v != _password.text
                  ? 'Пароли не совпадают'
                  : null,
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
                    : const Text('Зарегистрироваться'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go(
                Uri(
                  path: '/login',
                  queryParameters: from == null ? null : {'from': from},
                ).toString(),
              ),
              child: const Text('Уже есть учётная запись? Войти'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Строка списка требований к паролю: выполнено или нет.
class _RuleLine extends StatelessWidget {
  const _RuleLine({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = ok ? Colors.green.shade700 : colors.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}
