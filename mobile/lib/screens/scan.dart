import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../main.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

// ====================================================================
// Scanner + shared action sheets — port of scan.js.
// Camera hookup (mobile_scanner) is deferred; manual + simulator used.
// ====================================================================

String scanModeParam = 'lookup';
void setScanMode(String m) => scanModeParam = m;

const _reasons = ['Sale', 'Damaged', 'Internal use', 'Expired', 'Other'];
const _adjustReasons = ['Stock correction', 'Damaged', 'Expired', 'Returned', 'Other'];

List<({String value, String label})> locOpts() {
  return [
    for (final l in Store.instance.locations())
      (value: l.id, label: l.name),
  ];
}

Widget itemHeader(BuildContext context, Item item) {
  final q = Store.instance.totalOn(item.id);
  return SfCard(
    child: Row(
      children: [
        thumb(item, size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('${item.sku} · ${num(q)} ${item.unit} on hand',
                  style: const TextStyle(fontSize: 12.5, color: C.muted)),
            ],
          ),
        ),
      ],
    ),
  );
}

// ========================= ACTION SHEETS =========================

Future<void> receiveSheet(BuildContext context, Item item,
    {int qty = 1, String? locId, String? ref, void Function(int q)? onDone}) async {
  var q = qty;
  var loc = locId ?? Store.instance.locations().firstOrNull?.id ?? '';
  final refCtrl = TextEditingController(text: ref ?? '');
  await openSheet<void>(
    context: context,
    title: 'Receive stock',
    subtitle: item.name,
    build: (ctx, set) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        itemHeader(context, item),
        const SizedBox(height: 12),
        Labeled(
          label: 'Location',
          child: SfDropdown(
            value: loc,
            options: locOpts(),
            hint: 'Select location',
            onChanged: (v) => set(() => loc = v),
          ),
        ),
        const SizedBox(height: 12),
        Labeled(
          label: 'Quantity',
          child: StepRow(value: q, min: 1, max: 99999, unit: item.unit,
              onChange: (v) => set(() => q = v)),
        ),
        const SizedBox(height: 12),
        Labeled(
          label: 'Reference (optional)',
          hint: 'e.g. delivery note #',
          child: TextField(
            controller: refCtrl,
            decoration: const InputDecoration(hintText: 'Reference'),
          ),
        ),
      ],
    ),
    actions: [
      OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: C.green),
        onPressed: () {
          if (loc.isEmpty) {
            toastErr('Pick a location');
            return;
          }
          try {
            Store.instance.quickReceive(item.id, loc, q, refCtrl.text.trim());
            toastOk('+${num(q)} ${item.unit} received');
            Navigator.pop(context);
            onDone?.call(q);
          } catch (e) {
            toastErr(e.toString());
          }
        },
        child: Text('Receive ${num(q)}'),
      ),
    ],
  );
}

Future<void> issueSheet(BuildContext context, Item item,
    {void Function(int q)? onDone}) async {
  final onHand = Store.instance.totalOn(item.id);
  var q = 1;
  var loc = Store.instance.locations().firstOrNull?.id ?? '';
  var reason = _reasons.first;
  final notesCtrl = TextEditingController();
  await openSheet<void>(
    context: context,
    title: 'Issue stock',
    subtitle: item.name,
    build: (ctx, set) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        itemHeader(context, item),
        const SizedBox(height: 12),
        SfCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: C.amber),
              const SizedBox(width: 8),
              Text('$onHand ${item.unit} available',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Labeled(
          label: 'Location',
          child: SfDropdown(
            value: loc,
            options: locOpts(),
            hint: 'Select location',
            onChanged: (v) => set(() => loc = v),
          ),
        ),
        const SizedBox(height: 12),
        Labeled(
          label: 'Quantity',
          child: StepRow(value: q, min: 1, max: onHand > 0 ? onHand : 1, unit: item.unit,
              onChange: (v) => set(() => q = v)),
        ),
        const SizedBox(height: 12),
        Labeled(
          label: 'Reason',
          child: reasonChips(_reasons, reason, (v) => set(() => reason = v)),
        ),
        const SizedBox(height: 12),
        Labeled(
          label: 'Notes (optional)',
          child: TextField(
            controller: notesCtrl,
            decoration: const InputDecoration(hintText: 'Notes'),
          ),
        ),
      ],
    ),
    actions: [
      OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: C.red),
        onPressed: () {
          if (loc.isEmpty) {
            toastErr('Pick a location');
            return;
          }
          if (q > onHand) {
            toastErr('Only $onHand ${item.unit} available');
            return;
          }
          try {
            Store.instance.quickIssue(item.id, loc, q, reason, notesCtrl.text.trim());
            toastOk('-${num(q)} ${item.unit} issued');
            Navigator.pop(context);
            onDone?.call(q);
          } catch (e) {
            toastErr(e.toString());
          }
        },
        child: Text('Issue ${num(q)}'),
      ),
    ],
  );
}

Future<void> adjustSheet(BuildContext context, Item item,
    {void Function(int)? onDone}) async {
  var dir = 1;
  var q = 1;
  var loc = Store.instance.locations().firstOrNull?.id ?? '';
  var reason = _adjustReasons.first;
  final notesCtrl = TextEditingController();
  await openSheet<void>(
    context: context,
    title: 'Adjust stock',
    subtitle: item.name,
    build: (ctx, set) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        itemHeader(context, item),
        const SizedBox(height: 12),
        Labeled(
          label: 'Adjustment',
          child: SegControl<int>(
            options: [(value: 1, label: 'Add quantity'), (value: -1, label: 'Remove quantity')],
            current: dir,
            onChanged: (v) => set(() => dir = v),
          ),
        ),
        const SizedBox(height: 12),
        Labeled(
          label: 'Amount',
          child: StepRow(value: q, min: 1, max: 99999, unit: item.unit,
              onChange: (v) => set(() => q = v)),
        ),
        const SizedBox(height: 12),
        Labeled(
          label: 'Location',
          child: SfDropdown(
            value: loc,
            options: locOpts(),
            hint: 'Select location',
            onChanged: (v) => set(() => loc = v),
          ),
        ),
        const SizedBox(height: 12),
        Labeled(
          label: 'Reason',
          child: reasonChips(_adjustReasons, reason, (v) => set(() => reason = v)),
        ),
        const SizedBox(height: 12),
        Labeled(
          label: 'Notes (optional)',
          child: TextField(
            controller: notesCtrl,
            decoration: const InputDecoration(hintText: 'Notes'),
          ),
        ),
      ],
    ),
    actions: [
      OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(
        onPressed: () {
          if (loc.isEmpty) {
            toastErr('Pick a location');
            return;
          }
          try {
            Store.instance.quickAdjust(item.id, loc, dir * q, reason, notesCtrl.text.trim());
            toastOk('Stock ${dir > 0 ? 'increased' : 'decreased'} by ${num(q)} ${item.unit}');
            Navigator.pop(context);
            onDone?.call(dir * q);
          } catch (e) {
            toastErr(e.toString());
          }
        },
        child: Text('Apply'),
      ),
    ],
  );
}

Future<void> countSheet(BuildContext context, Item item,
    {void Function(int)? onDone}) async {
  var loc = Store.instance.locations().firstOrNull?.id ?? '';
  var val = loc.isEmpty ? 0 : Store.instance.levelQty(item.id, loc);
  await openSheet<void>(
    context: context,
    title: 'Count stock',
    subtitle: item.name,
    build: (ctx, set) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        itemHeader(context, item),
        const SizedBox(height: 12),
        Labeled(
          label: 'Location',
          child: SfDropdown(
            value: loc,
            options: locOpts(),
            hint: 'Select location',
            onChanged: (v) => set(() {
              loc = v;
              val = Store.instance.levelQty(item.id, v);
            }),
          ),
        ),
        const SizedBox(height: 12),
        Labeled(
          label: 'Physical count',
          hint: 'Set to what you actually see on the shelf',
          child: StepRow(value: val, min: 0, max: 9999999, unit: item.unit,
              onChange: (v) => set(() => val = v)),
        ),
      ],
    ),
    actions: [
      OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: C.navy),
        onPressed: () {
          if (loc.isEmpty) {
            toastErr('Pick a location');
            return;
          }
          try {
            Store.instance.quickCount(item.id, loc, val);
            toastOk('Level set to ${num(val)} ${item.unit}');
            Navigator.pop(context);
            onDone?.call(val);
          } catch (e) {
            toastErr(e.toString());
          }
        },
        child: Text('Save count'),
      ),
    ],
  );
}

// ======================= PICKERS (sheets) =======================

Future<String?> pickBarcode(BuildContext context) {
  final ctrl = TextEditingController();
  final known =
      Store.instance.activeItems().where((i) => i.barcode.isNotEmpty).take(8).toList();

  String popWith(String code) {
    ctrl.dispose();
    return code;
  }

  return openSheet<String>(
    context: context,
    title: 'Enter code manually',
    subtitle: 'Type a barcode or tap a demo',
    build: (ctx, set) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(hintText: 'Barcode number'),
          onSubmitted: (v) => Navigator.pop(context, popWith(v)),
        ),
        const SizedBox(height: 14),
        const Text('SIMULATED CODES',
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: C.muted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final i in known)
              InkWell(
                borderRadius: BorderRadius.circular(R.pill),
                onTap: () => Navigator.pop(context, popWith(i.barcode)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: C.navyBg,
                    borderRadius: BorderRadius.circular(R.pill),
                    border: Border.all(color: C.line),
                  ),
                  child: Text(i.name,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
              ),
            InkWell(
              borderRadius: BorderRadius.circular(R.pill),
              onTap: () => Navigator.pop(context, popWith('9990001112223')),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: C.blueBg,
                  borderRadius: BorderRadius.circular(R.pill),
                  border: Border.all(color: C.blueSoft),
                ),
                child: const Text('Demo unknown code',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.blueD)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
      ],
    ),
    actions: [
      FilledButton(
        onPressed: () => Navigator.pop(context, popWith(ctrl.text.trim())),
        child: const Text('Look up'),
      ),
    ],
  );
}

Future<Item?> pickItemSheet(BuildContext context, {String title = 'Pick item'}) {
  final ctrl = TextEditingController();
  return openSheet<Item>(
    context: context,
    title: title,
    build: (ctx, set) {
      final qq = ctrl.text.trim().toLowerCase();
      final st = Store.instance;
      var list = st.activeItems();
      if (qq.isNotEmpty) {
        list = list
            .where((i) =>
                i.name.toLowerCase().contains(qq) ||
                i.sku.toLowerCase().contains(qq) ||
                i.barcode.toLowerCase().contains(qq))
            .toList();
      }
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Search items…'),
            onChanged: (v) => set(() {}),
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                  child: Text('No items match.',
                      style: TextStyle(fontSize: 13, color: C.muted))),
            )
          else
            for (final i in list)
              InkWell(
                borderRadius: BorderRadius.circular(R.sm),
                onTap: () => Navigator.pop(context, i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      thumb(i, size: 36),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(i.name,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            Text('${i.category} · ${num(Store.instance.totalOn(i.id))} ${i.unit}',
                                style: const TextStyle(fontSize: 12, color: C.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      );
    },
  );
}

// ========================= SCAN SCREEN =========================
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  late String mode = scanModeParam == 'receive' ? 'receive' : 'lookup';
  final ctrl = TextEditingController();

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  void onCode(String raw) {
    final code = raw.trim();
    if (code.isEmpty) return;
    final st = Store.instance;
    final item = st.findByBarcode(code) ??
        st.activeItems().where((i) => i.sku == code).firstOrNull;
    if (item == null) {
      _unknown(code);
      return;
    }
    if (mode == 'receive') {
      receiveSheet(context, item, qty: 1);
    } else {
      _found(item);
    }
  }

  void _unknown(String code) {
    openSheet<void>(
      context: context,
      title: 'Not in your catalog',
      subtitle: code,
      build: (ctx, set) => SfCard(
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: C.redBg, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.qr_code_2_rounded, color: C.red, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('No item has this barcode in your catalog yet.',
                  style: const TextStyle(fontSize: 13.5, height: 1.4)),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Scan again')),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            go(context, '/items/new?barcode=${Uri.encodeComponent(code)}');
          },
          child: const Text('Create item'),
        ),
      ],
    );
  }

  void _found(Item item) {
    final q = Store.instance.totalOn(item.id);
    openSheet<void>(
      context: context,
      title: item.name,
      subtitle: '${item.sku} · ${num(q)} ${item.unit} on hand',
      build: (ctx, set) => Column(
        children: [
          Row(
            children: [
              _qa(context, Icons.inbox_rounded, 'Receive',
                  () { Navigator.pop(context); receiveSheet(context, item); }),
              _qa(context, Icons.north_east_rounded, 'Issue',
                  () { Navigator.pop(context); issueSheet(context, item); }),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _qa(context, Icons.swap_horiz_rounded, 'Transfer',
                  () { Navigator.pop(context); go(context, '/transfer?item=${item.id}'); }),
              _qa(context, Icons.assignment_outlined, 'Count',
                  () { Navigator.pop(context); countSheet(context, item); }),
            ],
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            go(context, '/items/${item.id}');
          },
          child: const Text('View item'),
        ),
      ],
    );
  }

  Widget _qa(BuildContext context, IconData ic, String label, VoidCallback fn) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(R.md),
        onTap: fn,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: C.bg,
            borderRadius: BorderRadius.circular(R.md),
            border: Border.all(color: C.line),
          ),
          child: Column(
            children: [
              Icon(ic, size: 20, color: C.navy),
              const SizedBox(height: 5),
              Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: const Text('Scan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      body: ListenableBuilder(
        listenable: Store.instance,
        builder: (context, _) {
          final sims = Store.instance.activeItems().where((i) => i.barcode.isNotEmpty).take(4).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            children: [
              SegControl<String>(
                options: [
                  (value: 'lookup', label: 'Lookup'),
                  (value: 'receive', label: 'Receive'),
                ],
                current: mode,
                onChanged: (v) => setState(() => mode = v),
              ),
              const SizedBox(height: 14),
              // camera area
              Container(
                height: 220,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [C.navy, C.navy2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(R.lg),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white38, width: 2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.qr_code_scanner_rounded,
                            size: 64, color: Colors.white38),
                      ),
                    ),
                    Positioned(
                      left: 0, right: 0, bottom: 22,
                      child: Column(
                        children: [
                          Text(
                            mode == 'receive' ? 'Point at item to add stock' : 'Point at a barcode',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 3),
                          const Text('Camera hookup coming soon — use manual entry',
                              style: TextStyle(color: Colors.white54, fontSize: 11.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onSubmitted: onCode,
                decoration: InputDecoration(
                  hintText: 'Enter barcode manually…',
                  prefixIcon: const Icon(Icons.keyboard_rounded, size: 20, color: C.muted),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20, color: C.blue),
                    onPressed: () => onCode(ctrl.text),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (sims.isNotEmpty) ...[
                const Text('SIMULATE A SCAN',
                    style: TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: C.muted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final i in sims)
                      InkWell(
                        borderRadius: BorderRadius.circular(R.pill),
                        onTap: () => onCode(i.barcode),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: C.navyBg,
                            borderRadius: BorderRadius.circular(R.pill),
                            border: Border.all(color: C.line),
                          ),
                          child: Text(i.name,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    InkWell(
                      borderRadius: BorderRadius.circular(R.pill),
                      onTap: () => onCode('9990001112223'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: C.blueBg,
                          borderRadius: BorderRadius.circular(R.pill),
                          border: Border.all(color: C.blueSoft),
                        ),
                        child: const Text('Demo unknown code',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.blueD)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}