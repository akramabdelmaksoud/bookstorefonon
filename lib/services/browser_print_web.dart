import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Prints [html] through the browser's print dialog using a hidden iframe,
/// so receipts work on any printer the OS knows (including thermal printers with drivers).
void printHtml(String html) {
  final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
  iframe.style.display = 'none';
  iframe.onload = ((web.Event _) {
    iframe.contentWindow?.print();
    Future.delayed(const Duration(seconds: 30), () => iframe.remove());
  }).toJS;
  iframe.srcdoc = html.toJS;
  web.document.body!.append(iframe);
}
