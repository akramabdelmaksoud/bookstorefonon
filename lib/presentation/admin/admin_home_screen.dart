import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/config/env.dart';
import '../providers.dart';
import '../cashier/cashier_screen.dart';
import 'overview_tab.dart';
import 'receipts_tab.dart';
import 'stock_logs_tab.dart';
import 'stock_tab.dart';

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  Future<void> _pickRange(BuildContext context, WidgetRef ref) async {
    final cur = ref.read(dateRangeProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: cur.start, end: cur.end.subtract(const Duration(days: 1))),
    );
    if (picked != null) ref.read(dateRangeProvider.notifier).set(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Realtime: any new stock_log row (sale / restock / adjustment) refreshes the dashboard.
    ref.listen(changesProvider, (_, _) {
      ref.invalidate(salesProvider);
      ref.invalidate(stockLogsProvider);
    });
    final range = ref.watch(dateRangeProvider);
    final f = DateFormat('MMM d');
    final last = range.end.subtract(const Duration(days: 1));
    final label = range.start == DateTime(last.year, last.month, last.day) ? f.format(range.start) : '${f.format(range.start)} – ${f.format(last)}';

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${Env.storeName} · Admin'),
          actions: [
            TextButton.icon(onPressed: () => _pickRange(context, ref), icon: const Icon(Icons.date_range), label: Text(label)),
            IconButton(
              tooltip: 'Open cashier screen',
              icon: const Icon(Icons.point_of_sale),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CashierScreen())),
            ),
            IconButton(tooltip: 'Sign out', icon: const Icon(Icons.logout), onPressed: () => ref.read(authRepoProvider).signOut()),
          ],
          bottom: const TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
            Tab(icon: Icon(Icons.insights), text: 'Overview'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Receipts'),
            Tab(icon: Icon(Icons.inventory_2), text: 'Live stock'),
            Tab(icon: Icon(Icons.history), text: 'Stock log'),
          ]),
        ),
        body: const TabBarView(children: [OverviewTab(), ReceiptsTab(), StockTab(), StockLogsTab()]),
      ),
    );
  }
}

/// Shared loading/error wrapper for admin tabs.
Widget asyncBody<T>(WidgetRef ref, AsyncValue<T> v, VoidCallback retry, Widget Function(T) builder) => v.when(
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Failed to load\n$e', textAlign: TextAlign.center),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: retry, child: const Text('Retry')),
        ]),
      ),
      data: builder,
    );
