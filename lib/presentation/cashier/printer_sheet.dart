import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../providers.dart';

Future<void> showPrinterSheet(BuildContext context) =>
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const _PrinterSheet());

class _PrinterSheet extends ConsumerStatefulWidget {
  const _PrinterSheet();

  @override
  ConsumerState<_PrinterSheet> createState() => _PrinterSheetState();
}

class _PrinterSheetState extends ConsumerState<_PrinterSheet> {
  List<BluetoothInfo>? _devices;
  String? _error;
  String? _connecting;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ref.read(printerProvider).pairedDevices();
      if (mounted) setState(() => _devices = d);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _connect(BluetoothInfo d) async {
    setState(() {
      _connecting = d.macAdress;
      _error = null;
    });
    try {
      await ref.read(printerProvider).connect(d.macAdress);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _connecting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final printer = ref.watch(printerProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Thermal printer', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('Pair the printer in Android/iOS Bluetooth settings first, then pick it here.'),
          const SizedBox(height: 12),
          SegmentedButton<PaperSize>(
            segments: const [
              ButtonSegment(value: PaperSize.mm58, label: Text('58 mm')),
              ButtonSegment(value: PaperSize.mm80, label: Text('80 mm')),
            ],
            selected: {printer.paper},
            onSelectionChanged: (s) => setState(() => printer.paper = s.first),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          const SizedBox(height: 8),
          if (_devices == null && _error == null) const Center(child: CircularProgressIndicator()),
          if (_devices != null && _devices!.isEmpty) const Text('No paired Bluetooth devices found.'),
          if (_devices != null)
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final d in _devices!)
                  ListTile(
                    leading: const Icon(Icons.print),
                    title: Text(d.name),
                    subtitle: Text(d.macAdress),
                    selected: printer.connectedMac == d.macAdress,
                    trailing: _connecting == d.macAdress
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : (printer.connectedMac == d.macAdress ? const Icon(Icons.check_circle) : null),
                    onTap: _connecting == null ? () => _connect(d) : null,
                  ),
              ]),
            ),
        ]),
      ),
    );
  }
}
