// lib/ui/lab/components/lab_state.dart
//
// Connection state machine — mirrors mqtt_view_model.dart's 8 states.
// Each state resolves to a color + label + glyph + the actions that
// should be available, so the top bar can render any state uniformly.

import 'package:flutter/material.dart';
import '../tokens/lab_tokens.dart';
import 'lab_feedback.dart' show LabStatusDot, LabStatus;

enum LabConnectionState {
  idle,
  starting,
  connecting,
  running,
  reconnecting,
  partialRunning,
  stopping,
  failed,
}

/// Visual + behavioural descriptor for a [LabConnectionState].
class LabStateInfo {
  final String label;
  final String Function(BuildContext)? subtitle; // localized at call-site
  final bool spinning;   // show inline spinner (transitional states)
  final bool pulsing;    // blink the dot (reconnecting)
  final bool glowing;    // glow the dot (healthy running)
  const LabStateInfo({
    required this.label,
    this.subtitle,
    this.spinning = false,
    this.pulsing = false,
    this.glowing = false,
  });
}

extension LabConnectionStateX on LabConnectionState {
  /// Resolve the accent color off the current theme.
  Color color(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = LabTokens.of(context);
    return switch (this) {
      LabConnectionState.idle           => t.faint,
      LabConnectionState.starting        => t.info,
      LabConnectionState.connecting      => t.info,
      LabConnectionState.running         => t.ok,
      LabConnectionState.reconnecting    => t.warn,
      LabConnectionState.partialRunning  => t.warn,
      LabConnectionState.stopping        => scheme.onSurfaceVariant,
      LabConnectionState.failed          => scheme.error,
    };
  }

  String get label => switch (this) {
    LabConnectionState.idle          => 'IDLE',
    LabConnectionState.starting      => 'STARTING',
    LabConnectionState.connecting    => 'CONNECTING',
    LabConnectionState.running       => 'RUNNING',
    LabConnectionState.reconnecting  => 'RECONNECTING',
    LabConnectionState.partialRunning=> 'PARTIAL',
    LabConnectionState.stopping      => 'STOPPING',
    LabConnectionState.failed        => 'FAILED',
  };

  bool get spinning => this == LabConnectionState.starting ||
      this == LabConnectionState.connecting ||
      this == LabConnectionState.stopping;

  bool get pulsing => this == LabConnectionState.reconnecting;
  bool get glowing => this == LabConnectionState.running;

  /// Whether configuration inputs should be locked in this state.
  bool get locksConfig => this != LabConnectionState.idle &&
      this != LabConnectionState.failed;
}

/// The status pill shown at the left of the top bar — dot + label,
/// with optional inline spinner for transitional states.
class LabStatePill extends StatefulWidget {
  final LabConnectionState state;
  const LabStatePill({super.key, required this.state});

  @override
  State<LabStatePill> createState() => _LabStatePillState();
}

class _LabStatePillState extends State<LabStatePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  @override
  void initState() {
    super.initState();
    _syncSpin();
  }

  @override
  void didUpdateWidget(covariant LabStatePill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.spinning != widget.state.spinning) _syncSpin();
  }

  // Only burn a ticker while a transitional state is on screen; an
  // always-repeating controller would otherwise spin invisibly (and leave a
  // pending timer that trips widget-test teardown).
  void _syncSpin() {
    if (widget.state.spinning) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LabTokens.of(context);
    final c = widget.state.color(context);

    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (widget.state.spinning)
        RotationTransition(
          turns: _spin,
          child: SizedBox(
            width: 10, height: 10,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: c),
          ),
        )
      else
        LabStatusDot(
          kind: switch (widget.state) {
            LabConnectionState.running => LabStatus.ok,
            LabConnectionState.failed => LabStatus.error,
            LabConnectionState.reconnecting ||
            LabConnectionState.partialRunning => LabStatus.warn,
            LabConnectionState.starting ||
            LabConnectionState.connecting => LabStatus.info,
            _ => LabStatus.idle,
          },
          glow: widget.state.glowing,
        ),
      SizedBox(width: tokens.sMd),
      Text(
        widget.state.label,
        style: TextStyle(
          fontFamily: tokens.monoFamily,
          fontSize: 12, fontWeight: FontWeight.w700, color: c,
        ),
      ),
    ]);
  }
}
