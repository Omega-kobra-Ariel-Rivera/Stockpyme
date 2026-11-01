import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'l10n/i18n.dart';
import 'screens/auth/login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/cart_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/inventory_service.dart';
import 'services/language_service.dart';
import 'services/storage_service.dart';
import 'services/subscription_service.dart';
import 'utils/constants.dart';
import 'utils/theme.dart';
import 'widgets/app_logo.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();

    // En vez de una pantalla gris, muestra el error para poder corregirlo.
    ErrorWidget.builder = (details) => _ErrorView(
          message: details.exceptionAsString(),
        );

    // Se dibuja de inmediato; lo demás se carga dentro de _Bootstrap.
    runApp(const _Bootstrap());
  }, (error, stack) {
    debugPrint('Error no controlado: $error\n$stack');
  });
}

/// App con el tema de StockPyme. Hay una por estado (cargando, sin sesión,
/// con sesión) para que los datos de cada cuenta queden por encima de la
/// navegación y todas las pantallas los vean.
///
/// Al cambiar el idioma cambia la clave y toda la app se vuelve a dibujar.
Widget _app(Widget home) => MaterialApp(
      key: ValueKey(I18n.current),
      title: AppConstants.appName,
      locale: I18n.current.locale,
      supportedLocales: [for (final l in AppLanguage.values) l.locale],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: home,
    );

/// Inicia Firebase y el almacenamiento del teléfono.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  StorageService? _storage;
  AuthService? _auth;
  LanguageService? _language;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(const Duration(seconds: 15));
      }
      final storage = await StorageService.create()
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() {
        _storage = storage;
        _language ??= LanguageService(storage)..addListener(_onLanguage);
        _auth ??= AuthService();
      });
    } on UnsupportedError catch (e) {
      if (mounted) setState(() => _error = e.message ?? e.toString());
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _onLanguage() => setState(() {});

  @override
  void dispose() {
    _language?.removeListener(_onLanguage);
    _language?.dispose();
    _auth?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storage = _storage;
    final auth = _auth;
    final language = _language;
    if (_error != null) {
      return _app(_ErrorView(message: _error!, onRetry: _load));
    }
    if (storage == null || auth == null || language == null) {
      return _app(const _LoadingView());
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: language),
      ],
      child: Consumer<AuthService>(
        builder: (context, session, _) {
          if (!session.ready) return _app(const _LoadingView());
          final user = session.user;
          if (user == null) return _app(const LoginScreen());
          return _AccountScope(
            key: ValueKey(user.uid),
            user: user,
            storage: storage,
            pendingBusinessName: session.pendingBusinessName,
          );
        },
      ),
    );
  }
}

/// Carga el negocio de la cuenta que inició sesión.
class _AccountScope extends StatefulWidget {
  const _AccountScope({
    super.key,
    required this.user,
    required this.storage,
    this.pendingBusinessName,
  });

  final User user;
  final StorageService storage;
  final String? pendingBusinessName;

  @override
  State<_AccountScope> createState() => _AccountScopeState();
}

class _AccountScopeState extends State<_AccountScope> {
  InventoryService? _inventory;
  SubscriptionService? _subscription;
  CloudSyncService? _sync;
  final CartService _cart = CartService();
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final storage = widget.storage.forAccount(widget.user.uid);
      await storage.migrateLegacyData();

      final inventory = InventoryService(storage);
      await inventory.init();
      final subscription = SubscriptionService(storage);
      await subscription
          .init(accountId: widget.user.uid)
          .timeout(const Duration(seconds: 10));
      final sync = CloudSyncService(
        user: widget.user,
        inventory: inventory,
        subscription: subscription,
        storage: storage,
        pendingBusinessName: widget.pendingBusinessName,
      );
      if (!mounted) return;
      setState(() {
        _inventory = inventory;
        _subscription = subscription;
        _sync = sync;
      });
      unawaited(sync.start());
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _sync?.dispose();
    _subscription?.dispose();
    _inventory?.dispose();
    _cart.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventory = _inventory;
    final subscription = _subscription;
    final sync = _sync;

    if (_error != null) {
      return _app(_ErrorView(message: _error!, onRetry: _load));
    }
    if (inventory == null || subscription == null || sync == null) {
      return _app(const _LoadingView());
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: inventory),
        ChangeNotifierProvider.value(value: subscription),
        ChangeNotifierProvider.value(value: sync),
        ChangeNotifierProvider.value(value: _cart),
      ],
      child: _app(const SplashScreen()),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.seed,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogo(size: 96),
            SizedBox(height: 28),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.seed,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 48),
              const SizedBox(height: 12),
              Text(
                tr('No se pudo iniciar StockPyme'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.onBrandMuted, fontSize: 13),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: onRetry,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    minimumSize: const Size(160, 48),
                  ),
                  child: Text(tr('Reintentar')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
