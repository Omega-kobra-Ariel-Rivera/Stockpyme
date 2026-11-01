/// Constantes globales de StockPyme.
class AppConstants {
  AppConstants._();

  static const String appName = 'StockPyme';
  static const String appVersion = '1.5.0';
  static const String tagline = 'Inventario y ventas para tu negocio';

  static const String company = 'Rivera Systems';
  static const String companyLocation = 'San Felipe, Chile';

  static const String logoPath = 'assets/branding/logo.png';
  static const String logoForegroundPath = 'assets/branding/splash_logo.png';
  static const String companyLogoPath = 'assets/branding/rivera_systems.png';

  /// Dirección del servidor de pagos (sitio de Netlify con las funciones).
  /// Cámbiala por la de tu sitio, por ejemplo:
  /// https://stockpyme-pagos.netlify.app/api
  static const String paymentsApiUrl = 'https://stockpyme-pagos.netlify.app/api';

  /// Cada cuántas horas se vuelve a consultar el estado del pago.
  static const int paymentCheckHours = 24;

  /// Días de prueba gratis antes de exigir la suscripción.
  static const int trialDays = 14;

  /// Precio del plan mensual (compatibilidad con versiones anteriores).
  static const String fallbackPrice = r'$4.990';

  static const List<String> units = [
    'unidad',
    'kg',
    'g',
    'litro',
    'caja',
    'paquete',
  ];
}

/// Nivel del plan: Básico solo sirve en el celular; Negocio en todos los
/// equipos (celular, PC y web) sin límite.
enum PlanTier {
  basico('basico', 'Básico', 'Solo celular'),
  negocio('negocio', 'Negocio', 'Celular + PC · equipos ilimitados');

  const PlanTier(this.id, this.title, this.subtitle);

  final String id;

  /// Textos en español (se traducen con tr al mostrarlos).
  final String title;
  final String subtitle;

  static PlanTier fromId(String? id) => PlanTier.values.firstWhere(
        (t) => t.id == id,
        orElse: () => PlanTier.basico,
      );
}

/// Planes Premium. Los montos deben ser iguales a los del servidor de pagos
/// (funciones de Netlify): el cobro real lo define el servidor.
enum PremiumPlan {
  mensual(
    id: 'mensual',
    tier: PlanTier.basico,
    title: 'Mensual',
    price: 4990,
    months: 1,
    period: 'al mes',
    note: 'Cancela cuando quieras',
  ),
  semestral(
    id: 'semestral',
    tier: PlanTier.basico,
    title: 'Semestral',
    price: 26990,
    months: 6,
    period: 'cada 6 meses',
    note: 'Ahorra 10%',
  ),
  anual(
    id: 'anual',
    tier: PlanTier.basico,
    title: 'Anual',
    price: 49900,
    months: 12,
    period: 'al año',
    note: '2 meses gratis',
  ),
  negocioMensual(
    id: 'negocio_mensual',
    tier: PlanTier.negocio,
    title: 'Mensual',
    price: 7990,
    months: 1,
    period: 'al mes',
    note: 'Cancela cuando quieras',
  ),
  negocioSemestral(
    id: 'negocio_semestral',
    tier: PlanTier.negocio,
    title: 'Semestral',
    price: 43990,
    months: 6,
    period: 'cada 6 meses',
    note: 'Ahorra 8%',
  ),
  negocioAnual(
    id: 'negocio_anual',
    tier: PlanTier.negocio,
    title: 'Anual',
    price: 79900,
    months: 12,
    period: 'al año',
    note: '2 meses gratis',
  );

  const PremiumPlan({
    required this.id,
    required this.tier,
    required this.title,
    required this.price,
    required this.months,
    required this.period,
    required this.note,
  });

  final String id;
  final PlanTier tier;
  final String title;

  /// Pesos chilenos.
  final int price;
  final int months;
  final String period;
  final String note;

  bool get isNegocio => tier == PlanTier.negocio;

  /// Nombre completo, por ejemplo "Negocio · Anual" (en español).
  String get fullTitle => '${tier.title} · $title';

  int get monthlyEquivalent => (price / months).round();

  /// Plan con la misma duración en el otro nivel.
  PremiumPlan inTier(PlanTier target) => PremiumPlan.values.firstWhere(
        (p) => p.tier == target && p.months == months,
      );

  static List<PremiumPlan> ofTier(PlanTier tier) =>
      PremiumPlan.values.where((p) => p.tier == tier).toList();

  static PremiumPlan fromId(String? id) =>
      PremiumPlan.values.firstWhere((p) => p.id == id,
          orElse: () => PremiumPlan.mensual);
}

/// Colecciones de Firestore.
class CloudPaths {
  CloudPaths._();

  /// users/{uid}: perfil, negocio, plan y resumen de ventas.
  static const String users = 'users';

  /// users/{uid}/products/{productId}
  static const String products = 'products';

  /// users/{uid}/sales/{saleId}
  static const String sales = 'sales';

  /// admins/{email}: si existe el documento, ese correo es administrador.
  static const String admins = 'admins';
}

/// Claves usadas en el almacenamiento local.
class StorageKeys {
  StorageKeys._();

  static const String products = 'sp_products';
  static const String sales = 'sp_sales';
  static const String movements = 'sp_movements';
  static const String businessName = 'sp_business_name';
  static const String trialStart = 'sp_trial_start';
  static const String subscribed = 'sp_subscribed';
  static const String accountId = 'sp_account_id';
  static const String payerEmail = 'sp_payer_email';
  static const String preapprovalId = 'sp_mp_preapproval_id';
  static const String lastPaymentCheck = 'sp_mp_last_check';
  static const String premiumPlan = 'sp_premium_plan';

  /// Plan de la suscripción ya pagada (puede ser distinto al elegido en
  /// pantalla, por ejemplo mientras se paga el cambio a Negocio).
  static const String paidPlan = 'sp_paid_plan';

  /// Moneda del negocio (CLP, USD, EUR...).
  static const String currency = 'sp_currency';

  /// Idioma de la app (igual para todas las cuentas del teléfono).
  static const String language = 'sp_language';

  /// Marca de "datos ya restaurados desde la nube" en este teléfono.
  static const String cloudRestored = 'sp_cloud_restored';

  static const List<String> dataKeys = [products, sales, movements];

  /// Claves que pertenecen a cada cuenta (se guardan con el id del usuario).
  static const List<String> accountKeys = [
    products,
    sales,
    movements,
    businessName,
    trialStart,
    subscribed,
    payerEmail,
    preapprovalId,
    lastPaymentCheck,
    premiumPlan,
    paidPlan,
    currency,
    cloudRestored,
  ];
}
