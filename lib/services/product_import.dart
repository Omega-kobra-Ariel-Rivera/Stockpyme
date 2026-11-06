import '../l10n/i18n.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

/// Una fila leída desde Excel, Google Sheets o un archivo CSV.
class ImportRow {
  ImportRow({
    required this.line,
    required this.name,
    this.barcode = '',
    this.category = '',
    this.unit = 'unidad',
    this.costPrice,
    this.salePrice,
    this.stock,
    this.minStock,
    this.error,
  });

  /// Número de fila en lo que se pegó (para mostrar errores).
  final int line;
  final String name;
  final String barcode;
  final String category;
  final String unit;
  final int? costPrice;
  final int? salePrice;
  final double? stock;
  final double? minStock;

  /// Motivo por el que la fila no se puede importar (null si está bien).
  final String? error;

  bool get isValid => error == null;
}

enum _Col { name, barcode, category, unit, cost, price, stock, minStock }

/// Lee lo que el usuario copió desde Excel (columnas separadas por
/// tabulación) o un CSV (separado por ";" o ","). La primera fila puede ser
/// de títulos: se reconocen "Nombre", "Código", "Precio", etc. en español,
/// inglés o portugués. Sin títulos, se usa el mismo orden que "Copiar
/// inventario": Nombre; Código; Categoría; Unidad; Costo; Precio; Stock;
/// Stock mínimo.
class ProductImport {
  ProductImport._();

  /// Fila de títulos para la plantilla de Excel.
  static String get templateHeader =>
      tr('Nombre;Código;Categoría;Unidad;Costo;Precio;Stock;Stock mínimo')
          .replaceAll(';', '\t');

  static List<ImportRow> parse(String text) {
    final lines = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return [];

    final sep = _separator(lines.first);
    var cells = lines.map((l) => _split(l, sep)).toList();

    // ¿La primera fila son títulos?
    var map = _headerMap(cells.first);
    var firstLine = 1;
    if (map == null) {
      map = {
        for (var i = 0; i < _Col.values.length; i++) _Col.values[i]: i,
      };
      firstLine = 0;
    } else {
      cells = cells.sublist(1);
    }

    final rows = <ImportRow>[];
    for (var i = 0; i < cells.length; i++) {
      rows.add(_row(cells[i], map, i + 1 + firstLine));
    }
    return rows;
  }

  static String _separator(String line) {
    if (line.contains('\t')) return '\t';
    final semi = ';'.allMatches(line).length;
    final comma = ','.allMatches(line).length;
    return semi >= comma && semi > 0 ? ';' : (comma > 0 ? ',' : '\t');
  }

  /// Separa una línea respetando comillas ("Arroz; grado 1").
  static List<String> _split(String line, String sep) {
    final out = <String>[];
    final buf = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (quoted && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (ch == sep && !quoted) {
        out.add(buf.toString().trim());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    out.add(buf.toString().trim());
    return out;
  }

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[áàâã]'), 'a')
      .replaceAll(RegExp('[éèê]'), 'e')
      .replaceAll(RegExp('[íì]'), 'i')
      .replaceAll(RegExp('[óòôõ]'), 'o')
      .replaceAll(RegExp('[úù]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static _Col? _colFor(String header) {
    final h = _norm(header);
    if (h.isEmpty) return null;
    bool has(List<String> words) => words.any(h.contains);
    if (has(['minimo', 'minimum', 'min stock', 'stock min', 'alerta'])) {
      return _Col.minStock;
    }
    if (has(['codigo', 'barcode', 'code', 'ean', 'sku', 'barra'])) {
      return _Col.barcode;
    }
    if (has(['categor', 'rubro', 'familia', 'category'])) return _Col.category;
    if (has(['unidad', 'unit', 'medida'])) return _Col.unit;
    if (has(['costo', 'cost', 'custo', 'compra'])) return _Col.cost;
    if (has(['precio', 'price', 'preco', 'venta', 'valor'])) return _Col.price;
    if (has(['stock', 'cantidad', 'existencia', 'estoque', 'qty', 'quantity'])) {
      return _Col.stock;
    }
    if (has(['nombre', 'name', 'nome', 'producto', 'product', 'produto', 'descrip'])) {
      return _Col.name;
    }
    return null;
  }

  static Map<_Col, int>? _headerMap(List<String> first) {
    final map = <_Col, int>{};
    for (var i = 0; i < first.length; i++) {
      final c = _colFor(first[i]);
      if (c != null && !map.containsKey(c)) map[c] = i;
    }
    // Es fila de títulos si trae el nombre y al menos otra columna conocida,
    // y no trae números de precio.
    final looksNumeric = first.any((c) => RegExp(r'^\$?\s*\d').hasMatch(c));
    if (map.containsKey(_Col.name) && map.length >= 2 && !looksNumeric) {
      return map;
    }
    return null;
  }

  static String _unit(String raw) {
    final n = _norm(raw);
    if (n.isEmpty) return 'unidad';
    for (final u in AppConstants.units) {
      if (n == _norm(u) || n == _norm(unitLabel(u))) return u;
    }
    if (n.startsWith('kilo') || n == 'kgs') return 'kg';
    if (n.startsWith('gram') || n == 'gr') return 'g';
    if (n.startsWith('lit') || n == 'l' || n == 'lt' || n == 'lts') {
      return 'litro';
    }
    if (n.startsWith('caj') || n == 'box') return 'caja';
    if (n.startsWith('paq') || n == 'pack') return 'paquete';
    return 'unidad';
  }

  static ImportRow _row(List<String> cells, Map<_Col, int> map, int line) {
    String get(_Col c) {
      final i = map[c];
      return i == null || i >= cells.length ? '' : cells[i].trim();
    }

    final name = get(_Col.name);
    final rawCost = get(_Col.cost);
    final rawPrice = get(_Col.price);
    final rawStock = get(_Col.stock);
    final rawMin = get(_Col.minStock);
    final cost = rawCost.isEmpty ? null : parseMoney(rawCost);
    final price = rawPrice.isEmpty ? null : parseMoney(rawPrice);
    final stock = rawStock.isEmpty ? null : parseQty(rawStock);
    final min = rawMin.isEmpty ? null : parseQty(rawMin);

    String? error;
    if (name.isEmpty) {
      error = tr('Falta el nombre');
    } else if (rawPrice.isNotEmpty && price == null) {
      error = tr('Precio no válido: {v}', {'v': rawPrice});
    } else if (rawCost.isNotEmpty && cost == null) {
      error = tr('Costo no válido: {v}', {'v': rawCost});
    } else if (rawStock.isNotEmpty && stock == null) {
      error = tr('Stock no válido: {v}', {'v': rawStock});
    }

    return ImportRow(
      line: line,
      name: name,
      barcode: get(_Col.barcode).replaceAll(RegExp(r'\s'), ''),
      category: get(_Col.category),
      unit: _unit(get(_Col.unit)),
      costPrice: cost,
      salePrice: price,
      stock: stock,
      minStock: min,
      error: error,
    );
  }
}
