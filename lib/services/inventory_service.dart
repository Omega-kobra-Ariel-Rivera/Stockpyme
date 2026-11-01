import 'dart:math';

import 'package:flutter/foundation.dart';

import '../l10n/i18n.dart';
import '../models/product.dart';
import '../models/report_models.dart';
import '../models/sale.dart';
import '../models/stock_movement.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/id_generator.dart';
import 'cart_service.dart';
import 'storage_service.dart';

/// Error de negocio con mensaje listo para mostrar al usuario.
class InventoryException implements Exception {
  InventoryException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Cambios pendientes de subir a la nube.
class CloudChanges {
  CloudChanges({
    required this.products,
    required this.deletedProductIds,
    required this.sales,
    required this.profileChanged,
    required this.wipe,
  });

  final List<Product> products;
  final List<String> deletedProductIds;
  final List<Sale> sales;
  final bool profileChanged;

  /// El usuario borró todos sus datos.
  final bool wipe;

  bool get isEmpty =>
      products.isEmpty &&
      deletedProductIds.isEmpty &&
      sales.isEmpty &&
      !profileChanged &&
      !wipe;
}

/// Lógica central: productos, stock, ventas y reportes.
class InventoryService extends ChangeNotifier {
  InventoryService(this._storage);

  final StorageService _storage;

  List<Product> _products = [];
  List<Sale> _sales = [];
  List<StockMovement> _movements = [];
  String _businessName = 'Mi negocio';
  AppCurrency _currency = AppCurrency.clp;

  // Cambios que la sincronización con la nube aún no sube.
  final Set<String> _dirtyProducts = {};
  final Set<String> _deletedProducts = {};
  final List<Sale> _newSales = [];
  bool _profileDirty = false;
  bool _wipeRequested = false;

  List<Product> get products => List.unmodifiable(_products);
  List<Sale> get sales => List.unmodifiable(_sales);
  String get businessName => _businessName;

  /// Nombre para mostrar (el nombre por defecto se traduce).
  String get businessLabel =>
      _businessName == 'Mi negocio' ? tr('Mi negocio') : _businessName;

  /// Moneda en que el negocio lleva sus precios y ventas.
  AppCurrency get currency => _currency;

  List<Product> get lowStockProducts =>
      _products.where((p) => p.isLowStock).toList();

  List<String> get categories {
    final set = <String>{
      for (final p in _products)
        if (p.category.trim().isNotEmpty) p.category.trim(),
    };
    final list = set.toList()..sort();
    return list;
  }

  // ---------------------------------------------------------------------------
  // Carga y guardado
  // ---------------------------------------------------------------------------

  Future<void> init() async {
    _products = _storage
        .readList(StorageKeys.products)
        .map(Product.fromJson)
        .toList();
    _sales =
        _storage.readList(StorageKeys.sales).map(Sale.fromJson).toList();
    _movements = _storage
        .readList(StorageKeys.movements)
        .map(StockMovement.fromJson)
        .toList();
    _businessName =
        _storage.getString(StorageKeys.businessName) ?? 'Mi negocio';
    _currency = AppCurrency.fromCode(_storage.getString(StorageKeys.currency));
    Money.currency = _currency;
    _sortProducts();
    _sales.sort((a, b) => b.date.compareTo(a.date));
    _movements.sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> _saveProducts() => _storage.writeList(
      StorageKeys.products, _products.map((p) => p.toJson()).toList());

  Future<void> _saveSales() => _storage.writeList(
      StorageKeys.sales, _sales.map((s) => s.toJson()).toList());

  Future<void> _saveMovements() => _storage.writeList(
      StorageKeys.movements, _movements.map((m) => m.toJson()).toList());

  void _sortProducts() {
    _products.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> setBusinessName(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    _businessName = clean;
    _profileDirty = true;
    await _storage.setString(StorageKeys.businessName, clean);
    notifyListeners();
  }

  /// Cambia la moneda. Los montos guardados mantienen su número
  /// ($1.290 pasa a US$1,290.00): no se convierte con el tipo de cambio.
  Future<void> setCurrency(AppCurrency currency) async {
    if (currency == _currency) return;
    final from = _currency.factor;
    final to = currency.factor;
    if (from != to) {
      int scale(int v) => (v * to / from).round();
      for (final p in _products) {
        p.costPrice = scale(p.costPrice);
        p.salePrice = scale(p.salePrice);
        p.updatedAt = DateTime.now();
      }
      _sales = [
        for (final sale in _sales)
          Sale(
            id: sale.id,
            number: sale.number,
            date: sale.date,
            paymentMethod: sale.paymentMethod,
            items: [
              for (final item in sale.items)
                SaleItem(
                  productId: item.productId,
                  name: item.name,
                  quantity: item.quantity,
                  unitPrice: scale(item.unitPrice),
                  unitCost: scale(item.unitCost),
                ),
            ],
          ),
      ];
      await _saveProducts();
      await _saveSales();
      // Sube todo otra vez con los montos nuevos.
      markAllForUpload(maxSales: 500);
    }
    _currency = currency;
    Money.currency = currency;
    _profileDirty = true;
    await _storage.setString(StorageKeys.currency, currency.code);
    notifyListeners();
  }

  /// Moneda guardada en la nube (teléfono nuevo); no cambia los montos.
  Future<void> applyCloudCurrency(String? code) async {
    if (code == null || code.isEmpty) return;
    final currency = AppCurrency.fromCode(code);
    if (currency == _currency) return;
    _currency = currency;
    Money.currency = currency;
    await _storage.setString(StorageKeys.currency, currency.code);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Productos
  // ---------------------------------------------------------------------------

  Product? productById(String id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Product? findByBarcode(String barcode) {
    final code = barcode.trim();
    if (code.isEmpty) return null;
    for (final p in _products) {
      if (p.barcode == code) return p;
    }
    return null;
  }

  bool isBarcodeTaken(String barcode, {String? exceptId}) {
    final found = findByBarcode(barcode);
    return found != null && found.id != exceptId;
  }

  List<Product> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return products;
    return _products
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.barcode.contains(q) ||
            p.category.toLowerCase().contains(q))
        .toList();
  }

  Future<void> addProduct(Product product) async {
    if (isBarcodeTaken(product.barcode)) {
      throw InventoryException(tr('Ya existe un producto con ese código.'));
    }
    _products.add(product);
    _dirtyProducts.add(product.id);
    _sortProducts();
    if (product.stock > 0) {
      _addMovement(product, MovementType.entrada, product.stock,
          note: tr('Stock inicial'));
      await _saveMovements();
    }
    await _saveProducts();
    notifyListeners();
  }

  Future<void> updateProduct(Product updated) async {
    final existing = productById(updated.id);
    if (existing == null) {
      throw InventoryException(tr('El producto ya no existe.'));
    }
    if (isBarcodeTaken(updated.barcode, exceptId: updated.id)) {
      throw InventoryException(tr('Ya existe otro producto con ese código.'));
    }
    final difference = updated.stock - existing.stock;
    existing.applyFrom(updated);
    _dirtyProducts.add(existing.id);
    if (difference != 0) {
      _addMovement(existing, MovementType.ajuste, difference,
          note: tr('Edición de producto'));
      await _saveMovements();
    }
    _sortProducts();
    await _saveProducts();
    notifyListeners();
  }

  Future<void> deleteProduct(String id) async {
    _products.removeWhere((p) => p.id == id);
    _dirtyProducts.remove(id);
    _deletedProducts.add(id);
    await _saveProducts();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Stock
  // ---------------------------------------------------------------------------

  void _addMovement(Product product, MovementType type, double quantity,
      {String note = ''}) {
    _movements.insert(
      0,
      StockMovement(
        id: newId(),
        productId: product.id,
        productName: product.name,
        type: type,
        quantity: quantity,
        date: DateTime.now(),
        note: note,
      ),
    );
  }

  /// [quantity] siempre positiva; el tipo define si suma o resta.
  Future<void> adjustStock(
    Product product,
    MovementType type,
    double quantity, {
    String note = '',
    int? newCostPrice,
  }) async {
    if (quantity <= 0) {
      throw InventoryException(tr('La cantidad debe ser mayor a cero.'));
    }
    final adds = type == MovementType.entrada;
    if (!adds && quantity > product.stock) {
      throw InventoryException(
          tr('No puedes descontar más de lo que hay ({qty}).', {
        'qty': '${formatQty(product.stock)} ${unitLabel(product.unit)}',
      }));
    }
    product.stock += adds ? quantity : -quantity;
    if (newCostPrice != null && newCostPrice >= 0) {
      product.costPrice = newCostPrice;
    }
    product.updatedAt = DateTime.now();
    _dirtyProducts.add(product.id);
    _addMovement(product, type, adds ? quantity : -quantity, note: note);
    await _saveProducts();
    await _saveMovements();
    notifyListeners();
  }

  List<StockMovement> movementsFor(String productId) =>
      _movements.where((m) => m.productId == productId).toList();

  // ---------------------------------------------------------------------------
  // Ventas
  // ---------------------------------------------------------------------------

  Future<Sale> registerSale(
      List<CartItem> items, PaymentMethod paymentMethod) async {
    if (items.isEmpty) {
      throw InventoryException(tr('El carrito está vacío.'));
    }

    final resolved = <Product, double>{};
    for (final item in items) {
      final product = productById(item.product.id);
      if (product == null) {
        throw InventoryException(
            tr('"{name}" fue eliminado. Quítalo del carrito.',
                {'name': item.product.name}));
      }
      if (item.quantity > product.stock) {
        throw InventoryException(
            tr('Stock insuficiente de {name} (quedan {qty}).', {
          'name': product.name,
          'qty': '${formatQty(product.stock)} ${unitLabel(product.unit)}',
        }));
      }
      resolved[product] = item.quantity;
    }

    final nextNumber =
        _sales.isEmpty ? 1 : _sales.map((s) => s.number).reduce(max) + 1;

    final sale = Sale(
      id: newId(),
      number: nextNumber,
      date: DateTime.now(),
      paymentMethod: paymentMethod,
      items: [
        for (final entry in resolved.entries)
          SaleItem(
            productId: entry.key.id,
            name: entry.key.name,
            quantity: entry.value,
            unitPrice: entry.key.salePrice,
            unitCost: entry.key.costPrice,
          ),
      ],
    );

    for (final entry in resolved.entries) {
      entry.key.stock -= entry.value;
      entry.key.updatedAt = sale.date;
      _dirtyProducts.add(entry.key.id);
      _addMovement(entry.key, MovementType.venta, -entry.value,
          note: tr('Venta N° {n}', {'n': sale.number}));
    }

    _sales.insert(0, sale);
    _newSales.add(sale);
    await _saveProducts();
    await _saveSales();
    await _saveMovements();
    notifyListeners();
    return sale;
  }

  // ---------------------------------------------------------------------------
  // Reportes
  // ---------------------------------------------------------------------------

  List<Sale> salesLastDays(int days) {
    final start = startOfDay(DateTime.now())
        .subtract(Duration(days: days - 1));
    return _sales.where((s) => !s.date.isBefore(start)).toList();
  }

  int get todayTotal =>
      salesLastDays(1).fold(0, (sum, s) => sum + s.total);

  int get todayProfit =>
      salesLastDays(1).fold(0, (sum, s) => sum + s.profit);

  int get todaySalesCount => salesLastDays(1).length;

  int get inventoryValue => _products.fold(
      0, (sum, p) => sum + (p.costPrice * max(p.stock, 0)).round());

  List<DailyTotal> dailyTotals(int days) {
    final today = startOfDay(DateTime.now());
    final result = <DailyTotal>[];
    for (var i = days - 1; i >= 0; i--) {
      final day = DateTime(today.year, today.month, today.day - i);
      final next = DateTime(day.year, day.month, day.day + 1);
      final total = _sales
          .where((s) => !s.date.isBefore(day) && s.date.isBefore(next))
          .fold(0, (sum, s) => sum + s.total);
      result.add(DailyTotal(day: day, total: total));
    }
    return result;
  }

  List<TopProduct> topProducts(int days, {int limit = 5}) {
    final map = <String, TopProduct>{};
    for (final sale in salesLastDays(days)) {
      for (final item in sale.items) {
        final entry =
            map.putIfAbsent(item.productId, () => TopProduct(name: item.name));
        entry.quantity += item.quantity;
        entry.total += item.subtotal;
      }
    }
    final list = map.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return list.take(limit).toList();
  }

  Map<PaymentMethod, int> totalsByPayment(int days) {
    final map = <PaymentMethod, int>{};
    for (final sale in salesLastDays(days)) {
      map[sale.paymentMethod] = (map[sale.paymentMethod] ?? 0) + sale.total;
    }
    return map;
  }

  // ---------------------------------------------------------------------------
  // Exportación (CSV con ";" para Excel en español)
  // ---------------------------------------------------------------------------

  String _csv(Object? value) {
    final text = '${value ?? ''}';
    if (text.contains(';') || text.contains('"') || text.contains('\n')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  String exportProductsCsv() {
    final buffer = StringBuffer(
        '${tr('Nombre;Código;Categoría;Unidad;Costo;Precio;Stock;Stock mínimo')}\n');
    for (final p in _products) {
      buffer.writeln([
        p.name,
        p.barcode,
        p.category,
        unitLabel(p.unit),
        _currency.toPlain(p.costPrice),
        _currency.toPlain(p.salePrice),
        formatQty(p.stock),
        formatQty(p.minStock),
      ].map(_csv).join(';'));
    }
    return buffer.toString();
  }

  String exportSalesCsv(int days) {
    final buffer = StringBuffer(
        '${tr('Fecha;Venta N°;Producto;Cantidad;Precio unitario;Subtotal;Ganancia;Medio de pago')}\n');
    for (final sale in salesLastDays(days)) {
      for (final item in sale.items) {
        buffer.writeln([
          formatDateTime(sale.date),
          sale.number,
          item.name,
          formatQty(item.quantity),
          _currency.toPlain(item.unitPrice),
          _currency.toPlain(item.subtotal),
          _currency.toPlain(item.profit),
          sale.paymentMethod.label,
        ].map(_csv).join(';'));
      }
    }
    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // Datos
  // ---------------------------------------------------------------------------

  Future<void> deleteAllData() async {
    _products = [];
    _sales = [];
    _movements = [];
    _dirtyProducts.clear();
    _deletedProducts.clear();
    _newSales.clear();
    _wipeRequested = true;
    await _storage.clearBusinessData();
    notifyListeners();
  }

  /// Productos de ejemplo para probar la app o grabar capturas para la tienda.
  Future<void> loadDemoData() async {
    final demo = <Product>[
      Product(id: newId(), name: tr('Bebida cola 1,5 L'), barcode: '7801610001196', category: tr('Bebidas'), costPrice: 1350, salePrice: 1990, stock: 24, minStock: 6),
      Product(id: newId(), name: tr('Agua mineral 1,6 L'), barcode: '7801620002345', category: tr('Bebidas'), costPrice: 650, salePrice: 1100, stock: 4, minStock: 6),
      Product(id: newId(), name: tr('Leche entera 1 L'), barcode: '7802900001018', category: tr('Lácteos'), costPrice: 890, salePrice: 1290, stock: 18, minStock: 8),
      Product(id: newId(), name: tr('Pan marraqueta'), category: tr('Panadería'), unit: 'kg', costPrice: 1500, salePrice: 2300, stock: 12.5, minStock: 5),
      Product(id: newId(), name: tr('Arroz grado 1, 1 kg'), barcode: '7801320000127', category: tr('Abarrotes'), costPrice: 1150, salePrice: 1690, stock: 15, minStock: 5),
      Product(id: newId(), name: tr('Aceite maravilla 1 L'), barcode: '7802810004561', category: tr('Abarrotes'), costPrice: 1990, salePrice: 2790, stock: 3, minStock: 4),
      Product(id: newId(), name: tr('Fideos spaghetti 400 g'), barcode: '7802575001123', category: tr('Abarrotes'), costPrice: 690, salePrice: 1050, stock: 30, minStock: 10),
      Product(id: newId(), name: tr('Huevos bandeja 12'), category: tr('Frescos'), costPrice: 2800, salePrice: 3790, stock: 8, minStock: 4),
      Product(id: newId(), name: tr('Té 100 bolsitas'), barcode: '7802950006789', category: tr('Abarrotes'), costPrice: 2100, salePrice: 2990, stock: 10, minStock: 3),
      Product(id: newId(), name: tr('Azúcar 1 kg'), barcode: '7801505000014', category: tr('Abarrotes'), costPrice: 990, salePrice: 1490, stock: 20, minStock: 6),
    ];
    for (final product in demo) {
      if (!isBarcodeTaken(product.barcode)) {
        _products.add(product);
        _dirtyProducts.add(product.id);
        _addMovement(product, MovementType.entrada, product.stock,
            note: tr('Datos de ejemplo'));
      }
    }
    _sortProducts();
    await _saveProducts();
    await _saveMovements();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Nube
  // ---------------------------------------------------------------------------

  bool get hasCloudChanges =>
      _dirtyProducts.isNotEmpty ||
      _deletedProducts.isNotEmpty ||
      _newSales.isNotEmpty ||
      _profileDirty ||
      _wipeRequested;

  /// Entrega los cambios pendientes y los marca como enviados.
  CloudChanges takeCloudChanges() {
    final changes = CloudChanges(
      products: [
        for (final id in _dirtyProducts)
          if (productById(id) != null) productById(id)!,
      ],
      deletedProductIds: _deletedProducts.toList(),
      sales: List.of(_newSales),
      profileChanged: _profileDirty,
      wipe: _wipeRequested,
    );
    _dirtyProducts.clear();
    _deletedProducts.clear();
    _newSales.clear();
    _profileDirty = false;
    _wipeRequested = false;
    return changes;
  }

  /// Si la subida falla, se vuelven a marcar para el próximo intento.
  void requeueCloudChanges(CloudChanges changes) {
    if (changes.wipe) _wipeRequested = true;
    for (final p in changes.products) {
      _dirtyProducts.add(p.id);
    }
    _deletedProducts.addAll(changes.deletedProductIds);
    _newSales.addAll(changes.sales);
    if (changes.profileChanged) _profileDirty = true;
  }

  /// Marca todo para subir (primera sincronización de este teléfono).
  void markAllForUpload({int maxSales = 300}) {
    _dirtyProducts.addAll(_products.map((p) => p.id));
    _newSales
      ..clear()
      ..addAll(_sales.take(maxSales));
    _profileDirty = true;
  }

  /// Carga los datos guardados en la nube (teléfono nuevo o reinstalación).
  Future<void> restoreFromCloud({
    required List<Product> products,
    required List<Sale> sales,
    String? businessName,
  }) async {
    _products = List.of(products);
    _sales = List.of(sales)..sort((a, b) => b.date.compareTo(a.date));
    if (businessName != null && businessName.trim().isNotEmpty) {
      _businessName = businessName.trim();
      await _storage.setString(StorageKeys.businessName, _businessName);
    }
    _sortProducts();
    await _saveProducts();
    await _saveSales();
    notifyListeners();
  }

  /// Nombre del negocio sin marcarlo como cambio (lo trae la nube).
  Future<void> applyCloudBusinessName(String name) async {
    final clean = name.trim();
    if (clean.isEmpty || clean == _businessName) return;
    _businessName = clean;
    await _storage.setString(StorageKeys.businessName, clean);
    notifyListeners();
  }
}
