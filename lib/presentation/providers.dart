import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repositories/supabase_repositories.dart';
import '../domain/entities/entities.dart';
import '../domain/repositories/repositories.dart';
import '../services/printer_service.dart';

final supabaseProvider = Provider<SupabaseClient>((_) => Supabase.instance.client);

final authRepoProvider = Provider<AuthRepository>((r) => SupabaseAuthRepository(r.watch(supabaseProvider)));
final productRepoProvider = Provider<ProductRepository>((r) => SupabaseProductRepository(r.watch(supabaseProvider)));
final salesRepoProvider = Provider<SalesRepository>((r) => SupabaseSalesRepository(r.watch(supabaseProvider)));
final adminRepoProvider = Provider<AdminRepository>((r) => SupabaseAdminRepository(r.watch(supabaseProvider)));
final printerProvider = Provider<PrinterService>((_) => PrinterService());

// ---------------- Auth ----------------
final authStateProvider = StreamProvider<AuthState>((r) => r.watch(supabaseProvider).auth.onAuthStateChange);

final isAdminProvider = FutureProvider<bool>((r) {
  r.watch(authStateProvider); // re-evaluate on login/logout
  return r.watch(authRepoProvider).isAdmin();
});

// ---------------- Cart ----------------
class CartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() => const [];

  double get total => state.fold(0, (s, i) => s + i.total);

  /// Returns false when the requested quantity exceeds known stock.
  bool add(Product p, {int qty = 1}) {
    final idx = state.indexWhere((i) => i.product.id == p.id);
    final current = idx < 0 ? 0 : state[idx].quantity;
    if (current + qty > p.stockQuantity) return false;
    state = idx < 0
        ? [...state, CartItem(p, qty)]
        : [for (var i = 0; i < state.length; i++) i == idx ? state[i].copyWith(quantity: current + qty) : state[i]];
    return true;
  }

  bool setQuantity(String productId, int qty) {
    if (qty <= 0) {
      remove(productId);
      return true;
    }
    final item = state.firstWhere((i) => i.product.id == productId);
    if (qty > item.product.stockQuantity) return false;
    state = [for (final i in state) i.product.id == productId ? i.copyWith(quantity: qty) : i];
    return true;
  }

  void remove(String productId) => state = state.where((i) => i.product.id != productId).toList();
  void clear() => state = const [];
}

final cartProvider = NotifierProvider<CartNotifier, List<CartItem>>(CartNotifier.new);
final cartTotalProvider = Provider<double>((r) => r.watch(cartProvider).fold(0.0, (s, i) => s + i.total));

// ---------------- Quick price check (never touches the cart) ----------------
enum QuickCheckStatus { idle, loading, found, notFound, error }

class QuickCheckState {
  final QuickCheckStatus status;
  final Product? product;
  final String? barcode;
  final String? error;
  const QuickCheckState(this.status, {this.product, this.barcode, this.error});
}

class QuickCheckNotifier extends Notifier<QuickCheckState> {
  int _seq = 0;

  @override
  QuickCheckState build() => const QuickCheckState(QuickCheckStatus.idle);

  Future<void> lookup(String barcode) async {
    final my = ++_seq; // ignore stale responses if the worker scans quickly again
    state = QuickCheckState(QuickCheckStatus.loading, barcode: barcode);
    try {
      final p = await ref.read(productRepoProvider).findByBarcode(barcode);
      if (my != _seq) return;
      state = p == null
          ? QuickCheckState(QuickCheckStatus.notFound, barcode: barcode)
          : QuickCheckState(QuickCheckStatus.found, product: p, barcode: barcode);
    } catch (e) {
      if (my != _seq) return;
      state = QuickCheckState(QuickCheckStatus.error, barcode: barcode, error: e.toString());
    }
  }

  void clear() {
    _seq++;
    state = const QuickCheckState(QuickCheckStatus.idle);
  }
}

final quickCheckProvider = NotifierProvider<QuickCheckNotifier, QuickCheckState>(QuickCheckNotifier.new);

// ---------------- Admin ----------------
class DateRangeNotifier extends Notifier<DateTimeRange> {
  @override
  DateTimeRange build() {
    final n = DateTime.now();
    final start = DateTime(n.year, n.month, n.day);
    return DateTimeRange(start: start, end: start.add(const Duration(days: 1)));
  }

  void set(DateTimeRange r) => state = DateTimeRange(start: r.start, end: r.end.add(const Duration(days: 1)));
  void setRaw(DateTimeRange r) => state = r;
}

final dateRangeProvider = NotifierProvider<DateRangeNotifier, DateTimeRange>(DateRangeNotifier.new);

final salesProvider = FutureProvider<List<Sale>>((r) {
  final range = r.watch(dateRangeProvider);
  return r.watch(adminRepoProvider).sales(from: range.start, to: range.end);
});

final stockLogsProvider =
    FutureProvider<List<StockLog>>((r) => r.watch(adminRepoProvider).stockLogs());

final liveProductsProvider = StreamProvider<List<Product>>((r) => r.watch(productRepoProvider).watchAll());

final changesProvider = StreamProvider<void>((r) => r.watch(adminRepoProvider).watchChanges());

/// Product-level aggregation of the sales in the selected range.
final productStatsProvider = Provider<List<ProductSalesStat>>((r) {
  final sales = r.watch(salesProvider).value ?? const <Sale>[];
  final map = <String, (int, double)>{};
  for (final s in sales) {
    for (final l in s.lines) {
      final cur = map[l.name] ?? (0, 0.0);
      map[l.name] = (cur.$1 + l.quantity, cur.$2 + l.total);
    }
  }
  final list = [for (final e in map.entries) ProductSalesStat(e.key, e.value.$1, e.value.$2)]
    ..sort((a, b) => b.revenue.compareTo(a.revenue));
  return list;
});
