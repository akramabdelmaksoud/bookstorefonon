import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../providers.dart';

enum ScanMode { priceCheck, addToCart }

/// Always-on camera. Default mode is "Price check", which only fills the info
/// card and never touches the cart, so a worker can look up an item mid-sale.
class ScannerPanel extends ConsumerStatefulWidget {
  const ScannerPanel({super.key, this.height = 200});
  final double height;

  @override
  ConsumerState<ScannerPanel> createState() => _ScannerPanelState();
}

class _ScannerPanelState extends ConsumerState<ScannerPanel> with WidgetsBindingObserver {
  final _controller = MobileScannerController(detectionSpeed: DetectionSpeed.normal);
  final _manual = TextEditingController();
  ScanMode _mode = ScanMode.priceCheck;
  String? _lastCode;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.start();
    } else if (state == AppLifecycleState.paused) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _manual.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;
    final now = DateTime.now();
    // The camera sees the same barcode many times a second; swallow repeats.
    if (code == _lastCode && now.difference(_lastAt) < const Duration(seconds: 2)) return;
    _lastCode = code;
    _lastAt = now;
    _handle(code);
  }

  Future<void> _handle(String code) async {
    HapticFeedback.mediumImpact();
    if (_mode == ScanMode.priceCheck) {
      await ref.read(quickCheckProvider.notifier).lookup(code);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      final p = await ref.read(productRepoProvider).findByBarcode(code);
      if (p == null) {
        messenger.showSnackBar(SnackBar(content: Text('Unknown barcode $code')));
        return;
      }
      final ok = ref.read(cartProvider.notifier).add(p);
      messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 1),
        content: Text(ok ? 'Added ${p.name}' : 'Not enough stock for ${p.name}'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Lookup failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        height: widget.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(fit: StackFit.expand, children: [
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Camera unavailable (${error.errorCode.name}).\nUse manual entry below.',
                      textAlign: TextAlign.center),
                ),
              ),
            ),
            Positioned(
              right: 4,
              top: 4,
              child: Row(children: [
                IconButton.filledTonal(
                  tooltip: 'Torch',
                  icon: const Icon(Icons.flashlight_on),
                  onPressed: _controller.toggleTorch,
                ),
                IconButton.filledTonal(
                  tooltip: 'Switch camera',
                  icon: const Icon(Icons.cameraswitch),
                  onPressed: _controller.switchCamera,
                ),
              ]),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      SegmentedButton<ScanMode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: ScanMode.priceCheck, icon: Icon(Icons.search), label: Text('Price check')),
          ButtonSegment(value: ScanMode.addToCart, icon: Icon(Icons.add_shopping_cart), label: Text('Add to cart')),
        ],
        selected: {_mode},
        onSelectionChanged: (s) => setState(() => _mode = s.first),
        style: SegmentedButton.styleFrom(selectedBackgroundColor: scheme.primaryContainer),
      ),
      const SizedBox(height: 8),
      // Also serves USB / Bluetooth "keyboard wedge" scanners and damaged barcodes.
      TextField(
        controller: _manual,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          labelText: 'Type or scan barcode',
          suffixIcon: IconButton(
            icon: const Icon(Icons.keyboard_return),
            onPressed: () => _submitManual(_manual.text),
          ),
        ),
        onSubmitted: _submitManual,
      ),
    ]);
  }

  void _submitManual(String v) {
    final code = v.trim();
    if (code.isEmpty) return;
    _manual.clear();
    _handle(code);
  }
}
