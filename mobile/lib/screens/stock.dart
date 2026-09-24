import 'package:flutter/material.dart';

import '../format.dart';
import '../main.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'items.dart';
import 'scan.dart';

// ====================================================================
// Stock, locations, transfer, low stock — port of stock.js.
// ====================================================================

const _locTypes = [
  (value: 'warehouse', label: 'Warehouse', icon: Icons.warehouse_rounded),
  (value: 'store', label: 'Storefront', icon: Icons.storefront_rounded),
  (value: 'vehicle', label: 'Vehicle', icon: Icons.local_shipping_rounded),
  (value: 'virtual', label: 'Virtual / cloud', icon: Icons.cloud_outlined),
];

String _locLabel(String type) {
  for (final t in _locTypes) {
    if (t.value == type) return t.label;
  }
  return type;
}

// ========================= STOCK TAB =========================
class StockScreen extends StatelessWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: const Text('Stock', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      body: ListenableBuilder(
        listenable: Store.instance,
        builder: (context, _) {
          final st = Store.instance;
          final units = st.activeItems().fold<int>(0, (a, i) => a + st.totalOn(i.id));
          final value = st.orgStockValue();
          final lows = st.lowItems().length;
          final locs = st.valueByLocation();
          final mv = st.movements(6);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Units on hand',
                      value: num(units),
                      icon: Icons.inventory_2_outlined,
                      colorKey: 'blue',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      label: 'Stock value',
                      value: money0(value),
                      icon: Icons.payments_outlined,
                      colorKey: 'green',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Low stock',
                      value: '$lows',
                      icon: Icons.warning_amber_rounded,
                      colorKey: lows > 0 ? 'amber' : 'green',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      label: 'Locations',
                      value: '${locs.length}',
                      icon: Icons.location_on_outlined,
                      colorKey: 'navy',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text('QUICK ACTIONS',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: C.muted)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _qa(context, Icons.swap_horiz_rounded, 'Transfer', () => go(context, '/transfer')),
                  _qa(context, Icons.assignment_outlined, 'Count', () => go(context, '/counts/new')),
                  _qa(context, Icons.warning_amber_rounded, 'Low stock', () => go(context, '/lowstock')),
                  _qa(context, Icons.location_on_outlined, 'Locations', () => go(context, '/locations')),
                ],
              ),
              const SizedBox(height: 18),
              Section(
                title: 'LOCATIONS',
                trailing: TextButton(
                  onPressed: () => go(context, '/locations'),
                  style: TextButton.styleFrom(minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 6)),
                  child: const Text('View all'),
                ),
                padding: EdgeInsets.zero,
                child: locs.isEmpty
                    ? const SfCard(
                        child: Text('No locations yet. Add one from Locations.',
                            style: TextStyle(fontSize: 13, color: C.muted)))
                    : SfCard(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Column(
                          children: [
                            for (var i = 0; i < locs.length; i++) ...[
                              if (i > 0) const Divider(height: 20),
                              _locRow(context, locs[i].loc, locs[i].units, locs[i].value),
                            ],
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 18),
              Section(
                title: 'RECENT MOVEMENTS',
                padding: EdgeInsets.zero,
                child: mv.isEmpty
                    ? const SfCard(
                        child: Text('No movements recorded yet.',
                            style: TextStyle(fontSize: 13, color: C.muted)))
                    : SfCard(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Column(
                          children: [
                            for (var i = 0; i < mv.length; i++) ...[
                              if (i > 0) const Divider(height: 20),
                              movementRow(mv[i], showItem: true),
                            ],
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

  Widget _qa(BuildContext context, IconData ic, String label, VoidCallback fn) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(R.md),
        onTap: fn,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: C.surface,
            borderRadius: BorderRadius.circular(R.md),
            border: Border.all(color: C.line),
          ),
          child: Column(
            children: [
              Icon(ic, size: 20, color: C.navy),
              const SizedBox(height: 5),
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _locRow(BuildContext context, Location loc, int units, double value) {
    return InkWell(
      onTap: () => go(context, '/locations/${loc.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: C.navyBg, borderRadius: BorderRadius.circular(11)),
              child: Icon(locIcon(loc.type), size: 17, color: C.navy),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loc.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(_locLabel(loc.type), style: const TextStyle(fontSize: 12, color: C.muted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(num(units), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text(money0(value), style: const TextStyle(fontSize: 11.5, color: C.muted)),
              ],
            ),
            Icon(Icons.chevron_right, color: C.muted.withValues(alpha: 0.6), size: 20),
          ],
        ),
      ),
    );
  }
}

// ========================= LOCATIONS =========================
class LocationsScreen extends StatelessWidget {
  const LocationsScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final st = Store.instance;
    if (st.locations().isNotEmpty && !st.isPro()) {
      await paywallGate(context, 'locations');
      return;
    }
    var type = 'warehouse';
    final nameCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    String err = '';
    final ok = await openSheet<bool>(
      context: context,
      title: 'New location',
      build: (ctx, set) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Labeled(
            label: 'Location name *',
            child: TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(hintText: 'e.g. East Warehouse'),
            ),
          ),
          const SizedBox(height: 14),
          Labeled(
            label: 'Type',
            child: SfDropdown(
              value: type,
              options: [for (final t in _locTypes) (value: t.value, label: t.label)],
              onChanged: (v) => set(() => type = v),
            ),
          ),
          const SizedBox(height: 14),
          Labeled(
            label: 'Address (optional)',
            child: TextField(
              controller: addrCtrl,
              decoration: const InputDecoration(hintText: 'Street, city'),
            ),
          ),
          if (err.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(err, style: const TextStyle(fontSize: 13, color: C.red)),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final n = nameCtrl.text.trim();
                    if (n.isEmpty) {
                      set(() => err = 'Location name is required');
                      return;
                    }
                    try {
                      st.addLocation(n, type, addrCtrl.text.trim());
                      toastOk('Location created');
                      Navigator.pop(ctx, true);
                    } catch (e) {
                      set(() => err = isLimitError(e)
                          ? 'Free plan is limited to 1 location. Upgrade to add more.'
                          : e.toString());
                    }
                  },
                  child: const Text('Create'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    for (final c in [nameCtrl, addrCtrl]) {
      c.dispose();
    }
    if (ok == true && context.mounted) go(context, '/locations');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: const Text('Locations', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: C.ink),
            onPressed: () => _add(context),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Store.instance,
        builder: (context, _) {
          final st = Store.instance;
          final locs = st.valueByLocation();
          final value = st.orgStockValue();
          final units = st.activeItems().fold<int>(0, (a, i) => a + st.totalOn(i.id));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Locations',
                      value: '${locs.length}',
                      icon: Icons.location_on_outlined,
                      colorKey: 'navy',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      label: 'Total value',
                      value: money0(value),
                      icon: Icons.payments_outlined,
                      colorKey: 'green',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      label: 'Units',
                      value: num(units),
                      icon: Icons.inventory_2_outlined,
                      colorKey: 'blue',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (locs.isEmpty)
                emptyState(
                  icon: Icons.location_on_outlined,
                  title: 'No locations yet',
                  body: 'Locations are where your stock lives — warehouse, storefront, vehicle or virtual.',
                  ctaLabel: 'Add location',
                  onCta: () => _add(context),
                )
              else
                for (final l in locs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: RowCard(
                      left: Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(color: C.navyBg, borderRadius: BorderRadius.circular(12)),
                        child: Icon(locIcon(l.loc.type), size: 19, color: C.navy),
                      ),
                      title: l.loc.name,
                      sub: '${_locLabel(l.loc.type)} · ${num(l.units)} units · ${money0(l.value)}',
                      trailing: chip(l.units > 0 ? 'in' : 'blue', num(l.units)),
                      onTap: () => go(context, '/locations/${l.loc.id}'),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

// ========================= LOCATION DETAIL =========================
class LocationDetailScreen extends StatelessWidget {
  final String locationId;
  const LocationDetailScreen({super.key, required this.locationId});

  Future<void> _edit(BuildContext context, Location loc) async {
    final nameCtrl = TextEditingController(text: loc.name);
    final addrCtrl = TextEditingController(text: loc.address);
    var type = loc.type;
    await openSheet<bool>(
      context: context,
      title: 'Edit location',
      build: (ctx, set) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Labeled(
            label: 'Location name',
            child: TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Name')),
          ),
          const SizedBox(height: 14),
          Labeled(
            label: 'Type',
            child: SfDropdown(
              value: type,
              options: [for (final t in _locTypes) (value: t.value, label: t.label)],
              onChanged: (v) => set(() => type = v),
            ),
          ),
          const SizedBox(height: 14),
          Labeled(
            label: 'Address',
            child: TextField(controller: addrCtrl, decoration: const InputDecoration(hintText: 'Address')),
          ),
        ],
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            Store.instance.updateLocation(loc, name: nameCtrl.text, type: type, address: addrCtrl.text);
            toastOk('Location updated');
            Navigator.pop(context, true);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _archive(BuildContext context, Location loc) async {
    final ok = await confirmSheet(
      context: context,
      title: 'Archive this location?',
      body: '${loc.name} will be hidden. Locations with stock on hand cannot be archived.',
      confirmLabel: 'Archive',
      icon: Icons.archive_outlined,
    );
    if (ok == true) {
      try {
        Store.instance.archiveLocation(loc.id);
        toastOk('Location archived');
        if (context.mounted) go(context, '/locations', replace: true);
      } catch (e) {
        toastErr(e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = Store.instance;
    final loc = st.locationById(locationId);
    if (loc == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Location')),
        body: emptyState(
          icon: Icons.error_outline_rounded,
          title: 'Location not found',
          ctaLabel: 'Back',
          onCta: () => go(context, '/locations', replace: true),
        ),
      );
    }
    final units = st.activeItems().fold<int>(0, (a, i) => a + st.levelQty(i.id, loc.id));
    final value = st.valueAtLocation(loc.id);
    final stock = st.activeItems()
        .where((i) => st.levelQty(i.id, loc.id) > 0)
        .toList()
      ..sort((a, b) => st.levelQty(b.id, loc.id).compareTo(st.levelQty(a.id, loc.id)));
    final mv = st.movements(1000).where((m) => m.locationId == loc.id).take(12).toList();

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: const Text('Location', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: C.ink),
            onPressed: () => _edit(context, loc),
          ),
          IconButton(
            icon: const Icon(Icons.archive_outlined, color: C.ink),
            onPressed: () => _archive(context, loc),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Store.instance,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Container(
                color: C.surface,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(color: C.navyBg, borderRadius: BorderRadius.circular(15)),
                      child: Icon(locIcon(loc.type), size: 24, color: C.navy),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(loc.name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text('${_locLabel(loc.type)}'
                              '${loc.address.isNotEmpty ? ' · ${loc.address}' : ''}',
                              style: const TextStyle(fontSize: 12.5, color: C.muted)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(money0(value),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        Text('${num(units)} units',
                            style: const TextStyle(fontSize: 12, color: C.muted)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _qa(context, Icons.assignment_outlined, 'Start count',
                      () => go(context, '/counts/new?loc=${loc.id}')),
                  _qa(context, Icons.swap_horiz_rounded, 'Transfer from',
                      () => go(context, '/transfer?from=${loc.id}')),
                  _qa(context, Icons.inbox_rounded, 'Receive',
                      () => go(context, '/scan?mode=receive')),
                ],
              ),
              Section(
                title: 'STOCK HERE (${stock.length})',
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: stock.isEmpty
                    ? const SfCard(
                        child: Text('No stock at this location.',
                            style: TextStyle(fontSize: 13, color: C.muted)))
                    : SfCard(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Column(
                          children: [
                            for (var i = 0; i < stock.length; i++) ...[
                              if (i > 0) const Divider(height: 20),
                              _stockRow(context, st, stock[i], loc),
                            ],
                          ],
                        ),
                      ),
              ),
              Section(
                title: 'RECENT MOVEMENTS',
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: mv.isEmpty
                    ? const SfCard(
                        child: Text('No movements yet.',
                            style: TextStyle(fontSize: 13, color: C.muted)))
                    : SfCard(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Column(
                          children: [
                            for (var i = 0; i < mv.length; i++) ...[
                              if (i > 0) const Divider(height: 20),
                              movementRow(mv[i], showItem: true),
                            ],
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

  Widget _qa(BuildContext context, IconData ic, String label, VoidCallback fn) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(R.md),
        onTap: fn,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: C.surface,
            borderRadius: BorderRadius.circular(R.md),
            border: Border.all(color: C.line),
          ),
          child: Column(
            children: [
              Icon(ic, size: 20, color: C.navy),
              const SizedBox(height: 5),
              Text(label,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stockRow(BuildContext context, Store st, Item item, Location loc) {
    final q = st.levelQty(item.id, loc.id);
    final status = st.statusOf(item, loc.id);
    return InkWell(
      onTap: () => go(context, '/items/${item.id}'),
      child: Padding(
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
                  Text(item.sku,
                      style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', color: C.muted)),
                ],
              ),
            ),
            Text(num(q),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            chip(status.key, status.label),
          ],
        ),
      ),
    );
  }
}

// ========================= TRANSFER =========================
class TransferScreen extends StatefulWidget {
  final String? itemId;
  final String? fromId;
  const TransferScreen({super.key, this.itemId, this.fromId});
  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  Item? item;
  String from = '';
  String to = '';
  int qty = 1;
  String err = '';
  final notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final st = Store.instance;
    final iid = widget.itemId;
    if (iid != null) item = st.itemById(iid);
    final locs = st.locations();
    final fid = widget.fromId;
    if (fid != null && st.locationById(fid) != null) {
      from = fid;
    } else if (item != null) {
      from = locs.where((l) => st.levelQty(item!.id, l.id) > 0).firstOrNull?.id ?? '';
    }
    to = locs.where((l) => l.id != from).firstOrNull?.id ?? '';
  }

  @override
  void dispose() {
    notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final it = await pickItemSheet(context, title: 'Transfer item');
    if (it != null && mounted) {
      setState(() {
        item = it;
        err = '';
      });
    }
  }

  void _doTransfer() {
    final st = Store.instance;
    if (item == null) {
      setState(() => err = 'Pick an item to transfer');
      return;
    }
    if (from.isEmpty || to.isEmpty) {
      setState(() => err = 'Need two locations to transfer between');
      return;
    }
    if (from == to) {
      setState(() => err = 'From and to must be different');
      return;
    }
    final avail = st.levelQty(item!.id, from);
    if (qty <= 0 || qty > avail) {
      setState(() => err = 'Only $avail ${item!.unit} available at origin');
      return;
    }
    try {
      st.transferStock(item!.id, from, to, qty, notesCtrl.text.trim());
      toastOk('${num(qty)} ${item!.unit} transferred');
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => err = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = Store.instance;
    final locs = st.locations();
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: const Text('Transfer stock', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: FilledButton(onPressed: _doTransfer, child: const Text('Transfer')),
        ),
      ),
      body: ListenableBuilder(
        listenable: Store.instance,
        builder: (context, _) {
          final avail = item != null && from.isNotEmpty ? st.levelQty(item!.id, from) : 0;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Labeled(
                label: 'Item',
                child: item == null
                    ? OutlinedButton.icon(
                        onPressed: _pick,
                        icon: const Icon(Icons.search_rounded, size: 18),
                        label: const Text('Pick an item'),
                      )
                    : SfCard(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: InkWell(
                          onTap: _pick,
                          child: Row(
                            children: [
                              thumb(item!, size: 40),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item!.name,
                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                                    Text('${item!.sku} · ${num(st.totalOn(item!.id))} ${item!.unit} total',
                                        style: const TextStyle(fontSize: 12, color: C.muted)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.tune, size: 18, color: C.muted),
                            ],
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 14),
              Labeled(
                label: 'From',
                child: SfDropdown(
                  value: from,
                  options: [for (final l in locs) (value: l.id, label: l.name)],
                  hint: 'Origin location',
                  onChanged: (v) => setState(() {
                    from = v;
                    if (to == v) {
                      to = locs.where((l) => l.id != v).firstOrNull?.id ?? '';
                    }
                    err = '';
                  }),
                ),
              ),
              if (item != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('$avail ${item!.unit} available here',
                      style: const TextStyle(fontSize: 12, color: C.muted)),
                ),
              const SizedBox(height: 14),
              Labeled(
                label: 'To',
                child: SfDropdown(
                  value: to,
                  options: [for (final l in locs) (value: l.id, label: l.name)],
                  hint: 'Destination location',
                  onChanged: (v) => setState(() {
                    to = v;
                    err = '';
                  }),
                ),
              ),
              const SizedBox(height: 14),
              Labeled(
                label: 'Quantity',
                child: StepRow(
                  value: qty,
                  min: 1,
                  max: item == null ? 9999 : (avail > 0 ? avail : 1),
                  unit: item?.unit,
                  onChange: (v) => setState(() {
                    qty = v;
                    err = '';
                  }),
                ),
              ),
              const SizedBox(height: 14),
              Labeled(
                label: 'Notes (optional)',
                child: TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(hintText: 'e.g. restock storefront'),
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
}

// ========================= LOW STOCK =========================
class LowStockScreen extends StatefulWidget {
  const LowStockScreen({super.key});
  @override
  State<LowStockScreen> createState() => _LowStockScreenState();
}

class _LowStockScreenState extends State<LowStockScreen> {
  Future<void> _reorder(Item item) async {
    try {
      final r = Store.instance.createPOFromLowStock(item);
      toastOk('Draft PO ${r.po.number} ${r.merged ? 'updated' : 'created'}');
      go(context, '/orders/${r.po.id}');
    } catch (e) {
      toastErr(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = Store.instance;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: const Text('Low stock', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      body: ListenableBuilder(
        listenable: Store.instance,
        builder: (context, _) {
          final lows = st.lowItems();
          final txt = lows.isEmpty
              ? 'All items are above their reorder points.'
              : '${lows.length} item${lows.length == 1 ? '' : 's'} below its reorder point.';
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: lows.isEmpty ? C.greenBg : C.amberBg,
                  borderRadius: BorderRadius.circular(R.md),
                ),
                child: Row(
                  children: [
                    Icon(lows.isEmpty ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                        size: 18, color: lows.isEmpty ? C.green : C.amber),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(txt,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (lows.isEmpty)
                emptyState(
                  icon: Icons.verified_rounded,
                  title: 'All stocked up',
                  body: 'You’ll see items here as soon as they drop below their reorder point.',
                )
              else
                _cardList(context, lows),
            ],
          );
        },
      ),
    );
  }

  Widget _cardList(BuildContext context, List<({Item item, ({String key, String label}) st})> lows) {
    return Column(
      children: [
        for (final x in lows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SfCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(R.sm),
                    onTap: () =>
                        go(context, '/items/${x.item.id}'),
                    child: Row(
                      children: [
                        thumb(x.item, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(x.item.name,
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                              Text('${x.item.sku} · reorder point ${num(x.item.reorderPoint)} ${x.item.unit}',
                                  style: const TextStyle(fontSize: 11.5, color: C.muted)),
                            ],
                          ),
                        ),
                        chip(x.st.key, x.st.label),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _bar(x.item, Store.instance.totalOn(x.item.id)),
                      ),
                      const SizedBox(width: 8),
                      if (Store.instance.can('manageSuppliers'))
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 34),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              foregroundColor: C.amber),
                          onPressed: () => _reorder(x.item),
                          child: const Text('Reorder', style: TextStyle(fontSize: 12.5)),
                        ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 17,
                        icon: const Icon(Icons.notifications_off_outlined, color: C.muted),
                        tooltip: 'Mute alerts',
                        onPressed: () {
                          Store.instance.muteItem(x.item.id, true);
                          toastOk('Alerts muted for ${x.item.name}');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _bar(Item item, int q) {
    final rp = item.reorderPoint > 0 ? item.reorderPoint : 1;
    final pct = q / (rp * 2).clamp(1, 1000000);
    final p = pct > 1 ? 1.0 : pct;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${num(q)} on hand',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            Text('needs ${num(item.reorderPoint)}',
                style: const TextStyle(fontSize: 11.5, color: C.muted)),
          ],
        ),
        const SizedBox(height: 4),
        pbar(p, color: q <= 0 ? C.red : C.amber),
      ],
    );
  }
}