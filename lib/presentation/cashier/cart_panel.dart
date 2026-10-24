import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../domain/entities/entities.dart';
import '../providers.dart';
import 'receipt_dialog.dart';

class CartPanel extends ConsumerStatefulWidget {
  const CartPanel({super.key});

  @override
  ConsumerState<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends ConsumerState<CartPanel> {
  String _payment = 'cash';
  bool _busy = false;

  Future<void> _checkout() async {
    final items = ref.read(cartProvider);
    if (items.isEmpty || _busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final sale = await ref.read(salesRepoProvider).completeSale(items, _payment);
      ref.read(cartProvider.notifier).clear();
      if (!mounted) return;
      await showReceiptDialog(context, sale);
    } catch (e) {
      // The RPC is atomic: on failure nothing was sold and the cart is kept intact.
      final msg = e.toString().contains('insufficient stock')
          ? 'Stock changed: one of the items is no longer available in this quantity.'
          : 'Checkout failed. Nothing was charged. ($e)';
      messenger.showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 5)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);
    final text = Theme.of(context).textTheme;

    return Card(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(children: [
            Text('Cart (${items.fold<int>(0, (s, i) => s + i.quantity)})', style: text.titleMedium),
            const Spacer(),
            TextButton.icon(
              onPressed: items.isEmpty ? null : ref.read(cartProvider.notifier).clear,
              icon: const Icon(Icons.delete_sweep),
              label: const Text('Clear'),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('Cart is empty'))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) => _CartRow(item: items[i]),
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Row(children: [
              Text('Total', style: text.titleLarge),
              const Spacer(),
              Text(money(total), style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'cash', icon: Icon(Icons.payments), label: Text('Cash')),
                  ButtonSegment(value: 'card', icon: Icon(Icons.credit_card), label: Text('Card')),
                ],
                selected: {_payment},
                onSelectionChanged: (s) => setState(() => _payment = s.first),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: items.isEmpty || _busy ? null : _checkout,
                  icon: _busy
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_circle),
                  label: const Text('Pay'),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _CartRow extends ConsumerWidget {
  const _CartRow({required this.item});
  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.read(cartProvider.notifier);
    return Dismissible(
      key: ValueKey(item.product.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete),
      ),
      onDismissed: (_) => cart.remove(item.product.id),
      child: ListTile(
        title: Text(item.product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${money(item.product.sellingPrice)} each'),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => cart.setQuantity(item.product.id, item.quantity - 1),
          ),
          Text('${item.quantity}', style: Theme.of(context).textTheme.titleMedium),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              if (!cart.setQuantity(item.product.id, item.quantity + 1)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(duration: const Duration(seconds: 1), content: Text('Only ${item.product.stockQuantity} in stock')),
                );
              }
            },
          ),
          SizedBox(width: 78, child: Text(plainMoney(item.total), textAlign: TextAlign.right)),
        ]),
      ),
    );
  }
}
