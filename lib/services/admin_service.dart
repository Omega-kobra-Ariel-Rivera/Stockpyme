import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/admin_user.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../utils/constants.dart';

/// Lecturas y acciones del panel de administración.
/// Las reglas de seguridad de Firestore solo lo permiten a los correos
/// que están en la colección "admins".
class AdminService {
  AdminService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection(CloudPaths.users);

  /// Todas las cuentas, las más activas primero.
  static Stream<List<AdminUser>> watchUsers() {
    return _users.snapshots().map((snap) {
      final list = snap.docs.map(AdminUser.fromDoc).toList();
      list.sort((a, b) {
        final da = a.lastSeen ?? a.createdAt ?? DateTime(2000);
        final db = b.lastSeen ?? b.createdAt ?? DateTime(2000);
        return db.compareTo(da);
      });
      return list;
    });
  }

  static Stream<AdminUser> watchUser(String uid) =>
      _users.doc(uid).snapshots().map(AdminUser.fromDoc);

  static Stream<List<Product>> watchProducts(String uid) {
    return _users
        .doc(uid)
        .collection(CloudPaths.products)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => Product.fromJson(d.data())).toList();
      list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  static Stream<List<Sale>> watchSales(String uid, {int limit = 100}) {
    return _users
        .doc(uid)
        .collection(CloudPaths.sales)
        .orderBy('dateTs', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Sale.fromJson(d.data())).toList());
  }

  /// Activa Pro manualmente (por ejemplo, si te pagó en efectivo).
  /// Si ya tenía Pro manual vigente, suma los días al final.
  /// [tier] Básico (solo celular) o Negocio (celular + PC).
  static Future<void> grantPro(AdminUser user, int days, PlanTier tier) {
    final now = DateTime.now();
    final from = user.manualProActive ? user.manualProUntil! : now;
    return _users.doc(user.uid).update({
      'manualProUntil': Timestamp.fromDate(from.add(Duration(days: days))),
      'manualProTier': tier.id,
      'manualProBy': FirebaseAuth.instance.currentUser?.email ?? '',
      'manualProAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> revokePro(AdminUser user) {
    return _users.doc(user.uid).update({
      'manualProUntil': null,
      'manualProBy': FirebaseAuth.instance.currentUser?.email ?? '',
      'manualProAt': FieldValue.serverTimestamp(),
    });
  }
}
