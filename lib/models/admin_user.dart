import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/constants.dart';

/// Estado del plan de un usuario, visto por el administrador.
enum AdminPlan {
  proMercadoPago('Pro · Mercado Pago'),
  proManual('Pro · Manual'),
  trial('En prueba'),
  expired('Prueba vencida');

  const AdminPlan(this.label);
  final String label;

  bool get isPro => this == proMercadoPago || this == proManual;
}

/// Resumen de una cuenta (documento users/{uid}).
class AdminUser {
  AdminUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.businessName,
    required this.provider,
    required this.platform,
    required this.appVersion,
    required this.planCode,
    required this.mercadoPago,
    this.createdAt,
    this.lastSeen,
    this.trialStart,
    this.manualProUntil,
    this.products = 0,
    this.lowStock = 0,
    this.inventoryValue = 0,
    this.salesToday = 0,
    this.sales30d = 0,
    this.salesCount30d = 0,
    this.lastSaleAt,
  });

  final String uid;
  final String email;
  final String name;
  final String businessName;
  final String provider;
  final String platform;
  final String appVersion;
  final String planCode;
  final bool mercadoPago;
  final DateTime? createdAt;
  final DateTime? lastSeen;
  final DateTime? trialStart;
  final DateTime? manualProUntil;
  final int products;
  final int lowStock;
  final int inventoryValue;
  final int salesToday;
  final int sales30d;
  final int salesCount30d;
  final DateTime? lastSaleAt;

  bool get manualProActive =>
      manualProUntil != null && manualProUntil!.isAfter(DateTime.now());

  int get trialDaysLeft {
    final start = trialStart;
    if (start == null) return 0;
    final left = start
        .add(const Duration(days: AppConstants.trialDays))
        .difference(DateTime.now());
    if (left.isNegative) return 0;
    return (left.inHours / 24).ceil();
  }

  AdminPlan get plan {
    if (mercadoPago) return AdminPlan.proMercadoPago;
    if (manualProActive) return AdminPlan.proManual;
    if (trialDaysLeft > 0) return AdminPlan.trial;
    return AdminPlan.expired;
  }

  String get displayName {
    if (businessName.trim().isNotEmpty) return businessName.trim();
    if (name.trim().isNotEmpty) return name.trim();
    return email;
  }

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return email.toLowerCase().contains(q) ||
        name.toLowerCase().contains(q) ||
        businessName.toLowerCase().contains(q);
  }

  static DateTime? _date(Object? value) =>
      value is Timestamp ? value.toDate() : null;

  static int _int(Object? value) => value is num ? value.round() : 0;

  factory AdminUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final stats = (d['stats'] as Map?)?.cast<String, dynamic>() ?? {};
    return AdminUser(
      uid: doc.id,
      email: d['email'] as String? ?? '',
      name: d['name'] as String? ?? '',
      businessName: d['businessName'] as String? ?? '',
      provider: d['provider'] as String? ?? '',
      platform: d['platform'] as String? ?? '',
      appVersion: d['appVersion'] as String? ?? '',
      planCode: d['plan'] as String? ?? '',
      mercadoPago: d['mercadoPago'] as bool? ?? false,
      createdAt: _date(d['createdAt']),
      lastSeen: _date(d['lastSeen']),
      trialStart: _date(d['trialStart']),
      manualProUntil: _date(d['manualProUntil']),
      products: _int(stats['products']),
      lowStock: _int(stats['lowStock']),
      inventoryValue: _int(stats['inventoryValue']),
      salesToday: _int(stats['salesToday']),
      sales30d: _int(stats['sales30d']),
      salesCount30d: _int(stats['salesCount30d']),
      lastSaleAt: _date(stats['lastSaleAt']),
    );
  }
}
