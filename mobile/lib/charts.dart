import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

// ====================================================================
// Hand-rolled charts (CustomPainter) — port of src/ui.js SVG charts.
// ====================================================================

class AreaPoint {
  final String x;
  final double y;
  const AreaPoint(this.x, this.y);
}

class AreaChart extends StatelessWidget {
  final List<AreaPoint> points;
  final double height;
  final Color color;
  final bool isMoney;
  const AreaChart(this.points,
      {super.key, this.height = 190, this.color = C.blue, this.isMoney = false});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(double.infinity, height),
      painter: _AreaPainter(points, color, isMoney),
    );
  }
}

class _AreaPainter extends CustomPainter {
  final List<AreaPoint> points;
  final Color color;
  final bool isMoney;
  _AreaPainter(this.points, this.color, this.isMoney);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, hgt = size.height;
    final padL = 40.0, padR = 12.0, padT = 14.0, padB = 26.0;
    final iw = w - padL - padR, ih = hgt - padT - padB;
    final pts = points.isEmpty ? const [AreaPoint('', 0)] : points;
    var maxY = pts.map((p) => p.y).reduce(math.max);
    if (maxY < 1) maxY = 1;

    double px(int i) =>
        padL + (pts.length == 1 ? iw / 2 : (i / (pts.length - 1)) * iw);
    double py(double v) => padT + ih - (v / maxY) * ih;

    // grid + y labels
    final gridPaint = Paint()
      ..color = const Color(0xFFEDF1F6)
      ..strokeWidth = 1.5;
    final labelStyle = TextStyle(color: const Color(0xFF9AA3B2), fontSize: 10.5, fontWeight: FontWeight.w600, inherit: false);
    for (final f in [0.25, 0.5, 0.75, 1.0]) {
      final y = padT + ih - f * ih;
      canvas.drawLine(Offset(padL, y), Offset(w - padR, y), gridPaint);
      final val = maxY * f;
      final label = val >= 1000 ? '${(val / 1000).toStringAsFixed(1)}k' : val.round().toString();
      final tp = TextPainter(
        text: TextSpan(text: isMoney ? '\$$label' : label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(padL - 7 - tp.width, y - tp.height / 2));
    }

    // x labels (skip some when many points)
    for (var i = 0; i < pts.length; i++) {
      if (pts.length > 8 && i % ((pts.length / 6).ceil()) != 0) continue;
      final tp = TextPainter(
        text: TextSpan(text: pts[i].x, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(px(i) - tp.width / 2, hgt - 7 - tp.height));
    }

    if (pts.length < 2) {
      // single point: draw a small dot + baseline area
      final x = px(0), y = py(pts[0].y);
      _fillHalf(canvas, px, py, pts, padL, padT + ih, w - padR);
      canvas.drawCircle(Offset(x, y), 3.4, Paint()..color = color);
      return;
    }

    // area fill
    _fillArea(canvas, px, py, pts, padL, padT + ih);

    // line
    final linePath = Path()..moveTo(px(0), py(pts[0].y));
    for (var i = 1; i < pts.length; i++) {
      linePath.lineTo(px(i), py(pts[i].y));
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // dots
    final dotFill = Paint()..color = Colors.white;
    final dotStroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6;
    for (var i = 0; i < pts.length; i++) {
      canvas.drawCircle(Offset(px(i), py(pts[i].y)), 3.4, dotStroke);
      canvas.drawCircle(Offset(px(i), py(pts[i].y)), 3.4, dotFill);
    }
  }

  void _fillArea(
      Canvas c, double Function(int) px, double Function(double) py, List<AreaPoint> pts, double left, double bottom) {
    final path = Path()
      ..moveTo(px(0), py(pts[0].y));
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(px(i), py(pts[i].y));
    }
    path.lineTo(px(pts.length - 1), bottom);
    path.lineTo(left, bottom);
    path.close();
    final g = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
    ).createShader(Rect.fromLTRB(0, 0, 300, 300));
    c.drawPath(path, Paint()..shader = g);
  }

  void _fillHalf(
      Canvas c, double Function(int) px, double Function(double) py, List<AreaPoint> pts, double left, double bottom, double right) {
    final path = Path()..moveTo(left, bottom)..lineTo(px(0), py(pts[0].y))..lineTo(right, bottom)..close();
    final g = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
    ).createShader(Rect.fromLTRB(0, 0, 300, 300));
    c.drawPath(path, Paint()..shader = g);
  }

  @override
  bool shouldRepaint(covariant _AreaPainter old) =>
      old.points != points || old.color != color || old.isMoney != isMoney;
}

class HBar {
  final String label;
  final double value;
  final String? sub;
  final Color? color;
  const HBar(this.label, this.value, {this.sub, this.color});
}

class HBars extends StatelessWidget {
  final List<HBar> rows;
  final String Function(double) fmt;
  const HBars(this.rows, {super.key, required this.fmt});

  @override
  Widget build(BuildContext context) {
    var max = 1.0;
    for (final r in rows) {
      if (r.value > max) max = r.value;
    }
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(r.label,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600, color: C.ink),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Text(fmt(r.value),
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700, color: C.ink)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    children: [
                      Container(height: 9, color: const Color(0xFFEDF1F6)),
                      FractionallySizedBox(
                        widthFactor: math.max(0.025, r.value / max),
                        child: Container(
                          height: 9,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                r.color ?? C.blueD,
                                (r.color ?? C.blue).withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (r.sub != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(r.sub!,
                        style: const TextStyle(fontSize: 11.5, color: C.muted)),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class DonutSeg {
  final String color;
  final double value;
  const DonutSeg(this.color, this.value);
}

class Donut extends StatelessWidget {
  final List<DonutSeg> segs;
  final double size;
  final String centerValue;
  final String centerLabel;
  const Donut(this.segs,
      {super.key, this.size = 148, this.centerValue = '', this.centerLabel = ''});

  @override
  Widget build(BuildContext context) {
    final total = segs.fold<double>(0, (a, s) => a + s.value).clamp(1.0, 1e18);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _DonutPainter(segs, total.toDouble()),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(centerValue,
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w800, color: C.ink)),
              Text(centerLabel,
                  style: const TextStyle(fontSize: 11.5, color: C.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<DonutSeg> segs;
  final double total;
  _DonutPainter(this.segs, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.width / 2 - 8;
    final strokeWidth = radius * 0.375; // ~21/56 of 148 chart
    final ring = Paint()
      ..color = const Color(0xFFEDF1F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, ring);
    var start = -math.pi / 2;
    final gap = total <= 0 ? 0.0 : math.min(0.04, 0.75 / radius);
    for (final s in segs) {
      if (s.value <= 0) continue;
      final sweep = (s.value / total) * 2 * math.pi;
      final drawSweep = math.max(0.0, sweep - gap);
      final p = Paint()
        ..color = _hex(s.color)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start,
          drawSweep, false, p);
      start += sweep;
    }
  }

  Color _hex(String s) {
    if (s.startsWith('#')) {
      final v = int.tryParse(s.substring(1), radix: 16);
      if (v != null) return Color(0xFF000000 | v);
    }
    return C.blue;
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.segs != segs || old.total != total;
}