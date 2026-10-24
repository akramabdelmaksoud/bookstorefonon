import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../domain/entities/entities.dart';
import '../providers.dart';
import 'admin_home_screen.dart';

class ReceiptsTab extends ConsumerWidget {
  const ReceiptsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      asyncBody<List<Sale>>(ref, ref.watch(salesProvider), () => ref.invalidate(salesProvider), (sales) {
        if (sales.isEmpty) return const Center(child: Text('No receipts in this period'));
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(salesProvider),
          child: ListView.builder(
            itemCount: sales.length,
            itemBuilder: (_, i) {
              final s = sales[i];
              return ExpansionTile(
                leading: Icon(s.paymentMethod == 'cash' ? Icons.payments : Icons.credit_card),
                title: Text(money(s.total)),
                subtitle: Text('${formatDateTime(s.createdAt)} · #${s.id.substring(0, 8)}'),
                children: [
                  for (final l in s.lines)
                    ListTile(dense: true, title: Text(l.name), subtitle: Text('${l.quantity} × ${plainMoney(l.unitPrice)}'), trailing: Text(plainMoney(l.total))),
                ],
              );
            },
          ),
        );
      });
}
