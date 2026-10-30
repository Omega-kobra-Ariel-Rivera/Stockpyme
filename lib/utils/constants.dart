/// Constantes globales de StockPyme.
class AppConstants {
  AppConstants._();

  static const String appName = 'StockPyme';
  static const String appVersion = '1.3.0';
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

/// Planes Premium. Los montos deben ser iguales a los del servidor de pagos
/// (funciones de Netlify): el cobro real lo define el servidor.
enum PremiumPlan {
  mensual(
    id: 'mensual',
    title: 'Mensual',
    price: 4990,
    months: 1,
    period: 'al mes',
    note: 'Cancela cuando quieras',
  ),
  anual(
    id: 'anual',
    title: 'Anual',
    price: 49900,
    months: 12,
    period: 'al año',
    note: '2 meses gratis',
  );

  const PremiumPlan({
    required this.id,
    required this.title,
    required this.price,
    required this.months,
    required this.period,
    required this.note,
  });

  final String id;
  final String title;

  /// Pesos chilenos.
  final int price;
  final int months;
  final String period;
  final String note;

  int get monthlyEquivalent => (price / months).round();

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
    cloudRestored,
  ];
}
