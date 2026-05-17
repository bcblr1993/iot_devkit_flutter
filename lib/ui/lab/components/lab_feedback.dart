// lib/ui/lab/components/lab_feedback.dart
//
// Status & feedback atoms — see design system §05.
//
// LabPill        — uppercase mono tag with hairline border
// LabStatusDot   — 8px coloured dot (optional glow) for status text rows
// LabInlineAlert — in-flow message strip (info/success/warn/error)
// LabToast       — overlay-style toast with title/message/action; pair
//                  with [showLabToast()] to manage stacking & dismissal.

import 'dart:async';

import 'package:flutter/material.dart';
import '../tokens/lab_tokens.dart';

// ── LabPill ────────────────────────────────────────────────────────
class LabPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool small;
  const LabPill({
    super.key,
    required this.label,
    required this.color,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = LabTokens.of(context);
    final fs = small ? 10.0 : 11.0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        border: Border.all(color: color.withValues(alpha: .30)),
        borderRadius: BorderRadius.circular(tokens.rSm),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: tokens.monoFamily,
          fontSize: fs,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          height: 1.3,
          color: color,
        ),
      ),
    );
  }
}

// ── LabStatusDot ───────────────────────────────────────────────────
enum LabStatus { ok, warn, error, info, idle }

class LabStatusDot extends StatelessWidget {
  final LabStatus kind;
  final bool glow;
  const LabStatusDot({super.key, this.kind = LabStatus.ok, this.glow = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = LabTokens.of(context);
    final c = switch (kind) {
      LabStatus.ok => tokens.ok,
      LabStatus.warn => tokens.warn,
      LabStatus.error => scheme.error,
      LabStatus.info => tokens.info,
      LabStatus.idle => scheme.onSurfaceVariant,
    };
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        boxShadow: glow ? [BoxShadow(color: c, blurRadius: 10)] : null,
      ),
    );
  }
}

// ── LabInlineAlert ─────────────────────────────────────────────────
class LabInlineAlert extends StatelessWidget {
  final LabStatus kind;
  final Widget child;
  const LabInlineAlert(
      {super.key, this.kind = LabStatus.info, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = LabTokens.of(context);
    final text = Theme.of(context).textTheme;

    final c = switch (kind) {
      LabStatus.ok => tokens.ok,
      LabStatus.warn => tokens.warn,
      LabStatus.error => scheme.error,
      LabStatus.info => tokens.info,
      LabStatus.idle => scheme.onSurfaceVariant,
    };
    final glyph = switch (kind) {
      LabStatus.ok => '✓',
      LabStatus.warn => '!',
      LabStatus.error => '×',
      LabStatus.info => 'i',
      LabStatus.idle => '·',
    };

    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: tokens.sLg, vertical: tokens.sMd),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .12),
        border: Border.all(color: c.withValues(alpha: .35)),
        borderRadius: BorderRadius.circular(tokens.rSm + 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            glyph,
            style: TextStyle(
              fontFamily: tokens.monoFamily,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: c,
              height: 1.4,
            ),
          ),
          SizedBox(width: tokens.sSm + 2),
          Expanded(
            child: DefaultTextStyle.merge(
              style: text.bodySmall!.copyWith(color: tokens.body, height: 1.45),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

// ── LabToast ───────────────────────────────────────────────────────
//
// Use the [showLabToast] helper to drop a toast into the overlay.
// The toast auto-dismisses after [duration] unless it's an error.
class LabToast extends StatelessWidget {
  final LabStatus kind;
  final String title;
  final String? message;
  final List<Widget>? actions;
  final VoidCallback? onDismiss;

  const LabToast({
    super.key,
    required this.title,
    this.kind = LabStatus.info,
    this.message,
    this.actions,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = LabTokens.of(context);
    final text = Theme.of(context).textTheme;

    final c = switch (kind) {
      LabStatus.ok => tokens.ok,
      LabStatus.warn => tokens.warn,
      LabStatus.error => scheme.error,
      LabStatus.info => tokens.info,
      LabStatus.idle => scheme.onSurfaceVariant,
    };
    final glyph = switch (kind) {
      LabStatus.ok => '✓',
      LabStatus.warn => '!',
      LabStatus.error => '×',
      LabStatus.info => 'i',
      LabStatus.idle => '·',
    };
    final tag = kind.name.toUpperCase();

    // NOTE: a non-uniform Border (different left side) combined with a
    // borderRadius asserts in Border.paint(). Keep the rounded card with a
    // uniform hairline border and render the 3px accent as an inner stripe.
    return Container(
      width: 360,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.rMd),
        boxShadow: const [
          BoxShadow(
              color: Color(0x59000000), blurRadius: 32, offset: Offset(0, 12)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.rMd),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            border: Border.all(color: c.withValues(alpha: .50)),
          ),
          child: IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(width: 3, color: c),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(tokens.sLg),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: c.withValues(alpha: .18),
                            borderRadius: BorderRadius.circular(tokens.rSm + 1),
                          ),
                          alignment: Alignment.center,
                          child: Text(glyph,
                              style: TextStyle(
                                fontFamily: tokens.monoFamily,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: c,
                                height: 1,
                              )),
                        ),
                        SizedBox(width: tokens.sLg),
                        Expanded(
                            child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(children: [
                              Expanded(
                                  child: Text(title,
                                      style: text.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: scheme.onSurface,
                                      ))),
                              SizedBox(width: tokens.sMd),
                              LabPill(label: tag, color: c, small: true),
                            ]),
                            if (message != null) ...[
                              SizedBox(height: tokens.sXs),
                              Text(message!,
                                  style: text.bodySmall
                                      ?.copyWith(color: tokens.body)),
                            ],
                            if (actions != null && actions!.isNotEmpty) ...[
                              SizedBox(height: tokens.sMd),
                              Row(children: [
                                for (var i = 0; i < actions!.length; i++) ...[
                                  if (i > 0) SizedBox(width: tokens.sSm),
                                  actions![i],
                                ],
                              ]),
                            ],
                          ],
                        )),
                        if (onDismiss != null)
                          IconButton(
                            icon: Icon(Icons.close,
                                size: 14, color: tokens.faint),
                            onPressed: onDismiss,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Toast overlay helper ───────────────────────────────────────────
//
// One stack at bottom-right of the navigator. Call repeatedly — toasts
// stack and auto-dismiss after [duration] (4s default, errors stay until
// dismissed manually).

class _ToastStack extends ChangeNotifier {
  final List<_ToastEntry> entries = [];
  void add(_ToastEntry e) {
    entries.add(e);
    notifyListeners();
  }

  void remove(_ToastEntry e) {
    e.timer?.cancel();
    entries.remove(e);
    notifyListeners();
  }

  void clear() {
    for (final e in entries) {
      e.timer?.cancel();
    }
    entries.clear();
    notifyListeners();
  }
}

class _ToastEntry {
  final Key key;
  final LabStatus kind;
  final String title;
  final String? message;
  Timer? timer;
  _ToastEntry(this.key, this.kind, this.title, this.message);
}

final _stack = _ToastStack();
OverlayEntry? _overlayEntry;

/// Drop a toast into the root overlay. Returns a dismiss handle.
VoidCallback showLabToast(
  BuildContext context, {
  required String title,
  LabStatus kind = LabStatus.info,
  String? message,
  Duration? duration,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  if (_overlayEntry == null) {
    _overlayEntry = OverlayEntry(builder: (ctx) {
      return AnimatedBuilder(
        animation: _stack,
        builder: (_, __) => Positioned(
          right: 16,
          bottom: 16,
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final e in _stack.entries) ...[
                  LabToast(
                    key: e.key,
                    kind: e.kind,
                    title: e.title,
                    message: e.message,
                    onDismiss: () => _stack.remove(e),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      );
    });
    overlay.insert(_overlayEntry!);
  }

  final entry = _ToastEntry(UniqueKey(), kind, title, message);
  _stack.add(entry);

  final lifetime = duration ??
      (kind == LabStatus.error
          ? const Duration(days: 1) // stays
          : const Duration(seconds: 4));
  entry.timer = Timer(lifetime, () {
    if (_stack.entries.contains(entry)) _stack.remove(entry);
  });

  return () => _stack.remove(entry);
}

/// Cancel and remove every visible toast and tear down the shared overlay
/// entry. Call from test teardown (or when disposing the navigator) so
/// pending auto-dismiss timers don't leak past the widget tree.
void clearLabToasts() {
  _stack.clear();
  _overlayEntry?.remove();
  _overlayEntry = null;
}
