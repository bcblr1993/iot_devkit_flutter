// lib/ui/lab/components/lab_charts.dart
//
// Lightweight CustomPaint charts for the performance monitor and
// throughput strips. No external charting dependency — these are
// deliberately simple so they stay cheap to repaint under load.
//
//   LabSparkline — filled line, last-N window
//   LabBars      — bar series (throughput / histogram)
//   LabDonut     — single-value ring (success %, headroom)
//   LabMeter     — horizontal labelled bar (CPU / heap / sockets)

import 'package:flutter/material.dart';
import '../tokens/lab_tokens.dart';

// ── Sparkline ──────────────────────────────────────────────────────
class LabSparkline extends StatelessWidget {
  final List<double> values;   // normalized 0..1 not required; auto-scaled
  final Color? color;
  final double height;
  const LabSparkline({super.key, required this.values, this.color, this.height = 36});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _SparkPainter(values, c)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> v;
  final Color c;
  _SparkPainter(this.v, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    if (v.isEmpty) return;
    final maxV = v.reduce((a, b) => a > b ? a : b);
    final minV = v.reduce((a, b) => a < b ? a : b);
    final range = (maxV - minV).abs() < 1e-9 ? 1.0 : (maxV - minV);
    final dx = size.width / (v.length - 1).clamp(1, 9999);

    final path = Path();
    for (var i = 0; i < v.length; i++) {
      final x = i * dx;
      final y = size.height - ((v[i] - minV) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [c.withValues(alpha: .45), c.withValues(alpha: 0)],
      ).createShader(Offset.zero & size));
    canvas.drawPath(path, Paint()
      ..color = c..strokeWidth = 1.4..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.v != v || old.c != c;
}

// ── Bars ───────────────────────────────────────────────────────────
class LabBars extends StatelessWidget {
  final List<double> values;
  final Color? color;
  final int? peakIndex;
  final double height;
  const LabBars({super.key, required this.values, this.color, this.peakIndex, this.height = 60});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    final t = LabTokens.of(context);
    final maxV = values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++) ...[
            Expanded(
              child: FractionallySizedBox(
                heightFactor: (values[i] / maxV).clamp(0.02, 1.0),
                child: DecoratedBox(decoration: BoxDecoration(
                  color: i == peakIndex ? c : Color.alphaBlend(
                    c.withValues(alpha: .55), Theme.of(context).colorScheme.surface),
                  borderRadius: BorderRadius.circular(1),
                )),
              ),
            ),
            if (i < values.length - 1) SizedBox(width: t.sXxs),
          ],
        ],
      ),
    );
  }
}

// ── Donut ──────────────────────────────────────────────────────────
class LabDonut extends StatelessWidget {
  final double pct;          // 0..100
  final Color? color;
  final String? label;
  final double size;
  const LabDonut({super.key, required this.pct, this.color, this.label, this.size = 72});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = LabTokens.of(context);
    final c = color ?? scheme.primary;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: size, height: size,
        child: CustomPaint(
          painter: _DonutPainter(pct, c, scheme.outlineVariant),
          child: Center(child: Text(
            '${pct.round()}%',
            style: TextStyle(
              fontFamily: tokens.monoFamily,
              fontSize: size * 0.21, fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          )),
        ),
      ),
      if (label != null) ...[
        SizedBox(height: tokens.sSm),
        Text(label!.toUpperCase(), style: TextStyle(
          fontFamily: tokens.monoFamily, fontSize: 10.5,
          color: scheme.onSurfaceVariant, letterSpacing: 0.4,
        )),
      ],
    ]);
  }
}

class _DonutPainter extends CustomPainter {
  final double pct;
  final Color c, track;
  _DonutPainter(this.pct, this.c, this.track);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2 - 4;
    final sw = size.width * 0.10;
    canvas.drawCircle(center, r, Paint()
      ..color = track..strokeWidth = sw..style = PaintingStyle.stroke);
    final sweep = (pct.clamp(0, 100) / 100) * 2 * 3.1415926;
    canvas.drawArc(Rect.fromCircle(center: center, radius: r),
      -3.1415926 / 2, sweep, false,
      Paint()..color = c..strokeWidth = sw
        ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_DonutPainter o) => o.pct != pct || o.c != c;
}

// ── Meter ──────────────────────────────────────────────────────────
class LabMeter extends StatelessWidget {
  final String label;
  final String value;
  final double fraction; // 0..1
  final Color? color;
  const LabMeter({super.key, required this.label, required this.value, required this.fraction, this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = LabTokens.of(context);
    final c = color ?? scheme.primary;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontFamily: tokens.monoFamily, fontSize: 11, color: scheme.onSurfaceVariant)),
        Text(value, style: TextStyle(fontFamily: tokens.monoFamily, fontSize: 11, color: scheme.onSurface)),
      ]),
      SizedBox(height: tokens.sXs),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: fraction.clamp(0, 1),
          minHeight: 6,
          backgroundColor: scheme.outlineVariant,
          valueColor: AlwaysStoppedAnimation(c),
        ),
      ),
    ]);
  }
}
