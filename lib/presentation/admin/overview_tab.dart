import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../domain/entities/entities.dart';
import '../providers.dart';
import 'admin_home_screen.dart';

class OverviewTab extends ConsumerWidget {
  const OverviewTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(dateRangeProvider);
    final stats = ref.watch(productStatsProvider);
    return asyncBody<List<Sale>>(ref, ref.watch(salesProvider), () => ref.invalidate(salesProvider), (sales) {
      final revenue = sales.fold<double>(0, (s, e) => s + e.total);
      final units = sales.fold<int>(0, (s, e) => s + e.lines.fold(0, (a, l) => a + l.quantity));
      final perDay = range.end.difference(range.start).inHours > 24;

      // Bucket revenue by day (multi-day range) or by hour (single day).
      final buckets = <int, double>{};
      for (final s in sales) {
        final k = perDay ? DateTime(s.createdAt.year, s.createdAt.month, s.createdAt.day).difference(range.start).inDays : s.createdAt.hour;
        buckets[k] = (buckets[k] ?? 0) + s.total;
      }
      final count = perDay ? range.end.difference(range.start).inDays : 24;

      return ListView(padding: const EdgeInsets.all(12), children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          _Kpi('Revenue', money(revenue), Icons.payments),
          _Kpi('Receipts', '${sales.length}', Icons.receipt_long),
          _Kpi('Units sold', '$units', Icons.shopping_bag),
          _Kpi('Avg. receipt', sales.isEmpty ? '—' : money(revenue / sales.length), Icons.functions),
        ]),
        const SizedBox(height: 16),
        Text(perDay ? 'Revenue per day' : 'Revenue per hour', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: sales.isEmpty
              ? const Center(child: Text('No sales in this period'))
              : BarChart(BarChartData(
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: count > 12 ? (count / 6).ceilToDouble() : 1,
                        getTitlesWidget: (v, _) => Text(perDay ? '${range.start.add(Duration(days: v.toInt())).day}' : '${v.toInt()}h', style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < count; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(toY: buckets[i] ?? 0, width: perDay && count > 20 ? 6 : 10, color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(3)),
                      ]),
                  ],
                )),
        ),
        const SizedBox(height: 16),
        Text('Product sales', style: Theme.of(context).textTheme.titleMedium),
        if (stats.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('—')),
        for (final s in stats)
          ListTile(
            dense: true,
            title: Text(s.name),
            subtitle: Text('${s.unitsSold} sold'),
            trailing: Text(money(s.revenue)),
          ),
      ]);
    });
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.icon);
  final String label, value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 170,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 6),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              FittedBox(child: Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
            ]),
          ),
        ),
      );
}
