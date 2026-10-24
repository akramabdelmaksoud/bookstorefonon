import '../entities/entities.dart';

abstract class ProductRepository {
  /// Returns null when the barcode is unknown.
  Future<Product?> findByBarcode(String barcode);
  Future<List<Product>> search(String query);
  Stream<List<Product>> watchAll();
}

abstract class SalesRepository {
  /// Atomically records the sale + decrements stock. Returns the stored [Sale].
  Future<Sale> completeSale(List<CartItem> items, String paymentMethod);
}

abstract class AdminRepository {
  Future<List<Sale>> sales({required DateTime from, required DateTime to});
  Future<List<StockLog>> stockLogs({int limit = 200});
  Stream<void> watchChanges();
  Future<void> adjustStock({
    required String productId,
    required int delta,
    required String type,
    required String reason,
  });
}

abstract class AuthRepository {
  String? get userId;
  Future<void> signIn(String email, String password);
  Future<void> signOut();
  Future<bool> isAdmin();
}
