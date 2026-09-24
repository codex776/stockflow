import 'package:flutter/material.dart';

import '../export.dart';
import '../format.dart';
import '../main.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'items.dart';

// ====================================================================
// Reports — port of reports.js (valuation, lowstock, movements, topmovers).
// ====================================================================

const _reports = [
  (value: 'valuation', label: 'Valuation', pro: false),
  (value: 'lowstock', label: 'Low stock', pro: false),
  (value: 'movements', label: 'Movements', pro: true),
  (value: 'topmovers', label: 'Top movers', pro: true),
];

class ReportsScreen extends StatefulWidget {
  final String? rep;
  final String? days;
  final String? type;
  const ReportsScreen({super.key, this.rep, this.days, this.type});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late String _rep = _reports.any((r) => r.value == widget.rep) ? widget.rep! : 'valuation';
  late String _days = ['7', '30', '90', 'all'].contains(widget.days) ? widget.days! : '30';

  int _ms() => _days == 'all' ? 0 : int.parse(_days) * 24 * 3600 * 1000;

  @override
  Widget build(BuildContext context) {
    final st = Store.instance;
    final locked = _reports.firstWhere((r) => r.value == _rep).pro && !st.isPro();
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: const Text('Reports', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      body: ListenableBuilder(
        listenable: Store.instance,
        builder: (context, _) {
          final body = locked ? _proLock(context) : _content(st, context, locked);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final r in _reports) ...[
                        fchip(
                          r.label + (r.pro ? ' ${st.isPro() ? '' : '· Pro'}' : ''),
                          _rep == r.value,
                          () => setState(() => _rep = r.value),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(child: body),
            ],
          );
        },
      ),
    );
  }

  Widget _content(Store st, BuildContext context, bool locked) {
    final since = _ms();
    final mv = since == 0 ? st.movements(5000) : st.movements(5000).where((m) => m.ts >= DateTime.now().millisecondsSinceEpoch - since).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (_rep != 'valuation' && _rep != 'lowstock')
          Row(
            children: [
              Expanded(
                child: SegControl<String>(
                  options: [
                    (value: '7', label: '7d'),
                    (value: '30', label: '30d'),
                    (value: '90', label: '90d'),
                    (value: 'all', label: 'All'),
                  ],
                  current: _days,
                  onChanged: (v) => setState(() => _days = v),
                ),
              ),
            ],
          ),
        const SizedBox(height: 14),
        switch (_rep) {
          'valuation' => _valuation(st, context),
          'lowstock' => _lowstock(st, context),
          'movements' => _movements(st, context, mv),
          'topmovers' => _topmovers(st, context, mv),
          _ => const SizedBox.shrink(),
        },
      ],
    );
  }

  Widget _toolbar(BuildContext context, {required String label, required List<String> headers, required List<List<String>> rows, String? note}) {
    if (Store.instance.isPro() == false) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                try {
                  await shareCsv('$label.csv', [headers, ...rows]);
                } catch (e) {
                  toastErr('Could not export: $e');
                }
              },
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('CSV'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                try {
                  await sharePdf('$label report', headers, rows, note: note);
                } catch (e) {
                  toastErr('Could not export: $e');
                }
              },
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('PDF'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _valuation(Store st, BuildContext context) {
    final items = st.activeItems().toList()
      ..sort((a, b) => (st.totalOn(b.id) * b.cost).compareTo(st.totalOn(a.id) * a.cost));
    final byLoc = st.valueByLocation();
    final total = st.orgStockValue();
    final headers = ['Item', 'SKU', 'On hand', 'Cost', 'Value'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Total stock value',
                value: money0(total),
                icon: Icons.payments_outlined,
                colorKey: 'green',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                label: 'Items',
                value: '${items.length}',
                icon: Icons.inventory_2_outlined,
                colorKey: 'blue',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text('BY LOCATION',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: C.muted)),
        const SizedBox(height: 8),
        SfCard(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Column(
            children: [
              for (final l in byLoc)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(color: C.navyBg, borderRadius: BorderRadius.circular(10)),
                        child: Icon(locIcon(l.loc.type), size: 16, color: C.navy),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(l.loc.name,
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      ),
                      Text('${num(l.units)} units · ${money0(l.value)}',
                          style: const TextStyle(fontSize: 12.5, color: C.muted)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text('STOCK VALUATION',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: C.muted)),
        const SizedBox(height: 8),
        _toolbar(context,
            label: 'stock-valuation',
            headers: headers,
            rows: [
              for (final i in items)
                [i.name, i.sku, '${st.totalOn(i.id)}', money(i.cost), money(st.totalOn(i.id) * i.cost)],
            ],
            note: 'Total value: ${money0(total)}'),
        SfCard(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(height: 20),
                _itemRow(st, items[i], (st.totalOn(items[i].id) * items[i].cost)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _lowstock(Store st, BuildContext context) {
    final lows = st.lowItems();
    final headers = ['Item', 'SKU', 'On hand', 'Reorder', 'Status'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Items to reorder',
                value: '${lows.length}',
                icon: Icons.warning_amber_rounded,
                colorKey: lows.isEmpty ? 'green' : 'amber',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                label: 'To reorder (est.)',
                value: num(lows.fold<int>(
                    0, (a, x) => a + (x.item.reorderPoint > st.totalOn(x.item.id) ? x.item.reorderPoint - st.totalOn(x.item.id) : 0))),
                icon: Icons.shopping_cart_outlined,
                colorKey: 'navy',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _toolbar(context,
            label: 'low-stock',
            headers: headers,
            rows: [
              for (final x in lows)
                [x.item.name, x.item.sku, '${st.totalOn(x.item.id)}', '${x.item.reorderPoint}', x.st.label],
            ],
            note: 'Recommended reorder qty = 2× reorder point.'),
        if (lows.isEmpty)
          emptyState(
            icon: Icons.verified_rounded,
            title: 'Nothing low',
            body: 'Every item is above its reorder point. Nice.',
          )
        else
          for (final x in lows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RowCard(
                left: thumb(x.item, size: 40),
                title: x.item.name,
                sub: '${num(st.totalOn(x.item.id))} ${x.item.unit} on hand · reorder at ${num(x.item.reorderPoint)}',
                trailing: chip(x.st.key, x.st.label),
                onTap: () => go(context, '/items/${x.item.id}'),
              ),
            ),
      ],
    );
  }

  Widget _movements(Store st, BuildContext context, List<Movement> mv) {
    final headers = ['Date', 'Item', 'Type', 'Location', 'Delta', 'After', 'Reason'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatCard(
          label: 'Movements in period',
          value: '${mv.length}',
          icon: Icons.swap_vert_rounded,
          colorKey: 'blue',
        ),
        const SizedBox(height: 14),
        _toolbar(context,
            label: 'movements',
            headers: headers,
            rows: [
              for (final m in mv)
                [
                  dShort(m.ts),
                  st.itemById(m.itemId)?.name ?? '?',
                  st.mvLabel(m.type),
                  st.locationById(m.locationId)?.name ?? '?',
                  '${m.delta > 0 ? '+' : ''}${m.delta}',
                  '${m.qtyAfter}',
                  m.reason ?? '',
                ],
            ],
            note: 'Period: last ${_days == 'all' ? 'all time' : '$_days days'}'),
        SfCard(
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
      ],
    );
  }

  Widget _topmovers(Store st, BuildContext context, List<Movement> mv) {
    final map = <String, ({Item item, int out, int inn})>{};
    final counters = <String, List<int>>{};
    for (final m in mv) {
      final item = st.itemById(m.itemId);
      if (item == null) continue;
      map[m.itemId] ??= (item: item, out: 0, inn: 0);
      final c = counters.putIfAbsent(m.itemId, () => [0, 0]);
      if (m.delta < 0) c[0] += -m.delta;
      if (m.delta > 0) c[1] += m.delta;
    }
    final rows = map.entries.map((e) {
      final c = counters[e.key]!;
      return (item: e.value.item, out: c[0], inn: c[1]);
    }).toList()
      ..sort((a, b) => (b.out + b.inn).compareTo(a.out + a.inn));
    final top = rows.take(15).toList();
    final headers = ['Item', 'SKU', 'In', 'Out'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatCard(
          label: 'Top movers',
          value: '${top.length}',
          icon: Icons.compare_arrows_rounded,
          colorKey: 'green',
        ),
        const SizedBox(height: 14),
        _toolbar(context,
            label: 'top-movers',
            headers: headers,
            rows: [
              for (final t in top) [t.item.name, t.item.sku, '${t.inn}', '${t.out}'],
            ],
            note: 'Period: last ${_days == 'all' ? 'all time' : '$_days days'}'),
        if (top.isEmpty)
          const SfCard(child: Text('No movements in this period.', style: TextStyle(fontSize: 13, color: C.muted)))
        else
          for (var i = 0; i < top.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RowCard(
                left: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                      color: cycleColor(i).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10)),
                  child: Center(
                    child: Text('${i + 1}',
                        style: TextStyle(fontWeight: FontWeight.w800, color: cycleColor(i))),
                  ),
                ),
                title: top[i].item.name,
                sub: '${num(top[i].inn)} in · ${num(top[i].out)} out (${num(top[i].inn - top[i].out)} net)',
                trailing: chip('blue', num(top[i].inn + top[i].out)),
                onTap: () => go(context, '/items/${top[i].item.id}'),
              ),
            ),
      ],
    );
  }

  Widget _proLock(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [C.navy, C.navy2]),
            borderRadius: BorderRadius.circular(R.lg),
          ),
          child: Row(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.workspace_premium_outlined, color: C.navy, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('A Pro report',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                    Text('Movement & top-mover reports need the Pro plan.',
                        style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => paywallGate(context, 'reports'),
          icon: const Icon(Icons.lock_open_rounded, size: 18),
          label: const Text('See Pro plans'),
        ),
      ],
    );
  }

  Widget _itemRow(Store st, Item item, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          thumb(item, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                Text('${num(st.totalOn(item.id))} ${item.unit} × ${money(item.cost)}',
                    style: const TextStyle(fontSize: 11.5, color: C.muted)),
              ],
            ),
          ),
          Text(money0(value),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}