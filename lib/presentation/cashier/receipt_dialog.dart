import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../domain/entities/entities.dart';
import '../providers.dart';

Future<void> showReceiptDialog(BuildContext context, Sale sale) =>
    showDialog(context: context, barrierDismissible: false, builder: (_) => _ReceiptDialog(sale: sale));

class _ReceiptDialog extends ConsumerStatefulWidget {
  const _ReceiptDialog({required this.sale});
  final Sale sale;

  @override
  ConsumerState<_ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends ConsumerState<_ReceiptDialog> {
  bool _printing = false;
  String? _error;
  bool _printed = false;

  @override
  void initState() {
    super.initState();
    // Auto-print only when a printer was already chosen this session.
    if (!kIsWeb && ref.read(printerProvider).connectedMac != null) _print();
  }

  Future<void> _print() async {
    setState(() {
      _printing = true;
      _error = null;
    });
    try {
      await ref.read(printerProvider).printReceipt(widget.sale);
      if (mounted) setState(() => _printed = true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Print failed: $e');
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sale;
    return AlertDialog(
      title: const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8), Text('Sale completed')]),
      content: SizedBox(
        width: 360,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(formatDateTime(s.createdAt)),
          const Divider(),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              for (final l in s.lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Expanded(child: Text('${l.quantity} × ${l.name}')),
                    Text(plainMoney(l.total)),
                  ]),
                ),
            ]),
          ),
          const Divider(),
          Row(children: [
            const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(money(s.total), style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          if (_printed) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Receipt printed')),
        ]),
      ),
      actions: [
        TextButton.icon(
          onPressed: _printing ? null : _print,
          icon: _printing ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.print),
          label: Text(_error != null ? 'Retry print' : 'Print'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
          onPressed: () => Navigator.pop(context),
          child: const Text('New sale'),
        ),
      ],
    );
  }
}
