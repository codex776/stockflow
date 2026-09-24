import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'format.dart';
import 'store.dart';
import 'theme.dart';

// ====================================================================
// Shared UI kit — port of src/ui.js. All screens build on these.
// ====================================================================

// ---------- money / copy ----------
Future<void> copyText(String t, [String msg = 'Copied to clipboard']) async {
  await Clipboard.setData(ClipboardData(text: t));
  toastOk(msg);
}

void toastOk(String msg) => toast(msg, ok: true);
void toastErr(String msg) => toast(msg, ok: false);

void toast(String msg, {bool ok = true}) {
  final ctx = _rootContext;
  if (ctx == null) return;
  ScaffoldMessenger.of(ctx)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.error_rounded,
            color: ok ? C.green : C.red,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: const TextStyle(color: Colors.white))),
        ],
      ),
    ));
}

BuildContext? _rootContext;
void setToastContext(BuildContext ctx) => _rootContext = ctx;

// ---------- avatar ----------
const _avColors = <Color>[
  C.blue,
  C.green,
  Color(0xFF7C3AED),
  Color(0xFF0891B2),
  C.amber,
  C.red,
];

Color avColor(String? color) {
  final map = {
    'av-a': _avColors[0],
    'av-b': _avColors[1],
    'av-c': _avColors[2],
    'av-d': _avColors[3],
    'av-e': _avColors[4],
    'av-f': _avColors[5],
  };
  return map[color] ?? _avColors[0];
}

Widget avatar(String name, {String color = 'av-a', double size = 40}) {
  final initials = name.trim().isEmpty
      ? '?'
      : name.trim().split(RegExp(r'\s+')).take(2).map((s) => s[0].toUpperCase()).join();
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: avColor(color).withValues(alpha: 0.14),
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: Text(initials,
        style: TextStyle(
            color: avColor(color),
            fontSize: size * 0.38,
            fontWeight: FontWeight.w700)),
  );
}

Widget thumb(Item item, {double size = 44}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: C.blueBg,
      borderRadius: BorderRadius.circular(R.sm),
    ),
    alignment: Alignment.center,
    child: Icon(item.image == null ? Icons.inventory_2_outlined : Icons.image,
        size: size * 0.5, color: C.navy2),
  );
}

IconData locIcon(String type, {double size = 18}) {
  final ic = switch (type) {
    'store' => Icons.storefront_outlined,
    'vehicle' => Icons.local_shipping_outlined,
    'kiosk' => Icons.store_outlined,
    'warehouse' => Icons.warehouse_outlined,
    _ => Icons.place_outlined,
  };
  return ic;
}

// ---------- chips / flags ----------
Color stChipColor(String key) => switch (key) {
      'in' || 'received' || 'active' || 'approved' || 'done' || 'owner' => C.green,
      'low' || 'draft' || 'pending' || 'review' || 'sent' || 'invited' || 'manager' => C.amber,
      'out' || 'cancelled' || 'overdue' => C.red,
      _ => C.blue,
    };

Widget chip(String key, String label) {
  final c = stChipColor(key);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: chipBg(key),
      borderRadius: BorderRadius.circular(R.pill),
      border: Border.all(color: c.withValues(alpha: 0.18), width: 1),
    ),
    child: Text(label,
        style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: c,
            fontFamily: 'monospace')),
  );
}

Widget pendFlag() {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: const [
      Icon(Icons.schedule, size: 14, color: C.amber),
      SizedBox(width: 3),
      Text('Pending',
          style: TextStyle(fontSize: 12, color: C.amber, fontWeight: FontWeight.w600)),
    ],
  );
}

Widget qtyChip(int q, String unit) {
  final zero = q <= 0;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: zero ? C.redSoft : C.greenSoft,
      borderRadius: BorderRadius.circular(R.pill),
    ),
    child: Text('${num(q)} ${unit.toLowerCase()}',
        style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: zero ? C.red : C.green)),
  );
}

// ---------- status rows / stepper ----------
class StepRow extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChange;
  final String? unit;
  const StepRow({
    super.key,
    required this.value,
    this.min = 0,
    this.max = 999999,
    required this.onChange,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final decOn = value > min;
    final incOn = value < max;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepBtn(Icons.remove, decOn, () {
          if (decOn) onChange(value - 1);
        }),
        Container(
          width: 96,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: C.bg,
            borderRadius: BorderRadius.circular(R.sm),
            border: Border.all(color: C.line),
          ),
          alignment: Alignment.center,
          child: Text('${num(value)}${unit != null && unit!.isNotEmpty ? ' $unit' : ''}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ),
        _stepBtn(Icons.add, incOn, () {
          if (incOn) onChange(value + 1);
        }),
      ],
    );
  }

  Widget _stepBtn(IconData ic, bool on, VoidCallback cb) {
    return InkWell(
      onTap: on ? cb : null,
      borderRadius: BorderRadius.circular(R.sm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: on ? C.blue : C.bg,
          border: Border.all(color: on ? C.blue : C.line),
          borderRadius: BorderRadius.circular(R.sm),
        ),
        child: Icon(ic, color: on ? Colors.white : C.muted, size: 19),
      ),
    );
  }
}

class SegControl<T> extends StatelessWidget {
  final List<({T value, String label})> options;
  final T current;
  final ValueChanged<T> onChanged;
  const SegControl({super.key, required this.options, required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: C.bg,
        borderRadius: BorderRadius.circular(R.sm),
        border: Border.all(color: C.line),
      ),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(R.sm - 1),
                onTap: () => onChanged(o.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: o.value == current ? C.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(R.sm - 1),
                    boxShadow: o.value == current
                        ? [BoxShadow(color: C.line, blurRadius: 3, offset: const Offset(0, 1))]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(o.label,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              o.value == current ? FontWeight.w700 : FontWeight.w500,
                          color: o.value == current ? C.ink : C.muted)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Widget reasonChips(List<String> list, String current, ValueChanged<String> onPick) {
  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final r in list)
        InkWell(
          borderRadius: BorderRadius.circular(R.pill),
          onTap: () => onPick(r),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: r == current ? C.blue : C.bg,
              borderRadius: BorderRadius.circular(R.pill),
              border: Border.all(color: r == current ? C.blue : C.line),
            ),
            child: Text(r,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: r == current ? Colors.white : C.ink)),
          ),
        ),
    ],
  );
}

class SwitchRow extends StatelessWidget {
  final String label;
  final String? sub;
  final bool checked;
  final ValueChanged<bool>? onChanged;
  final bool disabled;
  const SwitchRow({
    super.key,
    required this.label,
    this.sub,
    required this.checked,
    this.onChanged,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              if (sub != null)
                const SizedBox(height: 2),
              if (sub != null)
                Text(sub!,
                    style: const TextStyle(fontSize: 12.5, color: C.muted)),
            ],
          ),
        ),
        Switch(
          value: checked,
          onChanged: disabled ? null : onChanged,
          activeTrackColor: C.green,
          activeThumbColor: Colors.white,
        ),
      ],
    );
  }
}

// ---------- layout: section, stat card, card ----------
class Section extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;
  const Section({super.key, required this.title, this.trailing, required this.child, this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 0)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: C.muted)),
                  ?trailing,
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class SfCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final EdgeInsets? margin;
  const SfCard({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.onTap, this.margin});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: C.line),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(R.md),
      child: card,
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final String colorKey;
  final IconData? icon;
  const StatCard({super.key, required this.label, required this.value, this.sub, this.colorKey = 'navy', this.icon});

  @override
  Widget build(BuildContext context) {
    final c = amp(colorKey);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: C.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(R.sm),
                  ),
                  child: Icon(icon, size: 15, color: c),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(label,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.muted)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: C.ink)),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub!,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: C.muted)),
          ],
        ],
      ),
    );
  }
}

class RowCard extends StatelessWidget {
  final Widget left;
  final String title;
  final String? sub;
  final Widget? trailing;
  final VoidCallback? onTap;
  const RowCard({super.key, required this.left, required this.title, this.sub, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SfCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          left,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                if (sub != null) ...[
                  const SizedBox(height: 3),
                  Text(sub!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: C.muted)),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: C.muted.withValues(alpha: 0.6)),
        ],
      ),
    );
  }
}

Widget emptyState({
  required IconData icon,
  required String title,
  String? body,
  String? ctaLabel,
  VoidCallback? onCta,
  IconData? ctaIcon,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: C.blueBg,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(icon, size: 34, color: C.blueD),
        ),
        const SizedBox(height: 16),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        if (body != null) ...[
          const SizedBox(height: 6),
          Text(body,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: C.muted, height: 1.4)),
        ],
        if (ctaLabel != null) ...[
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onCta,
            icon: Icon(ctaIcon ?? Icons.add, size: 18),
            label: Text(ctaLabel),
          ),
        ],
      ],
    ),
  );
}

Widget skeletonBox([double w = double.infinity, double h = 16]) {
  return Container(
    width: w,
    height: h,
    decoration: BoxDecoration(color: const Color(0xFFE9EEF4), borderRadius: BorderRadius.circular(R.sm)),
  );
}

Column skeletonRows({int n = 5, double h = 52}) {
  return Column(
    children: [
      for (var i = 0; i < n; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: skeletonBox(double.infinity, h),
        ),
    ],
  );
}

// ---------- sheet / confirm ----------
Future<T?> openSheet<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  required Widget Function(BuildContext, StateSetter) build,
  List<Widget>? actions,
  bool wide = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: C.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(R.lg)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: C.muted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Text(subtitle,
                    style: const TextStyle(fontSize: 13, color: C.muted)),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                child: build(ctx, setState),
              ),
            ),
            if (actions != null && actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
                child: Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(child: actions[i]),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

Future<bool?> confirmSheet({
  required BuildContext context,
  required String title,
  required String body,
  String confirmLabel = 'Confirm',
  bool danger = false,
  IconData? icon,
}) {
  return openSheet<bool>(
    context: context,
    title: title,
    build: (ctx, set) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: (danger ? C.red : C.blue).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: danger ? C.red : C.blue),
          ),
          const SizedBox(height: 12),
        ],
        Text(body, style: const TextStyle(fontSize: 14, color: C.ink, height: 1.45)),
      ],
    ),
    actions: [
      OutlinedButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: danger ? C.red : C.blue),
        onPressed: () => Navigator.pop(context, true),
        child: Text(confirmLabel),
      ),
    ],
  );
}

// ---------- form field wrapper ----------
class Labeled extends StatelessWidget {
  final String label;
  final Widget child;
  final String? error;
  final String? hint;
  const Labeled({super.key, required this.label, required this.child, this.error, this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        child,
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(error!,
              style: const TextStyle(fontSize: 12, color: C.red)),
        ] else if (hint != null) ...[
          const SizedBox(height: 4),
          Text(hint!, style: const TextStyle(fontSize: 12, color: C.muted)),
        ],
      ],
    );
  }
}

// ---------- screen scaffold ----------
Widget sfBackground(Widget child) => DecoratedBox(
      decoration: const BoxDecoration(color: C.bg),
      child: child,
    );

// Lightweight run-of-app "sheet" page (full screen, slides up)
class SheetPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;
  const SheetPage({super.key, required this.title, this.subtitle, required this.child, this.actions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, color: C.muted),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ],
        ),
        titleTextStyle: const TextStyle(color: C.ink, fontSize: 17, fontWeight: FontWeight.w800),
      ),
      bottomNavigationBar: (() {
        final acts = actions;
        if (acts == null) return null;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
            child: Row(
              children: [
                for (var i = 0; i < acts.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: acts[i]),
                ],
              ],
            ),
          ),
        );
      })(),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: subtitle != null ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subtitle!, style: const TextStyle(fontSize: 13, color: C.muted)),
              const SizedBox(height: 12),
              child,
            ],
          ) : child,
        ),
      ),
    );
  }
}

// ---------- movement row (port of ui.movementRow) ----------
IconData _mvIcon(String t) => switch (t) {
      'receive' => Icons.inbox_rounded,
      'issue' => Icons.arrow_upward_rounded,
      'adjust' => Icons.tune_rounded,
      'transfer_out' || 'transfer_in' => Icons.swap_horiz_rounded,
      'count' => Icons.assignment_outlined,
      'return' => Icons.replay_rounded,
      'waste' => Icons.delete_outline_rounded,
      _ => Icons.history_rounded,
    };

({Color bg, Color fg}) _mvTints(String t) {
  if (t == 'count') return (bg: C.blueBg, fg: C.blueD);
  if (t == 'waste') return (bg: C.redBg, fg: C.red);
  return (bg: C.greenBg, fg: C.green);
}

Widget movementRow(Movement m, {bool showItem = false, bool showCard = false}) {
  final item = Store.instance.itemById(m.itemId);
  final loc = Store.instance.locationById(m.locationId);
  final tints = _mvTints(m.type);
  final positive = m.delta > 0;
  if (showCard) {
    return SfCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: _mvRow(m, item, loc, tints, positive, showItem),
    );
  }
  return _mvRow(m, item, loc, tints, positive, showItem);
}

Widget _mvRow(Movement m, Item? item, Location? loc, ({Color bg, Color fg}) tints, bool positive, bool showItem) {
  return Row(
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: tints.bg, borderRadius: BorderRadius.circular(12)),
        child: Icon(_mvIcon(m.type), size: 17, color: tints.fg),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${Store.instance.mvLabel(m.type)}${showItem && item != null ? ' · ${item.name}' : ''}',
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Row(
              children: [
                Flexible(child: Text('${m.user ?? ''} · ${loc?.name ?? '?'}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: C.muted))),
                if (m.reason != null && m.reason!.isNotEmpty) ...[
                  const Text('  ·  ', style: TextStyle(fontSize: 12, color: C.muted)),
                  Flexible(child: Text(m.reason!, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: C.muted))),
                ],
              ],
            ),
            if (m.notes != null && m.notes!.isNotEmpty) ...[
              const SizedBox(height: 1),
              Text(m.notes!, style: const TextStyle(fontSize: 11.5, color: C.muted)),
            ],
          ],
        ),
      ),
      const SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text((positive ? '+' : '') + num(m.delta),
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: positive ? C.green : (m.delta < 0 ? C.red : C.muted))),
          const SizedBox(height: 2),
          Text(rel(m.ts), style: const TextStyle(fontSize: 11, color: C.muted)),
          const SizedBox(height: 2),
          if (m.pending) pendFlag(),
        ],
      ),
    ],
  );
}

// ---------- misc ----------
double _hue(int i) => (i * 137.508) % 360;
Color cycleColor(int i) => HSVColor.fromAHSV(1, _hue(i), 0.55, 0.85).toColor();

Widget labelDot(Color c, String label) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 12, color: C.muted)),
    ],
  );
}

// ---------- filter chip ----------
Widget fchip(String label, bool on, VoidCallback onTap) {
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

// ---------- progress bar ----------
Widget pbar(double pct, {double height = 6, Color color = C.green}) {
  final w = pct.clamp(0.0, 1.0).toDouble();
  return ClipRRect(
    borderRadius: BorderRadius.circular(height),
    child: Container(
      height: height,
      color: C.navyBg,
      alignment: Alignment.centerLeft,
      child: w <= 0
          ? null
          : FractionallySizedBox(
              widthFactor: w,
              child: Container(color: color),
            ),
    ),
  );
}

// ---------- dropdown ----------
class SfDropdown extends StatelessWidget {
  final String value;
  final List<({String value, String label})> options;
  final ValueChanged<String> onChanged;
  final String? hint;
  const SfDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: options.any((o) => o.value == value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(hintText: hint),
      items: [
        for (final o in options)
          DropdownMenuItem(
            value: o.value,
            child: Text(o.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}