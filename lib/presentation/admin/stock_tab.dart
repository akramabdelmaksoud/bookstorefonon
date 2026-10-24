import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../domain/entities/entities.dart';
import '../providers.dart';
import 'admin_home_screen.dart';

const lowStockThreshold = 5;

/// Live stock levels (Supabase realtime stream) with restock / adjustment actions.
class StockTab extends ConsumerStatefulWidget {
  const StockTab({super.key});

  @override
  ConsumerState<StockTab> createState() => _StockTabState();
}

class _StockTabState extends ConsumerState<StockTab> {
  String _q = '';

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            decoration: const InputDecoration(isDense: true, prefixIcon: Icon(Icons.search), hintText: 'Filter by name or barcode'),
            onChanged: (v) => setState(() => _q = v.toLowerCase()),
          ),
        ),
        Expanded(
          child: asyncBody<List<Product>>(ref, ref.watch(liveProductsProvider), () => ref.invalidate(liveProductsProvider), (all) {
            final list = all.where((p) => p.name.toLowerCase().contains(_q) || p.barcode.contains(_q)).toList();
            if (list.isEmpty) return const Center(child: Text('No products'));
            return ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final p = list[i];
                final low = p.stockQuantity <= lowStockThreshold;
                return ListTile(
                  title: Text(p.name),
                  subtitle: Text('${p.barcode} · ${money(p.sellingPrice)}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Chip(
                      label: Text('${p.stockQuantity}'),
                      backgroundColor: low ? Theme.of(context).colorScheme.errorContainer : null,
                      avatar: low ? const Icon(Icons.warning_amber, size: 16) : null,
                    ),
                    IconButton(icon: const Icon(Icons.edit_note), tooltip: 'Adjust stock', onPressed: () => _adjust(p)),
                  ]),
                );
              },
            );
          }),
        ),
      ]);

  Future<void> _adjust(Product p) async {
    final qty = TextEditingController();
    final reason = TextEditingController();
    var type = 'restock';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(p.name),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'restock', label: Text('Restock')),
                ButtonSegment(value: 'manual_adjustment', label: Text('Correction')),
              ],
              selected: {type},
              onSelectionChanged: (s) => setS(() => type = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qty,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: InputDecoration(labelText: type == 'restock' ? 'Quantity received' : 'Change (+/−)'),
            ),
            const SizedBox(height: 12),
            TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason (required)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    final delta = int.tryParse(qty.text.trim());
    final why = reason.text.trim();
    qty.dispose();
    reason.dispose();
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (delta == null || delta == 0 || why.isEmpty || (type == 'restock' && delta < 0)) {
      messenger.showSnackBar(const SnackBar(content: Text('Enter a valid quantity and a reason')));
      return;
    }
    try {
      await ref.read(adminRepoProvider).adjustStock(productId: p.id, delta: delta, type: type, reason: why);
      messenger.showSnackBar(const SnackBar(content: Text('Stock updated')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }
}
