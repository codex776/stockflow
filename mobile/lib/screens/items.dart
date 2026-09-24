import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../main.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'scan.dart';

// ====================================================================
// Items — port of items.js. Locations/transfer/low-stock live in stock.dart.
// ====================================================================

const _limits = {
  'sku': (n: 100, label: '100 SKUs', what: 'more items'),
  'locations': (n: 1, label: '1 location', what: 'more locations'),
  'team': (n: 2, label: '2 team seats', what: 'more teammates'),
  'reports': (n: 0, label: 'Free reports', what: 'advanced reports'),
};

Future<void> paywallGate(BuildContext context, String kind) async {
  final l = _limits[kind]!;
  final res = await openSheet<bool>(
    context: context,
    title: 'Free plan limit reached',
    subtitle: 'The free plan includes ${l.label}.',
    build: (ctx, set) => SfCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: C.blueBg, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.workspace_premium_outlined, color: C.blueD, size: 19),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Upgrade to Pro', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                Text('Unlimited everything, bulk import, priority support.',
                    style: TextStyle(fontSize: 12, color: C.muted)),
              ],
            ),
          ),
        ],
      ),
    ),
    actions: [
      FilledButton.icon(
        onPressed: () => Navigator.pop(context, true),
        icon: const Icon(Icons.workspace_premium_outlined, size: 18),
        label: const Text('See plans'),
      ),
      OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
    ],
  );
  if (res == true && context.mounted) go(context, '/paywall');
}

// ============================ ITEMS LIST ============================
class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});
  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  String q = '';
  String sort = 'name';
  String status = 'all';
  String? cat;
  bool showArchived = false;
  final searchCtrl = TextEditingController();

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  List<Item> filtered() {
    final st = Store.instance;
    var items = st.orgItems().where(
        (i) => showArchived ? i.status == 'archived' : i.status == 'active').toList();
    final qq = q.trim().toLowerCase();
    if (qq.isNotEmpty) {
      items = items
          .where((i) => [i.name, i.sku, i.barcode, i.category]
              .any((v) => (v).toLowerCase().contains(qq)))
          .toList();
    }
    if (cat != null) items = items.where((i) => i.category == cat).toList();
    if (!showArchived && status != 'all') {
      items = items.where((i) => st.statusOf(i).key == status).toList();
    }
    if (sort == 'name') {
      items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (sort == 'low') {
      items.sort((a, b) => st.totalOn(a.id).compareTo(st.totalOn(b.id)));
    } else {
      items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    return items;
  }

  Future<void> _openFilters() async {
    final cats = Store.instance.categories();
    var tmpCat = cat;
    var tmpSort = sort;
    var tmpArch = showArchived;
    final ok = await openSheet<bool>(
      context: context,
      title: 'Filter & sort',
      build: (ctx, set) => StatefulBuilder(
        builder: (ctx, set2) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('CATEGORY',
                style: TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: C.muted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                _fchip('All categories', tmpCat == null, () { set2(() => tmpCat = null); }),
                for (final c in cats)
                  _fchip(c, tmpCat == c, () { set2(() => tmpCat = c); }),
              ],
            ),
            const SizedBox(height: 18),
            const Text('SORT BY',
                style: TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: C.muted)),
            const SizedBox(height: 8),
            SegControl<String>(
              options: [
                (value: 'name', label: 'Name'),
                (value: 'low', label: 'Stock'),
                (value: 'recent', label: 'Updated'),
              ],
              current: tmpSort,
              onChanged: (v) => set2(() => tmpSort = v),
            ),
            const SizedBox(height: 14),
            SwitchRow(
              label: 'Show archived items',
              checked: tmpArch,
              onChanged: (v) => set2(() => tmpArch = v),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Apply'),
        ),
      ],
    );
    if (ok == true && mounted) {
      setState(() {
        cat = tmpCat;
        sort = tmpSort;
        showArchived = tmpArch;
      });
    }
  }

  Widget _fchip(String label, bool on, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(R.pill),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: on ? C.blue : C.surface,
          borderRadius: BorderRadius.circular(R.pill),
          border: Border.all(color: on ? C.blue : C.line),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                color: on ? Colors.white : C.ink)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = filtered();
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: const Text('Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded, color: C.ink),
            onPressed: _openFilters,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: C.navy,
        onPressed: () => go(context, '/items/new'),
        child: const Icon(Icons.add, color: Colors.white, size: 26),
      ),
      body: ListenableBuilder(
        listenable: Store.instance,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            children: [
              TextField(
                controller: searchCtrl,
                onChanged: (v) => setState(() => q = v),
                decoration: InputDecoration(
                  hintText: 'Search name, SKU or barcode…',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: C.muted),
                  suffixIcon: q.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 17, color: C.muted),
                          onPressed: () => setState(() {
                            q = '';
                            searchCtrl.clear();
                          }),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (v, l) in [
                      ('all', 'All'), ('in', 'In stock'), ('low', 'Low'), ('out', 'Out')
                    ]) ...[
                      _fchip(l, status == v && !showArchived, () => setState(() {
                        status = v;
                        showArchived = false;
                      })),
                      const SizedBox(width: 8),
                    ],
                    _fchip('Filters', false, _openFilters),
                    if (cat != null) ...[
                      const SizedBox(width: 8),
                      _fchip('${cat!} ✕', true, () => setState(() => cat = null)),
                    ],
                    if (showArchived) ...[
                      const SizedBox(width: 8),
                      _fchip('Archived ✕', true, () => setState(() => showArchived = false)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text('${items.length} item${items.length == 1 ? '' : 's'}${showArchived ? ' (archived)' : ''}',
                  style: const TextStyle(fontSize: 11.5, color: C.muted)),
              const SizedBox(height: 4),
              if (items.isEmpty)
                (q.isNotEmpty || cat != null || status != 'all')
                    ? emptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No matches',
                        body: 'Try a different search or clear filters.',
                        ctaLabel: 'Clear all',
                        ctaIcon: Icons.close_rounded,
                        onCta: () => setState(() {
                          q = '';
                          searchCtrl.clear();
                          cat = null;
                          status = 'all';
                          showArchived = false;
                        }),
                      )
                    : showArchived
                        ? emptyState(
                            icon: Icons.inventory_2_outlined,
                            title: 'Nothing archived',
                            body: 'Archived items you may need later will live here.')
                        : emptyState(
                            icon: Icons.inventory_2_outlined,
                            title: 'No items yet',
                            body: 'Add your first product to start tracking stock.',
                            ctaLabel: 'Add item',
                            onCta: () => go(context, '/items/new'),
                          )
              else
                SfCard(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Column(
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0) const Divider(height: 20),
                        _itemRow(context, items[i]),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _itemRow(BuildContext context, Item it) {
    final st = Store.instance.statusOf(it);
    final q = Store.instance.totalOn(it.id);
    return InkWell(
      onTap: () => go(context, '/items/${it.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            thumb(it, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(it.name,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(children: [
                    Text(it.sku,
                        style: const TextStyle(
                            fontSize: 11.5,
                            fontFamily: 'monospace',
                            color: C.navy,
                            backgroundColor: C.navyBg)),
                    const Text(' · ', style: TextStyle(fontSize: 12, color: C.muted)),
                    Text(it.category, style: const TextStyle(fontSize: 12, color: C.muted)),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(num(q), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                Text(it.unit, style: const TextStyle(fontSize: 11, color: C.muted)),
              ],
            ),
            const SizedBox(width: 8),
            chip(st.key == 'in' ? 'in' : st.key, st.label),
            Icon(Icons.chevron_right, color: C.muted.withValues(alpha: 0.6), size: 20),
          ],
        ),
      ),
    );
  }
}

// ============================ ITEM DETAIL ============================
class ItemDetailScreen extends StatelessWidget {
  final String itemId;
  const ItemDetailScreen({super.key, required this.itemId});

  @override
  Widget build(BuildContext context) {
    final st = Store.instance;
    final item = st.itemById(itemId);
    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Item')),
        body: emptyState(
            icon: Icons.error_outline_rounded,
            title: 'Item not found',
            body: 'It may have been removed.',
            ctaLabel: 'Back to items',
            onCta: () => go(context, '/items', replace: true)),
      );
    }
    final mvs = st.itemMovements(item.id, 12);

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: const Text('Item', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        actions: [
          if (item.status == 'active')
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: C.ink),
              onPressed: () => go(context, '/items/${item.id}/edit'),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: item.status == 'active'
              ? Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: C.navy),
                        onPressed: () => go(context, '/items/${item.id}/edit'),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final ok = await confirmSheet(
                            context: context,
                            title: 'Archive this item?',
                            body:
                                '${item.name} will be hidden from lists. Stock history is preserved and you can restore it anytime.',
                            confirmLabel: 'Archive',
                            icon: Icons.archive_outlined,
                          );
if (ok == true) {
                              st.archiveItem(item.id, true);
                              toastOk('Item archived');
                              if (context.mounted) go(context, '/items', replace: true);
                            }
                        },
                        icon: const Icon(Icons.archive_outlined, size: 18),
                        label: const Text('Archive'),
                      ),
                    ),
                  ],
                )
              : FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: C.navy),
                  onPressed: () {
                    st.archiveItem(item.id, false);
                    toastOk('Item restored');
                  },
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text('Restore item'),
                ),
        ),
      ),
      body: ListenableBuilder(
        listenable: Store.instance,
        builder: (context, _) {
          final status2 = Store.instance.statusOf(item);
          final q2 = Store.instance.totalOn(item.id);
          return ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              // hero
              Container(
                color: C.surface,
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    thumb(item, size: 64),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name,
                              style: const TextStyle(
                                  fontSize: 19, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Row(children: [
                            Text(item.sku,
                                style: const TextStyle(
                                    fontSize: 11.5, fontFamily: 'monospace', color: C.navy)),
                            const Text(' · ', style: TextStyle(color: C.muted, fontSize: 12)),
                            Text(item.category, style: const TextStyle(fontSize: 12.5, color: C.muted)),
                          ]),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              chip(status2.key, status2.label),
                              if (item.status == 'archived') chip('arch', 'Archived'),
                              if (item.alertsMuted) chip('mut', 'Alerts muted'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(num(q2),
                            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1)),
                        Text(item.unit, style: const TextStyle(fontSize: 11.5, color: C.muted)),
                      ],
                    ),
                  ],
                ),
              ),

              // low banner
              if ((status2.key == 'low' || status2.key == 'out') &&
                  !item.alertsMuted &&
                  item.status == 'active')
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: C.amberBg,
                      borderRadius: BorderRadius.circular(R.md),
                      border: Border.all(color: C.amberSoft),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: C.amber, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(q2 <= 0 ? 'Out of stock' : 'Below reorder point',
                                  style: const TextStyle(
                                      fontSize: 13.5, fontWeight: FontWeight.w700)),
                              Text('Reorder point is ${num(item.reorderPoint)} ${item.unit}.',
                                  style: const TextStyle(fontSize: 12, color: C.muted)),
                            ],
                          ),
                        ),
                        if (st.can('manageSuppliers'))
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 34),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                foregroundColor: C.amber),
                            onPressed: () {
                              try {
                                final r = st.createPOFromLowStock(item);
                                toastOk(
                                    'Draft PO ${r.po.number} ${r.merged ? 'updated' : 'created'}');
                              } catch (e) {
                                toastErr(e.toString());
                              }
                            },
                            child: const Text('Reorder', style: TextStyle(fontSize: 12.5)),
                          ),
                      ],
                    ),
                  ),
                ),

              // quick actions
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Row(
                  children: [
                    _qa(context, Icons.inbox_rounded, 'Receive',
                        () => receiveSheet(context, item)),
                    _qa(context, Icons.north_east_rounded, 'Issue',
                        () => issueSheet(context, item)),
                    _qa(context, Icons.swap_horiz_rounded, 'Transfer',
                        () => go(context, '/transfer?item=${item.id}')),
                    _qa(context, Icons.assignment_outlined, 'Count',
                        () => countSheet(context, item)),
                  ],
                ),
              ),

              // stock by location
              Section(
                title: 'STOCK BY LOCATION',
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: SfCard(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Column(
                    children: [
                      for (var i = 0; i < st.locations().length; i++) ...[
                        if (i > 0) const Divider(height: 20),
                        _locRow(st, item, st.locations()[i]),
                      ],
                    ],
                  ),
                ),
              ),

              // details
              Section(
                title: 'DETAILS',
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: SfCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    children: [
                      _drow('Barcode', item.barcode.isEmpty ? '—' : item.barcode),
                      _drow('Unit', item.unit),
                      _drow('Reorder point', num(item.reorderPoint)),
                      if (st.can('viewCosts')) _drow('Unit cost', money(item.cost)),
                      if (st.can('viewCosts')) _drow('Sell price', money(item.price)),
                      if (item.supplierId != null)
                        _drow('Preferred supplier',
                            st.supplierById(item.supplierId)?.name ?? '—'),
                      _drow('Last counted',
                          item.lastCountedAt == null ? 'Never' : dMed(item.lastCountedAt!)),
                      _drow('Created', dMed(item.createdAt)),
                    ],
                  ),
                ),
              ),

              // movements
              Section(
                title: 'MOVEMENT HISTORY',
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                trailing: Text('${st.itemMovements(item.id, 1000).length} total',
                    style: const TextStyle(fontSize: 11.5, color: C.muted)),
                child: mvs.isEmpty
                    ? SfCard(
                        child: Text('No movements recorded yet.',
                            style: TextStyle(fontSize: 13, color: C.muted)))
                    : SfCard(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Column(
                          children: [
                            for (var i = 0; i < mvs.length; i++) ...[
                              if (i > 0) const Divider(height: 20),
                              movementRow(mvs[i]),
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

  Widget _locRow(Store st, Item item, Location loc) {
    final lq = st.levelQty(item.id, loc.id);
    final lv = st.level(item.id, loc.id);
    final ls = st.statusOf(item, loc.id);
    return Padding(
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
                Text(loc.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(ls.label == 'In stock' ? 'Updated ${rel(lv?.updatedAt ?? item.updatedAt)}' : ls.label,
                    style: const TextStyle(fontSize: 12, color: C.muted)),
              ],
            ),
          ),
          Text(num(lq),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _drow(String l, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l, style: const TextStyle(fontSize: 13, color: C.muted)),
          Text(v, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _qa(BuildContext context, IconData ic, String label, VoidCallback fn) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(R.md),
        onTap: fn,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: C.surface,
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
}

// ============================ ITEM FORM ============================
class ItemNewScreen extends StatefulWidget {
  final String? initBarcode;
  const ItemNewScreen({super.key, this.initBarcode});
  @override
  State<ItemNewScreen> createState() => _ItemFormState<ItemNewScreen>();
}

class ItemEditScreen extends StatefulWidget {
  final String itemId;
  const ItemEditScreen({super.key, required this.itemId});
  @override
  State<ItemEditScreen> createState() => _ItemFormState<ItemEditScreen>();
}

class _ItemFormState<T extends StatefulWidget> extends State<T> {
  static const _units = ['pcs', 'box', 'pack', 'bag', 'kg', 'g', 'L', 'ml', 'case', 'bottle'];

  final nameCtrl = TextEditingController();
  final skuCtrl = TextEditingController();
  final barcodeCtrl = TextEditingController();
  final rpCtrl = TextEditingController();
  final costCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final newCatCtrl = TextEditingController();
  final Map<String, TextEditingController> openStock = {};
  final List<TextEditingController> _all = [];

  String unit = 'pcs';
  String category = 'General';
  bool newCat = false;
  String supplierId = '';
  bool alertsMuted = false;
  String err = '';

  late bool editing;

  @override
  void initState() {
    super.initState();
    editing = widget is ItemEditScreen;
    final it = editing ? Store.instance.itemById((widget as ItemEditScreen).itemId) : null;
    _track(() => nameCtrl);
    _track(() => skuCtrl);
    _track(() => barcodeCtrl);
    _track(() => rpCtrl);
    _track(() => costCtrl);
    _track(() => priceCtrl);
    _track(() => newCatCtrl);
    if (it != null) {
      category = it.category;
      unit = it.unit;
      supplierId = it.supplierId ?? '';
      alertsMuted = it.alertsMuted;
      nameCtrl.text = it.name;
      skuCtrl.text = it.sku;
      barcodeCtrl.text = it.barcode;
      if (it.reorderPoint > 0) rpCtrl.text = '${it.reorderPoint}';
      if (it.cost > 0) costCtrl.text = '${it.cost}';
      if (it.price > 0) priceCtrl.text = '${it.price}';
    } else if (widget is ItemNewScreen &&
        (widget as ItemNewScreen).initBarcode != null) {
      barcodeCtrl.text = (widget as ItemNewScreen).initBarcode!;
    }
    if (!editing) {
      for (final l in Store.instance.locations()) {
        final c = TextEditingController();
        openStock[l.id] = c;
        _all.add(c);
      }
    }
  }

  void _track(TextEditingController Function() get) {
    final c = get();
    _all.add(c);
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final code = await pickBarcode(context);
    if (code != null && mounted) setState(() => barcodeCtrl.text = code);
  }

  void _generate() {
    final n = nameCtrl.text.trim();
    if (n.isEmpty) {
      toastErr('Enter a name first');
      return;
    }
    skuCtrl.text = genSku(n);
  }

  void save() {
    final st = Store.instance;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => err = 'Item name is required');
      return;
    }
    var cat = category;
    if (newCat) {
      cat = newCatCtrl.text.trim();
      if (cat.isEmpty) {
        setState(() => err = 'Category name is required');
        return;
      }
    }
    try {
      final data = Item()
        ..name = name
        ..sku = skuCtrl.text.trim().isEmpty
            ? genSku(name)
            : skuCtrl.text.trim().toUpperCase()
        ..barcode = barcodeCtrl.text.trim()
        ..category = cat
        ..unit = unit
        ..reorderPoint = int.tryParse(rpCtrl.text.trim()) ?? 0
        ..cost = double.tryParse(costCtrl.text.trim()) ?? 0
        ..price = double.tryParse(priceCtrl.text.trim()) ?? 0
        ..supplierId = supplierId.isEmpty ? null : supplierId
        ..alertsMuted = alertsMuted;
      if (editing) {
        final editId = (widget as ItemEditScreen).itemId;
        st.updateItem(editId, data);
        toastOk('Item updated');
        if (mounted) go(context, '/items/$editId', replace: true);
      } else {
        if (st.checkSKULimit()) {
          paywallGate(context, 'sku');
          return;
        }
        final init = <String, int>{};
        for (final e in openStock.entries) {
          final v = int.tryParse(e.value.text.trim());
          if (v != null && v > 0) init[e.key] = v;
        }
        final it = st.addItem(data, init);
        st.addCategory(cat);
        toastOk('${it.name} created');
        if (mounted) go(context, '/items/${it.id}', replace: true);
      }
    } catch (e) {
      setState(() => err = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = Store.instance;
    final cats = st.categories();
    final sups = st.suppliers();
    final showCosts = !editing || st.can('viewCosts');

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: Text(editing ? 'Edit item' : 'New item',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: FilledButton(
            onPressed: save,
            child: Text(editing ? 'Save changes' : 'Add item'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Labeled(
            label: 'Item name *',
            child: TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'e.g. Oat Milk 1L'),
            ),
          ),
          const SizedBox(height: 14),
          Labeled(
            label: 'SKU',
            hint: 'Auto-generated from the name — tap generate or edit',
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: skuCtrl,
                    style: const TextStyle(fontFamily: 'monospace'),
                    decoration: const InputDecoration(hintText: 'SKU'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _generate,
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                  tooltip: 'Generate SKU',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Labeled(
            label: 'Barcode',
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: barcodeCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontFamily: 'monospace'),
                    decoration: const InputDecoration(hintText: 'Barcode (optional)'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _scanBarcode,
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                  tooltip: 'Scan barcode',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Labeled(
            label: 'Category',
            child: SfDropdown(
              value: newCat || !cats.contains(category) ? '__new' : category,
              options: [
                for (final c in cats) (value: c, label: c),
                (value: '__new', label: '+ New category'),
              ],
              hint: 'Category',
              onChanged: (v) => setState(() {
                newCat = v == '__new';
                if (!newCat) category = v;
              }),
            ),
          ),
          if (newCat) ...[
            const SizedBox(height: 10),
            TextField(
              controller: newCatCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'New category name'),
            ),
          ],
          const SizedBox(height: 14),
          Labeled(
            label: 'Unit',
            child: SfDropdown(
              value: unit,
              options: [for (final u in _units) (value: u, label: u)],
              onChanged: (v) => setState(() => unit = v),
            ),
          ),
          const SizedBox(height: 14),
          Labeled(
            label: 'Reorder point',
            hint: 'Alert me when total stock drops to this',
            child: TextField(
              controller: rpCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(hintText: 'e.g. 20'),
            ),
          ),
          if (showCosts) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Labeled(
                    label: 'Unit cost',
                    child: TextField(
                      controller: costCtrl,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      decoration: const InputDecoration(hintText: '0.00'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Labeled(
                    label: 'Sell price',
                    child: TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      decoration: const InputDecoration(hintText: '0.00'),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Labeled(
            label: 'Preferred supplier',
            hint: 'Used to pre-fill purchase orders',
            child: SfDropdown(
              value: supplierId,
              options: [
                (value: '', label: 'No supplier'),
                for (final s in sups) (value: s.id, label: s.name),
              ],
              onChanged: (v) => setState(() => supplierId = v),
            ),
          ),
          const SizedBox(height: 14),
          SwitchRow(
            label: 'Mute low-stock alerts',
            sub: 'Hide this item from low-stock notifications',
            checked: alertsMuted,
            onChanged: (v) => setState(() => alertsMuted = v),
          ),
          if (!editing && openStock.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text('OPENING STOCK',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: C.muted)),
            const SizedBox(height: 4),
            Text('Set current quantities for each location.',
                style: const TextStyle(fontSize: 12.5, color: C.muted)),
            const SizedBox(height: 10),
            for (final e in openStock.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Labeled(
                  label: Store.instance.locationById(e.key)?.name ?? '',
                  child: TextField(
                    controller: e.value,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(hintText: 'Opening quantity'),
                  ),
                ),
              ),
          ],
          if (err.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(err, style: const TextStyle(fontSize: 13, color: C.red)),
          ],
        ],
      ),
    );
  }
}
