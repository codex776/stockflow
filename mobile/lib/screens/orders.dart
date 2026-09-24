import 'package:flutter/material.dart';

import '../export.dart';
import '../format.dart';
import '../main.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'scan.dart';

// ====================================================================
// Purchase orders — port of orders.js.
// ====================================================================

const _poStatuses = [
  (value: 'draft', label: 'Draft', key: 'navy'),
  (value: 'sent', label: 'Sent', key: 'blue'),
  (value: 'partial', label: 'Partially received', key: 'amber'),
  (value: 'received', label: 'Received', key: 'green'),
  (value: 'cancelled', label: 'Cancelled', key: 'red'),
];

String _poLabel(String s) {
  for (final x in _poStatuses) {
    if (x.value == s) return x.label;
  }
  return s;
}

String _poKey(String s) {
  for (final x in _poStatuses) {
    if (x.value == s) return x.key;
  }
  return 'navy';
}

Widget _poChip(Po po) {
  final s = Store.instance.poStatus(po);
  return chip(_poKey(s), _poLabel(s));
}

// ========================= ORDERS LIST =========================
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String filter = 'open';

  List<Po> _filtered() {
    final all = Store.instance.posList();
    return switch (filter) {
      'open' => all.where((p) => ['draft', 'sent', 'partial'].contains(p.status)).toList(),
      'partial' => all.where((p) => p.status == 'partial').toList(),
      'draft' => all.where((p) => p.status == 'draft').toList(),
      'received' => all.where((p) => p.status == 'received').toList(),
      'all' => all,
      _ => all,
    };
  }

  @override
  Widget build(BuildContext context) {
    final st = Store.instance;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: const Text('Orders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: C.ink),
            onPressed: () => go(context, '/orders/new'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: C.navy,
        onPressed: () => go(context, '/orders/new'),
        child: const Icon(Icons.add, color: Colors.white, size: 26),
      ),
      body: ListenableBuilder(
        listenable: Store.instance,
        builder: (context, _) {
          final open = st.posList().where((p) => ['draft', 'sent', 'partial'].contains(p.status)).length;
          final list = _filtered();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            children: [
              if (open > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SfCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: C.blueBg, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.archive_outlined, color: C.blueD, size: 19),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$open open order${open == 1 ? '' : 's'}',
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                              Text('Tap to continue receiving',
                                  style: const TextStyle(fontSize: 12, color: C.muted)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: C.muted.withValues(alpha: 0.6)),
                      ],
                    ),
                  ),
                ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (v, l) in [
                      ('open', 'Open'), ('partial', 'Partial'), ('draft', 'Drafts'),
                      ('received', 'Received'), ('all', 'All'),
                    ]) ...[
                      fchip(l, filter == v, () => setState(() => filter = v)),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (list.isEmpty)
                emptyState(
                  icon: Icons.shopping_cart_outlined,
                  title: 'No orders here',
                  body: 'Create a purchase order to restock from your suppliers.',
                  ctaLabel: 'New order',
                  onCta: () => go(context, '/orders/new'),
                )
              else
                for (final po in list)
                  _orderCard(context, po),
            ],
          );
        },
      ),
    );
  }

  Widget _orderCard(BuildContext context, Po po) {
    final st = Store.instance;
    final sup = st.supplierById(po.supplierId);
    final totalQty = po.lines.fold<int>(0, (a, l) => a + l.qtyOrdered);
    final got = po.lines.fold<int>(0, (a, l) => a + l.qtyReceived);
    final status = st.poStatus(po);
    final pct = totalQty == 0 ? 0.0 : got / totalQty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SfCard(
        onTap: () => go(context, '/orders/${po.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(po.number,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
                ),
                _poChip(po),
              ],
            ),
            const SizedBox(height: 3),
            Text(
                '${sup?.name ?? 'No supplier'} · expected ${po.expectedDate == null ? '—' : dShort(po.expectedDate!)}',
                style: const TextStyle(fontSize: 12.5, color: C.muted)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: pbar(pct, color: status == 'partial' ? C.amber : C.green)),
                const SizedBox(width: 10),
                Text('$got/$totalQty · ${money0(st.poTotal(po))}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ========================= ORDER NEW / EDIT =========================
class OrderNewScreen extends StatefulWidget {
  final String? initBarcode;
  const OrderNewScreen({super.key, this.initBarcode});
  @override
  State<OrderNewScreen> createState() => _POrderForm<OrderNewScreen>();
}

class OrderEditScreen extends StatefulWidget {
  final String poId;
  const OrderEditScreen({super.key, required this.poId});
  @override
  State<OrderEditScreen> createState() => _POrderForm<OrderEditScreen>();
}

class _POrderForm<T extends StatefulWidget> extends State<T> {
  final List<({Item item, int qty})> lines = [];
  final Map<String, int> _qty = {};

  String supplier = '';
  int? expected;
  String err = '';
  final notesCtrl = TextEditingController();

  late bool editing;

  @override
  void initState() {
    super.initState();
    editing = widget is OrderEditScreen;
    final st = Store.instance;
    if (editing) {
      final po = st.poById((widget as OrderEditScreen).poId);
      if (po != null) {
        supplier = po.supplierId;
        expected = po.expectedDate;
        notesCtrl.text = po.notes;
        for (final l in po.lines) {
          final item = st.itemById(l.itemId);
          if (item != null) {
            lines.add((item: item, qty: l.qtyOrdered));
            _qty[item.id] = l.qtyOrdered;
          }
        }
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final bc = (widget is OrderNewScreen) ? (widget as OrderNewScreen).initBarcode : null;
        if (bc == null || bc.isEmpty || !mounted) return;
        final it = st.findByBarcode(bc);
        if (it != null) {
          setState(() {
            lines.add((item: it, qty: 1));
            _qty[it.id] = 1;
          });
        } else {
          toastErr('No item with barcode $bc');
          go(context, '/items/new?barcode=${Uri.encodeComponent(bc)}');
        }
      });
    }
  }

  @override
  void dispose() {
    notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    final it = await pickItemSheet(context, title: 'Add to order');
    if (it != null && mounted) {
      setState(() {
        if (!_qty.containsKey(it.id)) {
          lines.add((item: it, qty: 1));
          _qty[it.id] = 1;
        }
      });
    }
  }

  void _remove(Item item) {
    setState(() {
      lines.removeWhere((l) => l.item.id == item.id);
      _qty.remove(item.id);
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: expected == null ? now : DateTime.fromMillisecondsSinceEpoch(expected!),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (d != null) setState(() => expected = d.millisecondsSinceEpoch);
  }

  void _save() {
    final st = Store.instance;
    if (supplier.isEmpty) {
      setState(() => err = 'Pick a supplier');
      return;
    }
    if (lines.isEmpty) {
      setState(() => err = 'Add at least one item');
      return;
    }
    try {
      if (editing) {
        final poId = (widget as OrderEditScreen).poId;
        st.updatePOContent(
          poId,
          supplierId: supplier,
          expectedDate: expected,
          notes: notesCtrl.text.trim(),
          lines: [for (final l in lines) (itemId: l.item.id, qty: l.qty, unitCost: null)],
        );
        toastOk('Order updated');
        if (mounted) go(context, '/orders/$poId', replace: true);
      } else {
        final po = st.createPO(
          supplierId: supplier,
          expectedDate: expected,
          notes: notesCtrl.text.trim(),
          lines: [for (final l in lines) (itemId: l.item.id, qty: l.qty, unitCost: null)],
        );
        toastOk('${po.number} created as draft');
        if (mounted) go(context, '/orders/${po.id}', replace: true);
      }
    } catch (e) {
      setState(() => err = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = Store.instance;
    final sups = st.suppliers();
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: Text(editing ? 'Edit order' : 'New order',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: FilledButton(
            onPressed: _save,
            child: Text(editing ? 'Save changes' : 'Create order'),
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: Store.instance,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Labeled(
                label: 'Supplier',
                child: sups.isEmpty
                    ? OutlinedButton.icon(
                        onPressed: () => go(context, '/suppliers/new'),
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                        label: const Text('Add a supplier first'),
                      )
                    : SfDropdown(
                        value: supplier,
                        options: [for (final s in sups) (value: s.id, label: s.name)],
                        hint: 'Select supplier',
                        onChanged: (v) => setState(() {
                          supplier = v;
                          err = '';
                        }),
                      ),
              ),
              const SizedBox(height: 14),
              Labeled(
                label: 'Expected arrival',
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
                  icon: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: Text(expected == null ? 'Pick a date (optional)' : dMed(expected!)),
                ),
              ),
              const SizedBox(height: 14),
              Labeled(
                label: 'Notes',
                child: TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(hintText: 'Notes to supplier (optional)'),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ITEMS',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: C.muted)),
                  TextButton.icon(
                    onPressed: _addItem,
                    style: TextButton.styleFrom(
                        minimumSize: const Size(0, 30),
                        padding: const EdgeInsets.symmetric(horizontal: 8)),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add item'),
                  ),
                ],
              ),
              if (lines.isEmpty)
                SfCard(
                  child: Column(
                    children: [
                      const Text('No items yet.',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Add items you want to order from this supplier.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12.5, color: C.muted)),
                    ],
                  ),
                )
              else
                SfCard(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Column(
                    children: [
                      for (var i = 0; i < lines.length; i++) ...[
                        if (i > 0) const Divider(height: 20),
                        _lineRow(context, lines[i]),
                      ],
                    ],
                  ),
                ),
              if (err.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(err, style: const TextStyle(fontSize: 13, color: C.red)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _lineRow(BuildContext context, ({Item item, int qty}) l) {
    final item = l.item;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          thumb(item, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text('${item.sku} · ${money(item.cost)} each',
                    style: const TextStyle(fontSize: 11.5, color: C.muted)),
              ],
            ),
          ),
          StepRow(
            value: _qty[item.id] ?? 1,
            min: 1,
            max: 99999,
            unit: item.unit,
            onChange: (v) => setState(() {
              _qty[item.id] = v;
              final i = lines.indexWhere((x) => x.item.id == item.id);
              if (i >= 0) lines[i] = (item: item, qty: v);
            }),
          ),
          IconButton(
            iconSize: 17,
            icon: const Icon(Icons.close_rounded, color: C.muted),
            tooltip: 'Remove',
            onPressed: () => _remove(item),
          ),
        ],
      ),
    );
  }
}

// ========================= ORDER DETAIL =========================
class OrderDetailScreen extends StatelessWidget {
  final String poId;
  const OrderDetailScreen({super.key, required this.poId});

  Future<void> _send(BuildContext context, Po po) async {
    final ok = await confirmSheet(
      context: context,
      title: 'Send ${po.number}?',
      body: 'Mark this order as sent to ${Store.instance.supplierById(po.supplierId)?.name ?? 'the supplier'}.',
      confirmLabel: 'Send',
      icon: Icons.outbox_rounded,
    );
    if (ok != true) return;
    try {
      Store.instance.sendPO(po.id);
      toastOk('${po.number} marked sent');
    } catch (e) {
      toastErr(e.toString());
    }
  }

  Future<void> _cancel(BuildContext context, Po po) async {
    final ok = await confirmSheet(
      context: context,
      title: 'Cancel ${po.number}?',
      body: 'This order will be cancelled and can no longer be received.',
      confirmLabel: 'Cancel',
      danger: true,
      icon: Icons.cancel_outlined,
    );
    if (ok != true) return;
    try {
      Store.instance.cancelPO(po.id);
      toastOk('${po.number} cancelled');
    } catch (e) {
      toastErr(e.toString());
    }
  }

  Future<void> _print(BuildContext context, Po po) async {
    final st = Store.instance;
    final sup = st.supplierById(po.supplierId);
    await sharePdf(
      '${po.number} · ${sup?.name ?? 'No supplier'}',
      ['Item', 'Qty ordered', 'Qty received', 'Unit cost', 'Subtotal'],
      [
        for (final l in po.lines)
          [
            st.itemById(l.itemId)?.name ?? '?',
            '${l.qtyOrdered}',
            '${l.qtyReceived}',
            money(l.unitCost),
            money(l.qtyOrdered * l.unitCost),
          ],
      ],
      note: 'Expected: ${po.expectedDate == null ? '—' : dMed(po.expectedDate!)} · Created ${dMed(po.createdAt)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = Store.instance;
    final po = st.poById(poId);
    if (po == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order')),
        body: emptyState(
          icon: Icons.error_outline_rounded,
          title: 'Order not found',
          ctaLabel: 'Back',
          onCta: () => go(context, '/orders', replace: true),
        ),
      );
    }
    final sup = st.supplierById(po.supplierId);
    final status = st.poStatus(po);
    final totalQty = po.lines.fold<int>(0, (a, l) => a + l.qtyOrdered);
    final got = po.lines.fold<int>(0, (a, l) => a + l.qtyReceived);
    final pct = totalQty == 0 ? 0.0 : got / totalQty;
    final value = st.poTotal(po);
    final shippedValue = po.lines.fold<double>(0, (a, l) => a + l.qtyReceived * l.unitCost);

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: Text(po.number,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
        actions: [
          if (status == 'draft')
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: C.ink),
              onPressed: () => go(context, '/orders/${po.id}/edit'),
            ),
          if (['draft', 'sent', 'partial'].contains(status))
            IconButton(
              icon: const Icon(Icons.print_outlined, color: C.ink),
              onPressed: () => _print(context, po),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: _actions(context, po, status),
        ),
      ),
      body: ListenableBuilder(
        listenable: Store.instance,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              // hero
              Container(
                color: C.surface,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(color: C.navyBg, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.storefront_rounded, size: 21, color: C.navy),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sup?.name ?? 'No supplier',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                              Text('Expected ${po.expectedDate == null ? '—' : dMed(po.expectedDate!)}',
                                  style: const TextStyle(fontSize: 12.5, color: C.muted)),
                            ],
                          ),
                        ),
                        _poChip(po),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$got/$totalQty units',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              pbar(pct, color: status == 'partial' ? C.amber : C.green),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(money0(value),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                            Text('${money(shippedValue)} received',
                                style: const TextStyle(fontSize: 11.5, color: C.muted)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Section(
                title: 'LINE ITEMS',
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: SfCard(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Column(
                    children: [
                      for (var i = 0; i < po.lines.length; i++) ...[
                        if (i > 0) const Divider(height: 20),
                        _lineRow(context, po.lines[i]),
                      ],
                    ],
                  ),
                ),
              ),
              _totals(po, value, shippedValue),
              Section(
                title: 'HISTORY',
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: SfCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final e in po.history.reversed)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 8, height: 8,
                                margin: const EdgeInsets.only(top: 5),
                                decoration: BoxDecoration(
                                    color: e.event.startsWith('Created')
                                        ? C.blue
                                        : C.green,
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.event,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    Text('${e.user} · ${dMed(e.ts)}',
                                        style: const TextStyle(fontSize: 11.5, color: C.muted)),
                                  ],
                                ),
                              ),
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
      ),
    );
  }

  Widget _lineRow(BuildContext context, PoLine l) {
    final st = Store.instance;
    final item = st.itemById(l.itemId);
    final done = l.qtyReceived >= l.qtyOrdered;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          thumb(_fallbackItem(item), size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item?.name ?? 'Item removed',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                Text('${num(l.qtyOrdered)} × ${money(l.unitCost)}',
                    style: const TextStyle(fontSize: 11.5, color: C.muted)),
              ],
            ),
          ),
          textChip(done ? num(l.qtyReceived) : '${num(l.qtyReceived)} / ${num(l.qtyOrdered)}', done),
          const SizedBox(width: 6),
          Text(money(l.qtyOrdered * l.unitCost),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Item _fallbackItem(Item? it) {
  if (it != null) return it;
  final f = Item();
  f.name = '?';
  return f;
}

Widget _totals(Po po, double value, double shipped) {
    return Section(
      title: 'TOTALS',
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: SfCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            _trow('Ordered', money(value)),
            _trow('Received', money(shipped)),
            _trow('Outstanding', money(value - shipped)),
          ],
        ),
      ),
    );
  }

  Widget _trow(String l, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l, style: const TextStyle(fontSize: 13, color: C.muted)),
          Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, Po po, String status) {
    if (status == 'draft') {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _cancel(context, po),
              style: OutlinedButton.styleFrom(foregroundColor: C.red),
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _send(context, po),
              icon: const Icon(Icons.outbox_rounded, size: 18),
              label: const Text('Send to supplier'),
            ),
          ),
        ],
      );
    }
    if (status == 'sent' || status == 'partial') {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _cancel(context, po),
              style: OutlinedButton.styleFrom(foregroundColor: C.red),
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: C.green),
              onPressed: () => go(context, '/orders/${po.id}/receive'),
              icon: const Icon(Icons.inbox_rounded, size: 18),
              label: const Text('Receive'),
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

Widget textChip(String text, bool positive) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: positive ? C.greenSoft : C.amberSoft,
      borderRadius: BorderRadius.circular(R.pill),
    ),
    child: Text(text,
        style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: positive ? C.green : C.amber)),
  );
}

// ========================= ORDER RECEIVE =========================
class OrderReceiveScreen extends StatefulWidget {
  final String poId;
  const OrderReceiveScreen({super.key, required this.poId});
  @override
  State<OrderReceiveScreen> createState() => _OrderReceiveScreenState();
}

class _OrderReceiveScreenState extends State<OrderReceiveScreen> {
  final Map<String, int> _qty = {};
  final Map<String, Item> _items = {};
  String locId = '';
  String err = '';
  final notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final st = Store.instance;
    locId = st.locations().firstOrNull?.id ?? '';
    final po = st.poById(widget.poId);
    if (po != null) {
      for (final l in po.lines) {
        final item = st.itemById(l.itemId);
        if (item == null) continue;
        final remaining = l.qtyOrdered - l.qtyReceived;
        _items[item.id] = item;
        if (remaining > 0) _qty[item.id] = remaining;
      }
    }
  }

  @override
  void dispose() {
    notesCtrl.dispose();
    super.dispose();
  }

  void _receive() {
    final st = Store.instance;
    if (locId.isEmpty) {
      setState(() => err = 'Pick a receiving location');
      return;
    }
    final receipts = <({String itemId, int qty})>[];
    for (final e in _qty.entries) {
      if (e.value > 0) receipts.add((itemId: e.key, qty: e.value));
    }
    if (receipts.isEmpty) {
      setState(() => err = 'Enter a quantity for at least one line');
      return;
    }
    try {
      st.receivePO(widget.poId, receipts, locId, notesCtrl.text.trim());
      toastOk('Stock received');
      go(context, '/orders/${widget.poId}', replace: true);
    } catch (e) {
      setState(() => err = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = Store.instance;
    final po = st.poById(widget.poId);
    if (po == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Receive')),
        body: emptyState(
          icon: Icons.error_outline_rounded,
          title: 'Order not found',
          ctaLabel: 'Back',
          onCta: () => go(context, '/orders', replace: true),
        ),
      );
    }
    final locs = st.locations();
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: const Text('Receive stock', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: C.green),
            onPressed: _receive,
            icon: const Icon(Icons.inbox_rounded, size: 18),
            label: Text('Receive into ${locId.isEmpty ? '…' : (st.locationById(locId)?.name ?? '?')}'),
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: Store.instance,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              SfCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(po.number,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
                        const SizedBox(width: 8),
                        _poChip(po),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text('${st.supplierById(po.supplierId)?.name ?? 'No supplier'} — set how much arrived of each line.',
                        style: const TextStyle(fontSize: 12.5, color: C.muted)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Labeled(
                label: 'Receiving location',
                child: SfDropdown(
                  value: locId,
                  options: [for (final l in locs) (value: l.id, label: l.name)],
                  hint: 'Select location',
                  onChanged: (v) => setState(() {
                    locId = v;
                    err = '';
                  }),
                ),
              ),
              const SizedBox(height: 14),
              Labeled(
                label: 'Notes (optional)',
                child: TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(hintText: 'Receipt note'),
                ),
              ),
              const SizedBox(height: 18),
              const Text('LINES',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: C.muted)),
              const SizedBox(height: 10),
              if (_items.isEmpty)
                const SfCard(
                  child: Text('Nothing left to receive.',
                      style: TextStyle(fontSize: 13, color: C.muted)))
              else
                SfCard(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Column(
                    children: [
                      for (final e in _items.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Row(
                            children: [
                              thumb(e.value, size: 36),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.value.name,
                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                                    Text(_remaining(po, e.key),
                                        style: const TextStyle(fontSize: 11.5, color: C.muted)),
                                  ],
                                ),
                              ),
                              StepRow(
                                value: _qty[e.key] ?? 0,
                                min: 0,
                                max: 99999,
                                unit: e.value.unit,
                                onChange: (v) => setState(() => _qty[e.key] = v),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              if (err.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(err, style: const TextStyle(fontSize: 13, color: C.red)),
              ],
            ],
          );
        },
      ),
    );
  }

  String _remaining(Po po, String itemId) {
    for (final l in po.lines) {
      if (l.itemId == itemId) {
        return 'remaining ${num(l.qtyOrdered - l.qtyReceived)} ${_items[itemId]!.unit}';
      }
    }
    return '';
  }
}