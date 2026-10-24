import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';

const _saleSelect =
    '*, transaction_items(quantity, unit_price, total_price, products(name))';

class SupabaseProductRepository implements ProductRepository {
  SupabaseProductRepository(this._db);
  final SupabaseClient _db;

  @override
  Future<Product?> findByBarcode(String barcode) async {
    final row = await _db.from('products').select().eq('barcode', barcode.trim()).maybeSingle();
    return row == null ? null : Product.fromJson(row);
  }

  @override
  Future<List<Product>> search(String query) async {
    // Strip characters that have meaning inside PostgREST filter syntax.
    final q = query.trim().replaceAll(RegExp(r'[,()%*]'), ' ');
    if (q.isEmpty) return const [];
    final rows = await _db
        .from('products')
        .select()
        .or('name.ilike.%$q%,barcode.ilike.%$q%')
        .order('name')
        .limit(30);
    return rows.map(Product.fromJson).toList();
  }

  @override
  Stream<List<Product>> watchAll() => _db
      .from('products')
      .stream(primaryKey: ['id'])
      .order('name')
      .map((rows) => rows.map(Product.fromJson).toList());
}

class SupabaseSalesRepository implements SalesRepository {
  SupabaseSalesRepository(this._db);
  final SupabaseClient _db;

  @override
  Future<Sale> completeSale(List<CartItem> items, String paymentMethod) async {
    final id = await _db.rpc('complete_sale', params: {
      'p_items': [
        for (final i in items) {'product_id': i.product.id, 'quantity': i.quantity}
      ],
      'p_payment_method': paymentMethod,
    }) as String;
    final row = await _db.from('transactions').select(_saleSelect).eq('id', id).single();
    return Sale.fromJson(row);
  }
}

class SupabaseAdminRepository implements AdminRepository {
  SupabaseAdminRepository(this._db);
  final SupabaseClient _db;

  @override
  Future<List<Sale>> sales({required DateTime from, required DateTime to}) async {
    final rows = await _db
        .from('transactions')
        .select(_saleSelect)
        .gte('created_at', from.toUtc().toIso8601String())
        .lt('created_at', to.toUtc().toIso8601String())
        .order('created_at', ascending: false);
    return rows.map(Sale.fromJson).toList();
  }

  @override
  Future<List<StockLog>> stockLogs({int limit = 200}) async {
    final rows = await _db
        .from('stock_logs')
        .select('*, products(name)')
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(StockLog.fromJson).toList();
  }

  /// Every sale/restock writes a stock_log row, so this single stream is enough
  /// to tell the dashboard "something changed, refetch".
  @override
  Stream<void> watchChanges() =>
      _db.from('stock_logs').stream(primaryKey: ['id']).map((_) {});

  @override
  Future<void> adjustStock({
    required String productId,
    required int delta,
    required String type,
    required String reason,
  }) =>
      _db.rpc('adjust_stock', params: {
        'p_product_id': productId,
        'p_delta': delta,
        'p_type': type,
        'p_reason': reason,
      });
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._db);
  final SupabaseClient _db;

  @override
  String? get userId => _db.auth.currentUser?.id;

  @override
  Future<void> signIn(String email, String password) =>
      _db.auth.signInWithPassword(email: email.trim(), password: password);

  @override
  Future<void> signOut() => _db.auth.signOut();

  @override
  Future<bool> isAdmin() async {
    final id = userId;
    if (id == null) return false;
    final row = await _db.from('profiles').select('role').eq('id', id).maybeSingle();
    return row?['role'] == 'admin';
  }
}
