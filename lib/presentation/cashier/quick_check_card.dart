import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../providers.dart';

/// Side box showing the last price-checked product. Independent of the cart.
class QuickCheckCard extends ConsumerWidget {
  const QuickCheckCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(quickCheckProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    Widget body;
    switch (s.status) {
      case QuickCheckStatus.idle:
        body = Text('Scan an item to check its price and stock.', style: text.bodyMedium);
      case QuickCheckStatus.loading:
        body = const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()));
      case QuickCheckStatus.notFound:
        body = Text('No product with barcode ${s.barcode}', style: text.titleMedium?.copyWith(color: scheme.error));
      case QuickCheckStatus.error:
        body = Text('Lookup failed. Check connection.\n${s.error}', style: TextStyle(color: scheme.error));
      case QuickCheckStatus.found:
        final p = s.product!;
        final out = p.stockQuantity == 0;
        body = Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(money(p.sellingPrice), style: text.headlineSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Chip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(out ? Icons.block : Icons.inventory_2, size: 16),
                label: Text(out ? 'Out of stock' : 'In stock: ${p.stockQuantity}'),
              ),
            ]),
          ),
          Column(children: [
            IconButton.filled(
              tooltip: 'Add to cart',
              icon: const Icon(Icons.add_shopping_cart),
              onPressed: out
                  ? null
                  : () {
                      final ok = ref.read(cartProvider.notifier).add(p);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        duration: const Duration(seconds: 1),
                        content: Text(ok ? 'Added ${p.name}' : 'Not enough stock'),
                      ));
                    },
            ),
            IconButton(
              tooltip: 'Dismiss',
              icon: const Icon(Icons.close),
              onPressed: ref.read(quickCheckProvider.notifier).clear,
            ),
          ]),
        ]);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 72), child: Align(alignment: Alignment.centerLeft, child: body)),
      ),
    );
  }
}
