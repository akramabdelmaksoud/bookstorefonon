class Product {
  final String id;
  final String name;
  final String barcode;
  final double purchasePrice;
  final double sellingPrice;
  final int stockQuantity;

  const Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.stockQuantity,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'] as String,
        name: j['name'] as String,
        barcode: j['barcode'] as String,
        purchasePrice: (j['purchase_price'] as num).toDouble(),
        sellingPrice: (j['selling_price'] as num).toDouble(),
        stockQuantity: j['stock_quantity'] as int,
      );
}

class CartItem {
  final Product product;
  final int quantity;

  const CartItem(this.product, this.quantity);

  double get total => product.sellingPrice * quantity;
  CartItem copyWith({int? quantity}) => CartItem(product, quantity ?? this.quantity);
}

class SaleLine {
  final String name;
  final int quantity;
  final double unitPrice;
  final double total;

  const SaleLine(this.name, this.quantity, this.unitPrice, this.total);
}

class Sale {
  final String id;
  final String cashierId;
  final double total;
  final String paymentMethod;
  final DateTime createdAt;
  final List<SaleLine> lines;

  const Sale({
    required this.id,
    required this.cashierId,
    required this.total,
    required this.paymentMethod,
    required this.createdAt,
    this.lines = const [],
  });

  factory Sale.fromJson(Map<String, dynamic> j) {
    final items = (j['transaction_items'] as List? ?? const []).map((e) {
      final m = e as Map<String, dynamic>;
      final p = m['products'] as Map<String, dynamic>?;
      return SaleLine(
        p?['name'] as String? ?? 'Deleted product',
        m['quantity'] as int,
        (m['unit_price'] as num).toDouble(),
        (m['total_price'] as num).toDouble(),
      );
    }).toList();
    return Sale(
      id: j['id'] as String,
      cashierId: j['cashier_id'] as String,
      total: (j['total_amount'] as num).toDouble(),
      paymentMethod: j['payment_method'] as String,
      createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      lines: items,
    );
  }
}

class StockLog {
  final String id;
  final String productName;
  final String changeType;
  final int quantityChanged;
  final int previousStock;
  final int newStock;
  final String? reason;
  final DateTime createdAt;

  const StockLog({
    required this.id,
    required this.productName,
    required this.changeType,
    required this.quantityChanged,
    required this.previousStock,
    required this.newStock,
    required this.reason,
    required this.createdAt,
  });

  factory StockLog.fromJson(Map<String, dynamic> j) => StockLog(
        id: j['id'] as String,
        productName: (j['products'] as Map<String, dynamic>?)?['name'] as String? ?? '—',
        changeType: j['change_type'] as String,
        quantityChanged: j['quantity_changed'] as int,
        previousStock: j['previous_stock'] as int,
        newStock: j['new_stock'] as int,
        reason: j['reason'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      );
}

class ProductSalesStat {
  final String name;
  final int unitsSold;
  final double revenue;
  const ProductSalesStat(this.name, this.unitsSold, this.revenue);
}
