import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/google_logo.dart';

/// Inicio de sesión y registro: email y contraseña, o cuenta de Google.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _business = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _register = false;
  bool _hidePassword = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _business, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _setMode(bool register) {
    setState(() {
      _register = register;
      _error = null;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthService>();
    await _run(() => _register
        ? auth.register(
            name: _name.text,
            businessName: _business.text,
            email: _email.text,
            password: _password.text,
          )
        : auth.signInWithEmail(_email.text, _password.text));
  }

  Future<void> _google() =>
      _run(() => context.read<AuthService>().signInWithGoogle());

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _email.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Recuperar contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Te enviaremos un enlace para crear una contraseña nueva.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || !mounted) return;
    if (!_emailPattern.hasMatch(email.trim())) {
      setState(() => _error = 'Escribe un correo válido.');
      return;
    }
    await _run(() async {
      await context.read<AuthService>().sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Te enviamos un correo a ${email.trim()}.')),
      );
    });
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Escribe tu correo';
    if (!_emailPattern.hasMatch(v.trim())) return 'Correo no válido';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Escribe tu contraseña';
    if (_register && v.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.seed,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                children: [
                  const _BrandHeader(),
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight * 0.68,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SegmentedButton<bool>(
                                  segments: const [
                                    ButtonSegment(
                                        value: false, label: Text('Ingresar')),
                                    ButtonSegment(
                                        value: true,
                                        label: Text('Crear cuenta')),
                                  ],
                                  selected: {_register},
                                  showSelectedIcon: false,
                                  onSelectionChanged: _busy
                                      ? null
                                      : (s) => _setMode(s.first),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  _register
                                      ? 'Crea tu cuenta gratis'
                                      : 'Bienvenido de vuelta',
                                  style: text.headlineSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _register
                                      ? '${AppConstants.trialDays} días de prueba, sin tarjeta.'
                                      : 'Ingresa para ver tu inventario y ventas.',
                                  style: text.bodyMedium?.copyWith(
                                      color: scheme.onSurfaceVariant),
                                ),
                                const SizedBox(height: 20),
                                if (_register) ...[
                                  TextFormField(
                                    controller: _name,
                                    enabled: !_busy,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Tu nombre',
                                      prefixIcon: Icon(Icons.person_outline),
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Escribe tu nombre'
                                            : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _business,
                                    enabled: !_busy,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Nombre del negocio',
                                      hintText: 'Almacén Don Pedro',
                                      prefixIcon:
                                          Icon(Icons.storefront_outlined),
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Escribe el nombre del negocio'
                                            : null,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                TextFormField(
                                  controller: _email,
                                  enabled: !_busy,
                                  keyboardType: TextInputType.emailAddress,
                                  autocorrect: false,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.email],
                                  decoration: const InputDecoration(
                                    labelText: 'Correo',
                                    hintText: 'nombre@correo.cl',
                                    prefixIcon: Icon(Icons.mail_outline),
                                  ),
                                  validator: _validateEmail,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _password,
                                  enabled: !_busy,
                                  obscureText: _hidePassword,
                                  textInputAction: _register
                                      ? TextInputAction.next
                                      : TextInputAction.done,
                                  autofillHints: [
                                    _register
                                        ? AutofillHints.newPassword
                                        : AutofillHints.password,
                                  ],
                                  onFieldSubmitted:
                                      _register ? null : (_) => _submit(),
                                  decoration: InputDecoration(
                                    labelText: 'Contraseña',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      tooltip: _hidePassword
                                          ? 'Mostrar contraseña'
                                          : 'Ocultar contraseña',
                                      icon: Icon(_hidePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined),
                                      onPressed: () => setState(
                                          () => _hidePassword = !_hidePassword),
                                    ),
                                  ),
                                  validator: _validatePassword,
                                ),
                                if (_register) ...[
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _confirm,
                                    enabled: !_busy,
                                    obscureText: _hidePassword,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _submit(),
                                    decoration: const InputDecoration(
                                      labelText: 'Repite la contraseña',
                                      prefixIcon: Icon(Icons.lock_outline),
                                    ),
                                    validator: (v) => v != _password.text
                                        ? 'Las contraseñas no coinciden'
                                        : null,
                                  ),
                                ],
                                if (!_register)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _busy ? null : _forgotPassword,
                                      child: const Text(
                                          '¿Olvidaste tu contraseña?'),
                                    ),
                                  )
                                else
                                  const SizedBox(height: 16),
                                if (_error != null) ...[
                                  _ErrorBox(message: _error!),
                                  const SizedBox(height: 12),
                                ],
                                FilledButton(
                                  onPressed: _busy ? null : _submit,
                                  child: _busy
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2.5),
                                        )
                                      : Text(_register
                                          ? 'Crear cuenta'
                                          : 'Ingresar'),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    const Expanded(child: Divider()),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      child: Text(
                                        'o continúa con',
                                        style: text.bodySmall?.copyWith(
                                            color: scheme.onSurfaceVariant),
                                      ),
                                    ),
                                    const Expanded(child: Divider()),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                OutlinedButton(
                                  onPressed: _busy ? null : _google,
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                    side: BorderSide(
                                        color: scheme.outlineVariant),
                                    foregroundColor: scheme.onSurface,
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      GoogleLogo(size: 20),
                                      SizedBox(width: 12),
                                      Text(
                                        'Continuar con Google',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  _register
                                      ? 'Al crear la cuenta aceptas que tus datos se respalden de forma segura en la nube para que puedas recuperarlos.'
                                      : '¿No tienes cuenta? Toca "Crear cuenta" arriba.',
                                  textAlign: TextAlign.center,
                                  style: text.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant),
                                ),
                                const SizedBox(height: 24),
                                const Center(child: MadeByRivera()),
                                SizedBox(
                                    height:
                                        MediaQuery.of(context).padding.bottom),
                              ],
                            ),
                          ),
                        ),
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

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 32, 24, 28),
      child: Column(
        children: [
          AppLogo(size: 76),
          SizedBox(height: 14),
          Text(
            AppConstants.appName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: 4),
          Text(
            AppConstants.tagline,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.onBrandMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
