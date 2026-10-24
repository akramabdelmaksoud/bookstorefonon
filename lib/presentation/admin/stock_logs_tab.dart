import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../domain/entities/entities.dart';
import '../providers.dart';
import 'admin_home_screen.dart';

class StockLogsTab extends ConsumerWidget {
  const StockLogsTab({super.key});

  static const _icons = {
    'sale': (Icons.arrow_circle_up, Colors.orange),
    'restock': (Icons.arrow_circle_down, Colors.green),
    'manual_adjustment': (Icons.tune, Colors.blueGrey),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      asyncBody<List<StockLog>>(ref, ref.watch(stockLogsProvider), () => ref.invalidate(stockLogsProvider), (logs) {
        if (logs.isEmpty) return const Center(child: Text('No stock movements yet'));
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(stockLogsProvider),
          child: ListView.separated(
            itemCount: logs.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final l = logs[i];
              final (icon, color) = _icons[l.changeType] ?? (Icons.help, Colors.grey);
              final sign = l.quantityChanged > 0 ? '+' : '';
              return ListTile(
                leading: Icon(icon, color: color),
                title: Text(l.productName),
                subtitle: Text('${l.changeType.replaceAll('_', ' ')} · ${l.previousStock} → ${l.newStock}'
                    '${l.reason == null || l.reason!.isEmpty ? '' : '\n${l.reason}'}\n${formatDateTime(l.createdAt)}'),
                isThreeLine: true,
                trailing: Text('$sign${l.quantityChanged}', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color)),
              );
            },
          ),
        );
      });
}
