import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';
import '../providers.dart';
import 'cart_panel.dart';
import 'printer_sheet.dart';
import 'quick_check_card.dart';
import 'scanner_panel.dart';

class CashierScreen extends ConsumerWidget {
  const CashierScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(
          title: Text(Env.storeName),
          actions: [
            if (!kIsWeb) IconButton(tooltip: 'Printer', icon: const Icon(Icons.print), onPressed: () => showPrinterSheet(context)),
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () => ref.read(authRepoProvider).signOut(),
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 720;
            // Scanner + price-check box and the cart live side by side (tablet/landscape)
            // or stacked (phone); either way they are on screen at the same time.
            if (wide) {
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    flex: 4,
                    child: SingleChildScrollView(
                      child: Column(children: [
                        ScannerPanel(height: (c.maxHeight * 0.45).clamp(180, 420)),
                        const SizedBox(height: 8),
                        const QuickCheckCard(),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(flex: 6, child: CartPanel()),
                ]),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(8),
              child: Column(children: [
                const ScannerPanel(height: 140),
                const SizedBox(height: 4),
                const QuickCheckCard(),
                const Expanded(child: CartPanel()),
              ]),
            );
          }),
        ),
      );
}
