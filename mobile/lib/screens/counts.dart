import 'package:flutter/material.dart';

import '../format.dart';
import '../main.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

// ====================================================================
// Cycle counts — port of counts from stock.js.
// ====================================================================

String _countLabel(String s) => switch (s) {
      'open' => 'In progress',
      'review' => 'Awaiting review',
      'done' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => s,
    };

String _countKey(String s) => switch (s) {
      'open' => 'blue',
      'review' => 'amber',
      'done' => 'green',
      'cancelled' => 'red',
      _ => 'navy',
    };

Widget _countChip(String status) =>
    chip(_countKey(status), _countLabel(status));

// ========================= COUNTS LIST =========================
class CountsScreen extends StatelessWidget {
  const CountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = Store.instance;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: const Text('Cycle counts', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: C.navy,
        onPressed: () => go(context, '/counts/new'),
        child: const Icon(Icons.add, color: Colors.white, size: 26),
      ),
      body: ListenableBuilder(
        listenable: Store.instance,
        builder: (context, _) {
          final list = st.countsList();
          final open = list.where((c) => c.status == 'open' || c.status == 'review').length;
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
                          child: const Icon(Icons.rule_rounded, color: C.blueD, size: 19),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('$open count${open == 1 ? '' : 's'} need${open == 1 ? 's' : ''} your attention',
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ),
              if (list.isEmpty)
                emptyState(
                  icon: Icons.rule_outlined,
                  title: 'No counts yet',
                  body: 'Cycle counts keep your on-hand numbers honest. Start one to verify a location.',
                  ctaLabel: 'Start a count',
                  onCta: () => go(context, '/counts/new'),
                )
              else
                for (final c in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SfCard(
                      onTap: () => go(context, '/counts/${c.id}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(st.locationById(c.locationId)?.name ?? 'Location',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                              ),
                              _countChip(c.status),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                              '${c.items.length} items · started ${rel(c.createdAt)}'
                              '${c.completedAt != null ? ' · finished ${rel(c.completedAt!)}' : ''}',
                              style: const TextStyle(fontSize: 12.5, color: C.muted)),
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
}

// ========================= COUNT NEW =========================
class CountNewScreen extends StatefulWidget {
  final String? initLoc;
  const CountNewScreen({super.key, this.initLoc});
  @override
  State<CountNewScreen> createState() => _CountNewScreenState();
}

class _CountNewScreenState extends State<CountNewScreen> {
  late String locId;
  String scope = 'suggested';

  @override
  void initState() {
    super.initState();
    final st = Store.instance;
    final init = widget.initLoc;
    locId = init != null && st.locationById(init) != null
        ? init
        : st.locations().firstOrNull?.id ?? '';
  }

  void _start() {
    final st = Store.instance;
    if (locId.isEmpty) {
      toastErr('Add a location first');
      return;
    }
    final c = st.startCount(locId, scope);
    toastOk('Count started with ${c.items.length} items');
    go(context, '/counts/${c.id}', replace: true);
  }

  @override
  Widget build(BuildContext context) {
    final st = Store.instance;
    final locs = st.locations();
    if (locs.isEmpty) {
      return Scaffold(
        backgroundColor: C.bg,
        appBar: AppBar(
          title: const Text('Start count', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ),
        body: emptyState(
          icon: Icons.location_on_outlined,
          title: 'No locations',
          body: 'Add a location before running a count.',
          ctaLabel: 'Add location',
          onCta: () => go(context, '/locations'),
        ),
      );
    }
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: const Text('Start count', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: FilledButton(
            onPressed: _start,
            child: const Text('Start counting'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Labeled(
            label: 'Location',
            child: SfDropdown(
              value: locId,
              options: [for (final l in locs) (value: l.id, label: l.name)],
              onChanged: (v) => setState(() => locId = v),
            ),
          ),
          const SizedBox(height: 16),
          const Text('SCOPE',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: C.muted)),
          const SizedBox(height: 8),
          SegControl<String>(
            options: [
              (value: 'suggested', label: 'Suggested'),
              (value: 'all', label: 'Full'),
            ],
            current: scope,
            onChanged: (v) => setState(() => scope = v),
          ),
          const SizedBox(height: 12),
          SfCard(
            child: Row(
              children: [
                Icon(scope == 'suggested' ? Icons.auto_awesome_rounded : Icons.tune,
                    size: 18, color: C.blueD),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('How it works',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      SizedBox(height: 3),
                      Text(
                          'Tap each item to set the physical count. Submit when done, then an owner reviews and applies any changes.',
                          style: TextStyle(fontSize: 12.5, color: C.muted, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ========================= COUNT RUN =========================
class CountRunScreen extends StatefulWidget {
  final String countId;
  const CountRunScreen({super.key, required this.countId});
  @override
  State<CountRunScreen> createState() => _CountRunScreenState();
}

class _CountRunScreenState extends State<CountRunScreen> {
  Future<void> _finish() async {
    try {
      Store.instance.finishCountToReview(widget.countId);
      toastOk('Count submitted for review');
      go(context, '/counts/${widget.countId}/review', replace: true);
    } catch (e) {
      toastErr(e.toString());
    }
  }

  Future<void> _cancel() async {
    final ok = await confirmSheet(
      context: context,
      title: 'Cancel this count?',
      body: 'Entered quantities will be discarded.',
      confirmLabel: 'Cancel count',
      danger: true,
      icon: Icons.cancel_outlined,
    );
    if (ok == true) {
      Store.instance.cancelCount(widget.countId);
      toastOk('Count cancelled');
      if (mounted) go(context, '/counts', replace: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = Store.instance;
    final c = st.countById(widget.countId);
    if (c == null || c.status != 'open') {
      return Scaffold(
        appBar: AppBar(title: const Text('Count')),
        body: emptyState(
          icon: Icons.error_outline_rounded,
          title: 'Count not available',
          body: c == null ? 'It may have been removed.' : 'This count was already submitted.',
          ctaLabel: 'Your counts',
          onCta: () => go(context, '/counts', replace: true),
        ),
      );
    }
    final loc = st.locationById(c.locationId);
    final done = c.items.where((x) => x.countedQty != null).length;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: const Text('Count', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.cancel_outlined, color: C.red),
            onPressed: _cancel,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: FilledButton.icon(
            onPressed: _finish,
            icon: const Icon(Icons.rule_rounded, size: 18),
            label: Text('Submit — $done/${c.items.length} counted'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: C.blueBg,
              borderRadius: BorderRadius.circular(R.md),
            ),
            child: Row(
              children: [
                const Icon(Icons.touch_app_rounded, color: C.blueD, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${loc?.name ?? ''} — set the physical count for each item.',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < c.items.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _lineCard(c, c.items[i]),
          ],
        ],
      ),
    );
  }

  Widget _lineCard(CycleCount c, CountLine line) {
    final st = Store.instance;
    final item = st.itemById(line.itemId);
    if (item == null) return const SizedBox.shrink();
    final val = line.countedQty ?? line.systemQty ?? 0;
    return SfCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              thumb(item, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    Text('${item.sku} · system ${num(line.systemQty ?? 0)}',
                        style: const TextStyle(fontSize: 12, color: C.muted)),
                  ],
                ),
              ),
              if (line.countedQty != null) chip('green', 'Counted'),
            ],
          ),
          const SizedBox(height: 10),
          Labeled(
            label: 'Physical count',
            child: StepRow(
              value: val,
              min: 0,
              max: 9999999,
              unit: item.unit,
              onChange: (v) {
                Store.instance.setCountQty(c.id, item.id, v);
                setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ========================= COUNT REVIEW =========================
class CountReviewScreen extends StatefulWidget {
  final String countId;
  const CountReviewScreen({super.key, required this.countId});
  @override
  State<CountReviewScreen> createState() => _CountReviewScreenState();
}

class _CountReviewScreenState extends State<CountReviewScreen> {
  final Set<String> _approved = {};

  int _variance(CountLine l) => (l.countedQty ?? 0) - (l.systemQty ?? 0);

  Widget _delt(int a, int b) {
    final d = a - b;
    if (d == 0) {
      return const Text('0', style: TextStyle(fontSize: 12, color: C.muted));
    }
    return Text(d > 0 ? '+${num(d)}' : num(d).toString(),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: d > 0 ? C.green : C.red));
  }

  void _approve() {
    final st = Store.instance;
    final c = st.countById(widget.countId);
    if (c == null) return;
    final pending = c.items
        .where((x) =>
            x.countedQty != null && _variance(x) != 0)
        .where((x) => !_approved.contains(x.itemId))
        .toList();
    if (pending.isNotEmpty) {
      toastErr('Review every changed item first — ${pending.length} left');
      return;
    }
    try {
      final applied = st.approveCount(widget.countId, _approved.toList());
      toastOk(applied == 0
          ? 'Count completed — nothing to adjust'
          : '$applied adjustment${applied == 1 ? '' : 's'} applied');
      go(context, '/counts/${widget.countId}', replace: true);
    } catch (e) {
      toastErr(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = Store.instance;
    final c = st.countById(widget.countId);
    if (c == null || c.status != 'review') {
      return Scaffold(
        appBar: AppBar(title: const Text('Review')),
        body: emptyState(
          icon: Icons.error_outline_rounded,
          title: 'Nothing to review',
          ctaLabel: 'Your counts',
          onCta: () => go(context, '/counts', replace: true),
        ),
      );
    }
    final changed = c.items.where((x) => x.countedQty != null && _variance(x) != 0).toList();

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: const Text('Review count', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: C.green),
            onPressed: _approve,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Approve & apply changes'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: C.amberBg,
              borderRadius: BorderRadius.circular(R.md),
            ),
            child: Row(
              children: [
                const Icon(Icons.rule_rounded, color: C.amber, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      '${changed.length} item${changed.length == 1 ? '' : 's'} differ from system. Tap to confirm each change — stock updates when you approve.',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < c.items.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _lineCard(context, c, c.items[i]),
          ],
        ],
      ),
    );
  }

  Widget _lineCard(BuildContext context, CycleCount c, CountLine line) {
    final st = Store.instance;
    final item = st.itemById(line.itemId);
    if (item == null) return const SizedBox.shrink();
    final diff = _variance(line);
    final checked = _approved.contains(line.itemId);
    final isChange = line.countedQty != null && diff != 0;
    return SfCard(
      padding: const EdgeInsets.all(12),
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
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text('${num(line.systemQty ?? 0)} → ${num(line.countedQty ?? 0)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                    const SizedBox(width: 8),
                    _delt(line.countedQty ?? 0, line.systemQty ?? 0),
                  ],
                ),
              ],
            ),
          ),
          if (!isChange)
            chip('green', 'No change')
          else
            Checkbox(
              value: checked,
              activeColor: C.green,
              onChanged: (v) => setState(() {
                if (v == true) {
                  _approved.add(line.itemId);
                } else {
                  _approved.remove(line.itemId);
                }
              }),
            ),
        ],
      ),
    );
  }
}

// ========================= COUNT DETAIL =========================
class CountDetailScreen extends StatelessWidget {
  final String countId;
  const CountDetailScreen({super.key, required this.countId});

  @override
  Widget build(BuildContext context) {
    final st = Store.instance;
    final c = st.countById(countId);
    if (c == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Count')),
        body: emptyState(
          icon: Icons.error_outline_rounded,
          title: 'Count not found',
          ctaLabel: 'Your counts',
          onCta: () => go(context, '/counts', replace: true),
        ),
      );
    }
    final loc = st.locationById(c.locationId);
    final counted = c.items.where((x) => x.countedQty != null).length;
    final diffs = c.items
        .where((x) => x.countedQty != null && x.countedQty != x.systemQty)
        .toList()
        .length;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: const Text('Count', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        actions: [
          if (c.status == 'open')
            TextButton(
              onPressed: () => go(context, '/counts/${c.id}/run'),
              child: const Text('Continue'),
            ),
          if (c.status == 'review')
            TextButton(
              onPressed: () => go(context, '/counts/${c.id}/review'),
              child: const Text('Review'),
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
                      width: 46, height: 46,
                      decoration: BoxDecoration(color: C.navyBg, borderRadius: BorderRadius.circular(14)),
                      child: Icon(locIcon(loc?.type ?? 'warehouse'), size: 21, color: C.navy),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(loc?.name ?? 'Location',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                          Text('${c.scope == 'all' ? 'Full' : 'Suggested'} count · started ${rel(c.createdAt)}'
                              ' · by ${c.createdBy ?? '—'}',
                              style: const TextStyle(fontSize: 12.5, color: C.muted)),
                        ],
                      ),
                    ),
                    _countChip(c.status),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _stat(context, '${c.items.length}', 'Items'),
                  _stat(context, '$counted', 'Counted'),
                  _stat(context, '$diffs', 'Changes'),
                ],
              ),
              Section(
                title: 'LINES',
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: SfCard(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Column(
                    children: [
                      for (var i = 0; i < c.items.length; i++) ...[
                        if (i > 0) const Divider(height: 20),
                        _lineRow(context, c.items[i]),
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

  Widget _stat(BuildContext context, String v, String l) {
    return Expanded(
      child: SfCard(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text(l, style: const TextStyle(fontSize: 11.5, color: C.muted)),
          ],
        ),
      ),
    );
  }

  Widget _lineRow(BuildContext context, CountLine line) {
    final st = Store.instance;
    final item = st.itemById(line.itemId);
    if (item == null) return const SizedBox.shrink();
    final diff = (line.countedQty ?? 0) - (line.systemQty ?? 0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          thumb(item, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                Text(line.countedQty == null
                        ? 'Not counted'
                        : '${num(line.systemQty ?? 0)} → ${num(line.countedQty!)}',
                    style: const TextStyle(fontSize: 11.5, color: C.muted)),
              ],
            ),
          ),
          if (line.countedQty == null)
            chip('navy', '—')
          else if (diff == 0)
            chip('green', 'OK')
          else
            chip(diff > 0 ? 'green' : 'red', (diff > 0 ? '+' : '') + num(diff)),
        ],
      ),
    );
  }
}