import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../l10n/i18n.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/id_generator.dart';
import '../utils/platform.dart';
import 'storage_service.dart';

/// Prueba gratis + suscripción mensual con Mercado Pago.
///
/// La app nunca guarda el Access Token de Mercado Pago: habla con un
/// servidor propio (funciones de Netlify) que lo tiene como variable secreta.
class SubscriptionService extends ChangeNotifier with WidgetsBindingObserver {
  SubscriptionService(this._storage);

  final StorageService _storage;

  static final RegExp _emailPattern =
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  DateTime _trialStart = DateTime.now();
  bool _subscribed = false;
  bool _loading = false;
  String? _error;
  String? _info;
  String _accountId = '';
  String _payerEmail = '';
  String? _preapprovalId;
  DateTime? _lastCheck;

  /// Plan elegido en la pantalla de planes.
  PremiumPlan _plan = PremiumPlan.mensual;

  /// Plan de la suscripción pagada y autorizada en Mercado Pago.
  PremiumPlan? _paidPlan;

  /// Pro activado a mano por el administrador (pago en efectivo, regalo...).
  DateTime? _manualProUntil;
  PlanTier _manualProTier = PlanTier.basico;

  bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  /// Este equipo es un PC: solo funciona con el Plan Negocio.
  bool get onDesktop => AppPlatform.isDesktop;

  /// Nivel del plan activo (el mayor entre Mercado Pago y el manual), o null.
  PlanTier? get activeTier {
    PlanTier? tier;
    if (_subscribed) tier = (_paidPlan ?? _plan).tier;
    if (manualProActive &&
        (tier == null || _manualProTier == PlanTier.negocio)) {
      tier = _manualProTier;
    }
    return tier;
  }

  bool get negocioActive => activeTier == PlanTier.negocio;

  /// En el PC hace falta el Plan Negocio (aunque tenga el Básico).
  bool get needsNegocio => onDesktop && !negocioActive;

  /// Puede pasar del Básico al Negocio.
  bool get canUpgrade => activeTier == PlanTier.basico;

  /// Tiene algún plan pagado: por Mercado Pago o activado por el administrador.
  bool get isSubscribed => activeTier != null;

  /// Suscripción pagada con Mercado Pago.
  bool get mercadoPagoActive => _subscribed;

  bool get manualProActive =>
      _manualProUntil != null && _manualProUntil!.isAfter(DateTime.now());
  DateTime? get manualProUntil => _manualProUntil;
  DateTime get trialStart => _trialStart;
  String get accountId => _accountId;
  bool get loading => _loading;
  String? get error => _error;

  /// Mensaje informativo (por ejemplo, "pago pendiente").
  String? get info => _info;
  String get payerEmail => _payerEmail;

  /// Id de la suscripción en Mercado Pago (se guarda en la cuenta para que
  /// el Pro pagado en un equipo sirva también en los demás).
  String? get preapprovalId => _preapprovalId;

  /// Hay un pago iniciado en Mercado Pago que aún no se confirma.
  bool get hasPendingPayment => _preapprovalId != null && !_subscribed;

  int get trialDaysLeft {
    final end = _trialStart.add(const Duration(days: AppConstants.trialDays));
    final left = end.difference(DateTime.now());
    if (left.isNegative) return 0;
    return (left.inHours / 24).ceil();
  }

  /// La prueba gratis solo vale en el celular.
  bool get inTrial => !isSubscribed && !onDesktop && trialDaysLeft > 0;

  bool get hasAccess {
    if (onDesktop) return negocioActive;
    return isSubscribed || trialDaysLeft > 0;
  }

  /// Estado para mostrar al administrador.
  String get planCode {
    if (_subscribed) return 'pro_mp';
    if (manualProActive) return 'pro_manual';
    if (trialDaysLeft > 0) return 'trial';
    return 'expired';
  }

  PremiumPlan get plan => _plan;

  /// Plan contratado (o el elegido si aún no paga).
  PremiumPlan get currentPlan => (_subscribed ? _paidPlan : null) ?? _plan;

  /// Precio del plan contratado, por ejemplo "$49.900 al año".
  String get priceLabel =>
      '${formatCLP(currentPlan.price)} ${tr(currentPlan.period)}';

  void selectPlan(PremiumPlan plan) {
    if (plan == _plan) return;
    // Con un plan activo solo se puede elegir uno de Negocio (para subir).
    if (_subscribed && !(plan.isNegocio && canUpgrade)) return;
    _plan = plan;
    notifyListeners();
  }

  /// [accountId] es el id de la cuenta (Firebase); Mercado Pago lo usa como
  /// referencia para saber de quién es cada pago.
  Future<void> init({String? accountId}) async {
    final saved = _storage.getString(StorageKeys.trialStart);
    final parsed = saved == null ? null : DateTime.tryParse(saved);
    if (parsed == null) {
      _trialStart = DateTime.now();
      await _storage.setString(
          StorageKeys.trialStart, _trialStart.toIso8601String());
    } else {
      _trialStart = parsed;
    }

    _subscribed = _storage.getBool(StorageKeys.subscribed) ?? false;
    _payerEmail = _storage.getString(StorageKeys.payerEmail) ?? '';
    _plan = PremiumPlan.fromId(_storage.getString(StorageKeys.premiumPlan));
    final paid = _storage.getString(StorageKeys.paidPlan);
    _paidPlan = (paid == null || paid.isEmpty)
        ? (_subscribed ? _plan : null)
        : PremiumPlan.fromId(paid);
    // En el PC se ofrece directamente el Plan Negocio.
    if (onDesktop && !_plan.isNegocio) _plan = _plan.inTier(PlanTier.negocio);
    final savedId = _storage.getString(StorageKeys.preapprovalId);
    _preapprovalId = (savedId == null || savedId.isEmpty) ? null : savedId;
    final last = _storage.getString(StorageKeys.lastPaymentCheck);
    _lastCheck = last == null ? null : DateTime.tryParse(last);

    // La cuenta de Firebase es la referencia del pago en Mercado Pago.
    // Sin sesión se usa (o se crea) un id guardado en el teléfono.
    final String account;
    if (accountId != null && accountId.isNotEmpty) {
      account = accountId;
    } else {
      final saved = _storage.getString(StorageKeys.accountId) ?? '';
      account = saved.isNotEmpty ? saved : 'sp_${newId()}';
    }
    await _storage.setString(StorageKeys.accountId, account);
    _accountId = account;

    WidgetsBinding.instance.addObserver(this);

    // Revisa el estado en segundo plano para no retrasar el inicio.
    if (_preapprovalId != null && _isCheckDue) {
      unawaited(checkPayment(silent: true));
    }
  }

  bool get _isCheckDue {
    final last = _lastCheck;
    if (last == null) return true;
    return DateTime.now().difference(last).inHours >=
        AppConstants.paymentCheckHours;
  }

  /// Al volver a la app desde Mercado Pago, revisa si el pago se aprobó.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && hasPendingPayment && !_loading) {
      unawaited(checkPayment(silent: true));
    }
  }

  /// Aplica lo guardado en la cuenta en la nube: la fecha de inicio de la
  /// prueba (la más antigua gana, así reinstalar no regala días) y el Pro
  /// activado por el administrador.
  Future<void> applyCloudPlan({
    DateTime? trialStart,
    DateTime? manualProUntil,
    String? manualProTier,
    String? preapprovalId,
  }) async {
    _manualProTier = PlanTier.fromId(manualProTier);
    if (trialStart != null && trialStart.isBefore(_trialStart)) {
      _trialStart = trialStart;
      await _storage.setString(
          StorageKeys.trialStart, _trialStart.toIso8601String());
    }
    _manualProUntil = manualProUntil;
    notifyListeners();

    // Suscripción pagada en otro equipo (por ejemplo, en el celular y ahora
    // en el PC): se usa la misma y se revisa su estado en Mercado Pago.
    final cloudId = preapprovalId?.trim() ?? '';
    if (cloudId.isNotEmpty && cloudId != _preapprovalId) {
      _preapprovalId = cloudId;
      await _storage.setString(StorageKeys.preapprovalId, cloudId);
      if (!_loading) unawaited(checkPayment(silent: true));
    }
  }

  Future<void> setPayerEmail(String email) async {
    _payerEmail = email.trim().toLowerCase();
    await _storage.setString(StorageKeys.payerEmail, _payerEmail);
  }

  /// Crea la suscripción y abre Mercado Pago para pagar.
  Future<void> subscribe([String? email, PremiumPlan? plan]) async {
    if (plan != null) _plan = plan;
    final upgrading = canUpgrade && _plan.isNegocio;
    _error = null;
    _info = null;
    if (email != null) await setPayerEmail(email);
    if (!_emailPattern.hasMatch(_payerEmail)) {
      _error = tr(
          'Escribe un correo válido. Mercado Pago lo usa para tu suscripción.');
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();
    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.paymentsApiUrl}/crear-suscripcion'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': _payerEmail,
              'accountId': _accountId,
              'plan': _plan.id,
            }),
          )
          .timeout(const Duration(seconds: 20));
      final data = _decode(response.body);

      if (response.statusCode != 200 || data['init_point'] == null) {
        _error = (data['error'] as String?) ??
            tr('No se pudo iniciar el pago. Inténtalo otra vez.');
        return;
      }

      _preapprovalId = data['id'] as String?;
      if (_preapprovalId != null) {
        await _storage.setString(StorageKeys.preapprovalId, _preapprovalId!);
        await _storage.setString(StorageKeys.premiumPlan, _plan.id);
      }

      final opened = await launchUrl(
        Uri.parse(data['init_point'] as String),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        _error = tr(
          'No se pudo abrir Mercado Pago en este teléfono.');
      } else {
        _info = tr(
          'Completa el pago en Mercado Pago y vuelve a StockPyme. Lo revisaremos al volver.');
        if (upgrading) {
          _info = '$_info\n${tr('Cuando se active el Plan Negocio, cancela tu plan Básico en Mercado Pago para no pagar los dos.')}';
        }
      }
    } on TimeoutException {
      _error = tr(
          'Mercado Pago está tardando. Revisa tu conexión e inténtalo otra vez.');
    } catch (_) {
      _error = tr(
          'Sin conexión. Conéctate a internet para pagar.');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Consulta el estado de la suscripción en Mercado Pago.
  /// Con [silent] no muestra errores (revisiones automáticas).
  Future<void> checkPayment({bool silent = false}) async {
    final id = _preapprovalId;
    if (id == null) {
      if (!silent) {
        _error = tr(
          'Aún no has iniciado un pago desde este teléfono.');
        notifyListeners();
      }
      return;
    }

    if (!silent) {
      _error = null;
      _info = null;
      _loading = true;
      notifyListeners();
    }
    try {
      final response = await http
          .get(Uri.parse(
              '${AppConstants.paymentsApiUrl}/estado-suscripcion?id=${Uri.encodeQueryComponent(id)}'))
          .timeout(const Duration(seconds: 20));
      final data = _decode(response.body);
      if (response.statusCode != 200) {
        if (!silent) {
          _error = (data['error'] as String?) ??
            tr('No se pudo revisar el pago. Inténtalo más tarde.');
        }
        return;
      }

      final status = data['status'] as String? ?? '';
      final serverPlan = data['plan'] as String?;
      final checkedPlan =
          serverPlan == null ? _plan : PremiumPlan.fromId(serverPlan);
      _lastCheck = DateTime.now();
      await _storage.setString(
          StorageKeys.lastPaymentCheck, _lastCheck!.toIso8601String());

      switch (status) {
        case 'authorized':
          _paidPlan = checkedPlan;
          _plan = checkedPlan;
          await _storage.setString(StorageKeys.paidPlan, checkedPlan.id);
          await _storage.setString(StorageKeys.premiumPlan, checkedPlan.id);
          await _setSubscribed(true);
          _info = null;
        case 'pending':
          if (!silent) {
            _info = tr(
          'El pago aún está pendiente en Mercado Pago.');
          }
        case 'paused':
        case 'cancelled':
          await _setSubscribed(false);
          _paidPlan = null;
          await _storage.setString(StorageKeys.paidPlan, '');
          if (!silent) {
            _error = status == 'paused'
                ? tr('Tu suscripción está pausada en Mercado Pago.')
                : tr('Tu suscripción fue cancelada. Puedes suscribirte otra vez.');
          }
          if (status == 'cancelled') {
            _preapprovalId = null;
            await _storage.setString(StorageKeys.preapprovalId, '');
          }
      }
    } on TimeoutException {
      if (!silent) _error = tr(
          'Mercado Pago está tardando. Inténtalo otra vez.');
    } catch (_) {
      // Sin conexión: se mantiene el último estado guardado.
      if (!silent) _error = tr(
          'Sin conexión. Conéctate a internet para revisar el pago.');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Compatibilidad con la versión anterior ("restaurar compra").
  Future<void> restore() => checkPayment();

  Map<String, dynamic> _decode(String body) {
    try {
      final value = jsonDecode(body);
      return value is Map<String, dynamic> ? value : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _setSubscribed(bool value) async {
    _subscribed = value;
    await _storage.setBool(StorageKeys.subscribed, value);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
