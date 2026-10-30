import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../models/sale.dart';
import '../utils/constants.dart';
import 'inventory_service.dart';
import 'storage_service.dart';
import 'subscription_service.dart';

/// Respaldo en la nube (Firestore) del negocio de cada cuenta.
///
/// La app sigue funcionando sin internet: todo se guarda primero en el
/// teléfono y se sube a la nube unos segundos después de cada cambio.
/// Así el usuario recupera sus datos al cambiar de teléfono y el
/// administrador puede ver los negocios desde su panel.
class CloudSyncService extends ChangeNotifier {
  CloudSyncService({
    required this.user,
    required this.inventory,
    required this.subscription,
    required this.storage,
    this.pendingBusinessName,
  });

  final User user;
  final InventoryService inventory;
  final SubscriptionService subscription;
  final StorageService storage;
  final String? pendingBusinessName;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const int _batchLimit = 400;
  static const Duration _delay = Duration(seconds: 3);
  static const Duration _writeTimeout = Duration(seconds: 20);

  /// Lecturas directas del servidor: sin internet fallan en vez de
  /// devolver datos vacíos del caché.
  static const GetOptions _server = GetOptions(source: Source.server);

  Timer? _debounce;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;
  bool _syncing = false;
  bool _again = false;
  bool _started = false;
  bool _profileReady = false;
  bool _restoreDone = false;
  String _lastPlan = '';

  DateTime? _lastSync;
  String? _error;

  DateTime? get lastSync => _lastSync;
  String? get error => _error;
  bool get syncing => _syncing;

  /// Nombre actualizado (al registrarse se guarda un instante después).
  String get _name =>
      FirebaseAuth.instance.currentUser?.displayName ?? user.displayName ?? '';

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _db.collection(CloudPaths.users).doc(user.uid);

  CollectionReference<Map<String, dynamic>> get _productsCol =>
      _userDoc.collection(CloudPaths.products);

  CollectionReference<Map<String, dynamic>> get _salesCol =>
      _userDoc.collection(CloudPaths.sales);

  // ---------------------------------------------------------------------------
  // Inicio
  // ---------------------------------------------------------------------------

  Future<void> start() async {
    if (_started) return;
    _started = true;

    try {
      await _ensureReady();
    } catch (_) {
      // Sin conexión: la app sigue con los datos del teléfono y
      // se reintenta en el próximo cambio.
      _error = 'Sin conexión. Tus datos se respaldarán cuando vuelva internet.';
    }

    _profileSub = _userDoc.snapshots().listen(_onProfile, onError: (_) {});
    inventory.addListener(_schedule);
    subscription.addListener(_onSubscriptionChanged);
    _lastPlan = subscription.planCode;
    _schedule();
  }

  /// Crea el perfil y hace la primera sincronización si aún no se hizo
  /// (por ejemplo, si al abrir la app no había internet).
  Future<void> _ensureReady() async {
    if (!_profileReady) {
      await _prepareProfile().timeout(const Duration(seconds: 12));
      _profileReady = true;
    }
    if (!_restoreDone) {
      await _restoreOrUpload().timeout(const Duration(seconds: 25));
      _restoreDone = true;
    }
  }

  Future<void> _prepareProfile() async {
    final snap = await _userDoc.get(_server);
    if (!snap.exists) {
      final business = (pendingBusinessName?.isNotEmpty ?? false)
          ? pendingBusinessName!
          : inventory.businessName;
      if (pendingBusinessName?.isNotEmpty ?? false) {
        await inventory.setBusinessName(pendingBusinessName!);
      }
      await _userDoc.set({
        'uid': user.uid,
        'email': (user.email ?? '').toLowerCase(),
        'name': _name,
        'businessName': business,
        'provider': user.providerData.isEmpty
            ? 'password'
            : user.providerData.first.providerId,
        'createdAt': FieldValue.serverTimestamp(),
        'trialStart': Timestamp.fromDate(subscription.trialStart),
        'lastSeen': FieldValue.serverTimestamp(),
      });
      return;
    }
    await _applyProfile(snap.data() ?? {});
  }

  Future<void> _applyProfile(Map<String, dynamic> data) async {
    final cloudName = data['businessName'] as String?;
    if (cloudName != null &&
        cloudName.isNotEmpty &&
        inventory.businessName == 'Mi negocio') {
      await inventory.applyCloudBusinessName(cloudName);
    }
    await subscription.applyCloudPlan(
      trialStart: (data['trialStart'] as Timestamp?)?.toDate(),
      manualProUntil: (data['manualProUntil'] as Timestamp?)?.toDate(),
    );
  }

  void _onProfile(DocumentSnapshot<Map<String, dynamic>> snap) {
    if (!snap.exists) return;
    unawaited(_applyProfile(snap.data() ?? {}));
  }

  /// Primera vez en este teléfono: si no hay datos locales, los trae de la
  /// nube; si hay datos (de antes de iniciar sesión), los sube.
  Future<void> _restoreOrUpload() async {
    if (storage.getBool(StorageKeys.cloudRestored) ?? false) return;

    final localEmpty = inventory.products.isEmpty && inventory.sales.isEmpty;
    if (localEmpty) {
      final productsSnap = await _productsCol.get(_server);
      final salesSnap =
          await _salesCol
          .orderBy('dateTs', descending: true)
          .limit(500)
          .get(_server);
      final products = [
        for (final doc in productsSnap.docs) Product.fromJson(doc.data()),
      ];
      final sales = [
        for (final doc in salesSnap.docs) Sale.fromJson(doc.data()),
      ];
      if (products.isNotEmpty || sales.isNotEmpty) {
        await inventory.restoreFromCloud(products: products, sales: sales);
      }
    } else {
      inventory.markAllForUpload();
    }
    await storage.setBool(StorageKeys.cloudRestored, true);
  }

  // ---------------------------------------------------------------------------
  // Subida de cambios
  // ---------------------------------------------------------------------------

  void _onSubscriptionChanged() {
    if (subscription.planCode != _lastPlan) {
      _lastPlan = subscription.planCode;
      _schedule();
    }
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(_delay, () => unawaited(syncNow()));
  }

  /// Sube los cambios pendientes y el resumen del negocio.
  Future<void> syncNow() async {
    if (_syncing) {
      _again = true;
      return;
    }
    _syncing = true;
    notifyListeners();

    CloudChanges? changes;
    try {
      await _ensureReady();
      changes = inventory.takeCloudChanges();
      if (changes.wipe) {
        await _deleteAll(_productsCol);
        await _deleteAll(_salesCol);
      }
      await _writeChanges(changes);
      await _userDoc
          .set(_profileSummary(), SetOptions(merge: true))
          .timeout(_writeTimeout);
      _lastSync = DateTime.now();
      _error = null;
    } catch (_) {
      if (changes != null) inventory.requeueCloudChanges(changes);
      _error = 'Sin conexión. Tus datos se respaldarán cuando vuelva internet.';
    } finally {
      _syncing = false;
      notifyListeners();
      if (_again) {
        _again = false;
        _schedule();
      }
    }
  }

  Future<void> _writeChanges(CloudChanges changes) async {
    final ops = <void Function(WriteBatch)>[
      for (final p in changes.products)
        (b) => b.set(_productsCol.doc(p.id), p.toJson()),
      for (final id in changes.deletedProductIds)
        (b) => b.delete(_productsCol.doc(id)),
      for (final sale in changes.sales)
        (b) => b.set(_salesCol.doc(sale.id), {
              ...sale.toJson(),
              'total': sale.total,
              'profit': sale.profit,
              'dateTs': Timestamp.fromDate(sale.date),
            }),
    ];
    for (var i = 0; i < ops.length; i += _batchLimit) {
      final batch = _db.batch();
      for (final op in ops.skip(i).take(_batchLimit)) {
        op(batch);
      }
      await batch.commit().timeout(_writeTimeout);
    }
  }

  Future<void> _deleteAll(CollectionReference<Map<String, dynamic>> col) async {
    while (true) {
      final snap = await col.limit(_batchLimit).get(_server);
      if (snap.docs.isEmpty) return;
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit().timeout(_writeTimeout);
    }
  }

  /// Resumen que ve el administrador en su panel.
  Map<String, dynamic> _profileSummary() {
    final last30 = inventory.salesLastDays(30);
    final lastSale = inventory.sales.isEmpty ? null : inventory.sales.first;
    return {
      'email': (user.email ?? '').toLowerCase(),
      'name': _name,
      'businessName': inventory.businessName,
      'lastSeen': FieldValue.serverTimestamp(),
      'appVersion': AppConstants.appVersion,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'plan': subscription.planCode,
      'mercadoPago': subscription.mercadoPagoActive,
      'premiumPlan': subscription.plan.id,
      'stats': {
        'products': inventory.products.length,
        'lowStock': inventory.lowStockProducts.length,
        'inventoryValue': inventory.inventoryValue,
        'salesToday': inventory.todayTotal,
        'sales30d': last30.fold<int>(0, (sum, s) => sum + s.total),
        'salesCount30d': last30.length,
        'lastSaleAt':
            lastSale == null ? null : Timestamp.fromDate(lastSale.date),
      },
    };
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _profileSub?.cancel();
    inventory.removeListener(_schedule);
    subscription.removeListener(_onSubscriptionChanged);
    super.dispose();
  }
}
