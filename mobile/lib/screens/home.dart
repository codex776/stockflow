import 'package:flutter/material.dart';

import '../charts.dart';
import '../format.dart';
import '../main.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

// ====================================================================
// Dashboard + notifications — port of src/screens/home.js.
// ====================================================================

String _greeting() {
  final hour = DateTime.now().hour;
  return hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final u = Store.instance.currentUser();
    final org = Store.instance.currentOrg();
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: ListenableBuilder(
          listenable: Store.instance,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_greeting()}, ${(u?.name ?? '').split(' ').first}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(org?.name ?? '', overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: C.muted)),
            ],
          ),
        ),
        actions: [
          ListenableBuilder(
            listenable: Store.instance,
            builder: (context, _) {
              final unread = Store.instance.unreadCount();
              return IconButton(
                icon: Badge(
                  isLabelVisible: unread > 0,
                  backgroundColor: C.red,
                  label: Text('${unread > 99 ? '99+' : unread}',
                      style: const TextStyle(fontSize: 10)),
                  child: const Icon(Icons.notifications_none_rounded, color: C.ink),
                ),
                onPressed: () => go(context, '/notifications'),
              );
            },
          ),
        ],
      ),
      body: const _HomeBody(),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    final st = Store.instance;
    final items = st.activeItems();
    final units = items.fold<int>(0, (a, i) => a + st.totalOn(i.id));
    final value = st.orgStockValue();
    final low = st.lowItems();
    final seeCosts = st.can('viewCosts');
    final orgId = st.state.session.orgId;
    final pending = st.outboxPending();
    final online = st.state.ui.online;
    final mv = st.movements(6);

    // 14-day movement volume
    final days = <AreaPoint>[];
    for (var i = 13; i >= 0; i--) {
      final d0 = DateTime.now().subtract(Duration(days: i));
      final start = DateTime(d0.year, d0.month, d0.day).millisecondsSinceEpoch;
      final end = start + dayMs;
      var v = 0.0;
      for (final m in st.state.movements) {
        if (m.orgId == orgId && m.ts >= start && m.ts < end && m.type != 'count') {
          v += m.delta.abs();
        }
      }
      days.add(AreaPoint('${d0.day}/${d0.month}', v));
    }

    return RefreshIndicator(
      onRefresh: () async => st.syncNow(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          // --- KPI grid ---
          Row(
            children: [
              Expanded(
                  child: StatCard(
                label: 'Active SKUs',
                value: num(items.length),
                colorKey: 'navy',
                icon: Icons.inventory_2_outlined,
              )),
              const SizedBox(width: 10),
              Expanded(
                  child: StatCard(
                label: 'Units on hand',
                value: num(units),
                colorKey: 'blue',
                icon: Icons.layers_outlined,
              )),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: StatCard(
                label: seeCosts ? 'Stock value' : 'Locations',
                value: seeCosts ? money0(value) : num(st.locations().length),
                colorKey: 'green',
                icon: seeCosts ? Icons.payments_outlined : Icons.place_outlined,
              )),
              const SizedBox(width: 10),
              Expanded(
                  child: StatCard(
                label: 'Low-stock alerts',
                value: num(low.length),
                colorKey: low.isEmpty ? 'navy' : 'amber',
                icon: Icons.warning_amber_rounded,
              )),
            ],
          ),

          // --- sync card ---
          if (pending > 0) ...[
            const SizedBox(height: 14),
            SfCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                        color: C.amberBg, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.cloud_off_rounded, color: C.amber, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$pending change${pending > 1 ? 's' : ''} pending sync',
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                        Text(online ? 'Ready to upload.' : 'Will send automatically when back online.',
                            style: const TextStyle(fontSize: 12, color: C.muted)),
                      ],
                    ),
                  ),
                  if (online)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          foregroundColor: C.amber),
                      onPressed: () async {
                        toast('Syncing…');
                        await st.syncNow();
                      },
                      child: const Text('Sync now', style: TextStyle(fontSize: 13)),
                    ),
                ],
              ),
            ),
          ],

          // --- quick actions ---
          const SizedBox(height: 22),
          const Text('Quick actions',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: C.muted)),
          const SizedBox(height: 10),
          Row(children: [
            _qa(context, Icons.qr_code_scanner_rounded, 'Scan', '/scan', true),
            _qa(context, Icons.inbox_rounded, 'Receive', '/scan?mode=receive', false),
            _qa(context, Icons.assignment_outlined, 'Count', '/counts/new', false),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _qa(context, Icons.swap_horiz_rounded, 'Transfer', '/transfer', false),
            _qa(context, Icons.add_box_outlined, 'New item', '/items/new', false),
            _qa(context, Icons.receipt_long_outlined, 'New PO', '/orders/new', false),
          ]),

          // --- needs attention ---
          const SizedBox(height: 22),
          if (low.isNotEmpty)
            SfCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 17, color: C.amber),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text('Needs attention (${low.length})',
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800))),
                      TextButton(
                        onPressed: () => go(context, '/lowstock'),
                        child: const Text('View all', style: TextStyle(fontSize: 12.5)),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  for (final x in low.take(4))
                    _lowRow(st, x.item, x.st.label),
                ],
              ),
            )
          else
            SfCard(
              child: Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                        color: C.greenBg, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.check_circle_rounded, color: C.green, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('All stock levels healthy',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                        Text('No items below reorder point right now.',
                            style: TextStyle(fontSize: 12, color: C.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // --- movement chart ---
          const SizedBox(height: 22),
          SfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Movement volume',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                    const Text('Last 14 days', style: TextStyle(fontSize: 11, color: C.muted)),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(height: 150, child: AreaChart(days, color: C.navy2)),
              ],
            ),
          ),

          // --- recent activity ---
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent activity',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: C.muted)),
              TextButton(
                onPressed: () => go(context, '/reports?r=movements'),
                child: const Text('See all', style: TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
          if (mv.isEmpty)
            emptyState(
              icon: Icons.history_rounded,
              title: 'No activity yet',
              body: 'Receive your first stock to start the movement log.',
            )
          else
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
      ),
    );
  }

  Widget _qa(BuildContext context, IconData ic, String label, String path, bool featured) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(R.md),
        onTap: () => go(context, path),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: C.surface,
            borderRadius: BorderRadius.circular(R.md),
            border: Border.all(color: C.line),
          ),
          child: Column(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: featured ? C.navy : C.navyBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(ic, size: 20, color: featured ? Colors.white : C.navy),
              ),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lowRow(Store st, Item item, String label) {
    final q = st.totalOn(item.id);
    return Row(
      children: [
        thumb(item, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              Text('${item.sku} · reorder at ${num(item.reorderPoint)} ${item.unit}',
                  style: const TextStyle(fontSize: 12, color: C.muted)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(q <= 0 ? 'OUT' : '${num(q)} left',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: q <= 0 ? C.red : C.amber)),
            if (st.can('manageSuppliers'))
              TextButton(
                style: TextButton.styleFrom(
                    minimumSize: const Size(0, 30),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: C.green,
                    backgroundColor: C.greenBg),
                onPressed: () {
                  try {
                    final r = st.createPOFromLowStock(item);
                    toast('Draft PO ${r.po.number} ${r.merged ? 'updated' : 'created'}');
                  } catch (e) {
                    toastErr(e.toString());
                  }
                },
                child: const Text('Reorder', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ],
    );
  }
}

// ====================================================================
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = Store.instance;
    final list = st.notifsList();
    final unread = st.unreadCount();
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: const Text('Notifications',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () {
                st.notifReadAll();
                toast('All notifications marked as read');
              },
              child: const Text('Mark all as read', style: TextStyle(fontSize: 12.5)),
            ),
        ],
      ),
      body: list.isEmpty
          ? emptyState(
              icon: Icons.notifications_none_rounded,
              title: 'All quiet for now',
              body: 'Low-stock alerts, PO updates and team activity will land here.')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                _notifGroup(st, 'Today',
                    list.where((n) => DateTime.now().millisecondsSinceEpoch - n.ts < dayMs).toList(),
                    context),
                _notifGroup(st, 'Earlier',
                    list.where((n) => DateTime.now().millisecondsSinceEpoch - n.ts >= dayMs).toList(),
                    context),
              ],
            ),
    );
  }

  Widget _notifGroup(Store st, String label, List<AppNotif> items, BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: C.muted)),
        ),
        SfCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(height: 20),
                _notifRow(st, items[i], context),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _notifRow(Store st, AppNotif n, BuildContext context) {
    final (bg, fg, ic) = switch (n.type) {
      'lowStock' => (C.amberBg, C.amber, Icons.warning_amber_rounded),
      'poUpdates' => (C.blueBg, C.blueD, Icons.receipt_long_outlined),
      'invites' => (C.greenBg, C.green, Icons.person_add_alt_1_rounded),
      'counts' => (C.navyBg, C.navy, Icons.assignment_outlined),
      'conflicts' => (C.redBg, C.red, Icons.error_outline_rounded),
      _ => (C.navyBg, C.navy, Icons.info_outline_rounded),
    };
    return InkWell(
      onTap: () {
        st.notifRead(n.id);
        if (n.link.isNotEmpty) go(context, n.link);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: n.read ? Colors.transparent : C.blueBg,
          borderRadius: BorderRadius.circular(R.sm),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
              child: Icon(ic, size: 17, color: fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(n.title,
                              style: const TextStyle(
                                  fontSize: 13.5, fontWeight: FontWeight.w700))),
                      if (!n.read)
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                              color: C.blue, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(n.body,
                      style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.35)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(rel(n.ts),
                style: const TextStyle(fontSize: 11, color: C.muted)),
          ],
        ),
      ),
    );
  }
}