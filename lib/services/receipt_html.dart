import '../core/config/env.dart';
import '../core/utils/formatters.dart';
import '../domain/entities/entities.dart';

String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

/// Receipt as printable HTML sized for 80mm paper (also fine on A4).
String buildReceiptHtml(Sale sale) {
  final rows = sale.lines
      .map((l) => '<tr><td colspan="2"><b>${_esc(l.name)}</b></td></tr>'
          '<tr><td>${l.quantity} x ${plainMoney(l.unitPrice)}</td><td class="r">${plainMoney(l.total)}</td></tr>')
      .join();
  return '''<!doctype html><html dir="auto"><head><meta charset="utf-8"><style>
@page { size: 80mm auto; margin: 4mm; }
body { font-family: monospace; font-size: 12px; width: 72mm; margin: 0; }
h1 { font-size: 18px; text-align: center; margin: 0 0 4px; }
.c { text-align: center; } .r { text-align: right; }
table { width: 100%; border-collapse: collapse; } hr { border: 0; border-top: 1px dashed #000; }
.t { font-size: 15px; font-weight: bold; }
</style></head><body>
<h1>${_esc(Env.storeName)}</h1>
<div class="c">${formatDateTime(sale.createdAt)}<br>Receipt #${sale.id.substring(0, 8).toUpperCase()}</div>
<hr><table>$rows</table><hr>
<table><tr class="t"><td>TOTAL</td><td class="r">${money(sale.total)}</td></tr></table>
<div>Payment: ${_esc(sale.paymentMethod)}</div><hr>
<div class="c">Thank you for shopping with us!</div>
</body></html>''';
}
