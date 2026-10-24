import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../core/config/env.dart';
import '../core/utils/formatters.dart';
import '../domain/entities/entities.dart';
import 'browser_print.dart';
import 'receipt_html.dart';

class PrinterException implements Exception {
  PrinterException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Bluetooth ESC/POS thermal printing (58mm or 80mm).
/// A failed print never affects the already-committed sale; callers should
/// surface the error and offer "Retry".
class PrinterService {
  PaperSize paper = PaperSize.mm58;
  String? connectedMac;

  Future<List<BluetoothInfo>> pairedDevices() async {
    if (!await PrintBluetoothThermal.bluetoothEnabled) {
      throw PrinterException('Bluetooth is turned off');
    }
    return PrintBluetoothThermal.pairedBluetooths;
  }

  Future<bool> get isConnected => PrintBluetoothThermal.connectionStatus;

  Future<void> connect(String mac) async {
    final ok = await PrintBluetoothThermal.connect(macPrinterAddress: mac);
    if (!ok) throw PrinterException('Could not connect to printer');
    connectedMac = mac;
  }

  Future<void> disconnect() async {
    await PrintBluetoothThermal.disconnect;
    connectedMac = null;
  }

  /// Prints [sale]; transparently reconnects once if the link dropped.
  Future<void> printReceipt(Sale sale) async {
    if (kIsWeb) {
      printHtml(buildReceiptHtml(sale));
      return;
    }
    if (!await isConnected) {
      final mac = connectedMac;
      if (mac == null) throw PrinterException('No printer selected');
      await connect(mac);
    }
    final bytes = await buildReceipt(sale);
    final ok = await PrintBluetoothThermal.writeBytes(bytes);
    if (!ok) throw PrinterException('Printer did not accept the data');
  }

  Future<List<int>> buildReceipt(Sale sale) async {
    final profile = await CapabilityProfile.load();
    final g = Generator(paper, profile);
    final w = paper == PaperSize.mm58 ? 32 : 48;
    final b = <int>[];

    b.addAll(g.text(Env.storeName,
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2)));
    b.addAll(g.text(formatDateTime(sale.createdAt), styles: const PosStyles(align: PosAlign.center)));
    b.addAll(g.text('Receipt #${sale.id.substring(0, 8).toUpperCase()}', styles: const PosStyles(align: PosAlign.center)));
    b.addAll(g.hr());

    for (final l in sale.lines) {
      b.addAll(g.text(_ascii(l.name), styles: const PosStyles(bold: true)));
      final left = '${l.quantity} x ${plainMoney(l.unitPrice)}';
      final right = plainMoney(l.total);
      b.addAll(g.text(left + right.padLeft((w - left.length).clamp(right.length, w))));
    }

    b.addAll(g.hr());
    b.addAll(g.row([
      PosColumn(text: 'TOTAL', width: 5, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(
          text: money(sale.total),
          width: 7,
          styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size2)),
    ]));
    b.addAll(g.text('Payment: ${sale.paymentMethod}'));
    b.addAll(g.hr());
    b.addAll(g.text('Thank you for shopping with us!', styles: const PosStyles(align: PosAlign.center)));
    b.addAll(g.feed(2));
    b.addAll(g.cut());
    return b;
  }

  // Most cheap thermal printers have no Arabic code page; replace unprintable glyphs
  // rather than printing garbage. See "Suggestions" for image-rendered receipts.
  String _ascii(String s) => s.runes.map((r) => r < 128 ? String.fromCharCode(r) : '?').join();
}
