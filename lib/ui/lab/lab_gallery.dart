// lib/ui/lab/lab_gallery.dart
//
// Lab Console component gallery (design system · gallery.jsx · MIGRATION
// §6 widgetbook). A self-contained, theme-switchable showcase of every
// Lab atom in representative states — used for visual QA across the 8
// themes. NOT wired into the production app: zero blast radius.

import 'package:flutter/material.dart';
import 'lab.dart';

class LabGallery extends StatefulWidget {
  const LabGallery({super.key});

  @override
  State<LabGallery> createState() => _LabGalleryState();
}

class _LabGalleryState extends State<LabGallery> {
  int _themeIndex = 0;

  // Local state for the interactive form atoms.
  bool _checkbox = true;
  String _radio = 'a';
  bool _toggle = true;
  String _select = 'round-robin';
  int _segment = 1;
  final _fieldController = TextEditingController(text: '192.168.1.100');

  @override
  void dispose() {
    _fieldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = LabThemes.all[_themeIndex];
    return Theme(
      data: theme.themeData,
      child: Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          final tokens = LabTokens.of(context);
          return Scaffold(
            backgroundColor: scheme.surface,
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _themeBar(theme, tokens, scheme),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(tokens.sXl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buttons(tokens),
                          SizedBox(height: tokens.sLg),
                          _forms(tokens),
                          SizedBox(height: tokens.sLg),
                          _feedback(context, tokens, scheme),
                          SizedBox(height: tokens.sLg),
                          _data(tokens),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _themeBar(LabTheme theme, LabTokens tokens, ColorScheme scheme) {
    return Container(
      padding: EdgeInsets.all(tokens.sLg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Text(
            'LAB GALLERY',
            style: TextStyle(
              fontFamily: tokens.monoFamily,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: scheme.onSurface,
            ),
          ),
          SizedBox(width: tokens.sLg),
          LabPill(label: '${theme.name} · ${theme.tag}', color: scheme.primary),
          const Spacer(),
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                children: [
                  for (var i = 0; i < LabThemes.all.length; i++) ...[
                    LabButton(
                      label: LabThemes.all[i].name,
                      size: LabButtonSize.sm,
                      variant: i == _themeIndex
                          ? LabButtonVariant.primary
                          : LabButtonVariant.secondary,
                      onPressed: () => setState(() => _themeIndex = i),
                    ),
                    SizedBox(width: tokens.sSm),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buttons(LabTokens tokens) {
    return LabSection(
      title: 'Buttons',
      hint: '// variant × size × state',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: tokens.sMd, runSpacing: tokens.sMd, children: const [
            LabButton(label: 'Primary', variant: LabButtonVariant.primary),
            LabButton(label: 'Secondary'),
            LabButton(label: 'Ghost', variant: LabButtonVariant.ghost),
            LabButton(label: 'Danger', variant: LabButtonVariant.danger),
            LabButton(label: 'Success', variant: LabButtonVariant.success),
            LabButton(
                label: 'With icon',
                icon: Icons.play_arrow,
                variant: LabButtonVariant.primary),
            LabButton(label: 'Loading', loading: true),
            LabButton(label: 'Disabled'),
          ]),
          SizedBox(height: tokens.sMd),
          Wrap(
            spacing: tokens.sMd,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: const [
              LabButton(label: 'SM', size: LabButtonSize.sm),
              LabButton(label: 'MD', size: LabButtonSize.md),
              LabButton(label: 'LG', size: LabButtonSize.lg),
              LabIconButton(icon: Icons.settings),
              LabIconButton(icon: Icons.notifications, active: true),
              LabIconButton(icon: Icons.mail, badge: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _forms(LabTokens tokens) {
    return LabSection(
      title: 'Form',
      hint: '// field · select · segmented · check · radio · toggle',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child:
                  LabField(label: 'Broker host', controller: _fieldController),
            ),
            SizedBox(width: tokens.sLg),
            const Expanded(
              child: LabField(
                  label: 'Port', initialValue: '1883', suffix: 'tcp'),
            ),
          ]),
          SizedBox(height: tokens.sMd),
          const LabField(
            label: 'With error',
            initialValue: 'bad value',
            errorText: 'Invalid host',
          ),
          SizedBox(height: tokens.sMd),
          LabSelect<String>(
            label: 'Group strategy',
            value: _select,
            items: const [
              LabSelectItem('round-robin', 'round-robin'),
              LabSelectItem('random', 'random'),
              LabSelectItem('weighted', 'weighted'),
            ],
            onChanged: (v) => setState(() => _select = v ?? _select),
          ),
          SizedBox(height: tokens.sMd),
          LabSegmented<int>(
            value: _segment,
            segments: const [
              LabSegment(0, 'BASIC'),
              LabSegment(1, 'ADVANCED'),
              LabSegment(2, 'REPLAY'),
            ],
            onChanged: (v) => setState(() => _segment = v),
          ),
          SizedBox(height: tokens.sMd),
          Wrap(spacing: tokens.s2xl, runSpacing: tokens.sMd, children: [
            LabCheckbox(
              value: _checkbox,
              label: 'clean session',
              onChanged: (v) => setState(() => _checkbox = v ?? false),
            ),
            LabRadio<String>(
              groupValue: _radio,
              value: 'a',
              label: 'QoS 0',
              onChanged: (v) => setState(() => _radio = v ?? 'a'),
            ),
            LabRadio<String>(
              groupValue: _radio,
              value: 'b',
              label: 'QoS 1',
              onChanged: (v) => setState(() => _radio = v ?? 'a'),
            ),
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('auto reconnect'),
              SizedBox(width: tokens.sMd),
              LabToggle(
                value: _toggle,
                onChanged: (v) => setState(() => _toggle = v),
              ),
            ]),
          ]),
        ],
      ),
    );
  }

  Widget _feedback(BuildContext context, LabTokens tokens, ColorScheme scheme) {
    return LabSection(
      title: 'Feedback',
      hint: '// pill · dot · alert · toast · dialog',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: tokens.sMd, runSpacing: tokens.sMd, children: [
            LabPill(label: 'QoS 1', color: scheme.primary),
            LabPill(label: 'TLS OFF', color: tokens.warn),
            LabPill(label: 'v3.1.1', color: tokens.faint),
            LabPill(label: 'LIVE', color: tokens.ok, small: true),
          ]),
          SizedBox(height: tokens.sMd),
          const Row(children: [
            LabStatusDot(kind: LabStatus.ok, glow: true),
            SizedBox(width: 8),
            LabStatusDot(kind: LabStatus.warn),
            SizedBox(width: 8),
            LabStatusDot(kind: LabStatus.error),
            SizedBox(width: 8),
            LabStatusDot(kind: LabStatus.info),
            SizedBox(width: 8),
            LabStatusDot(kind: LabStatus.idle),
          ]),
          SizedBox(height: tokens.sMd),
          const LabInlineAlert(
            kind: LabStatus.info,
            child: Text('advanced 模式 · 1,000 设备 · 估算 132 KB/s'),
          ),
          SizedBox(height: tokens.sSm),
          const LabInlineAlert(
            kind: LabStatus.warn,
            child: Text('RTT spike 142ms · broker tcp://192.168.1.100:1883'),
          ),
          SizedBox(height: tokens.sMd),
          Wrap(spacing: tokens.sMd, runSpacing: tokens.sMd, children: [
            LabButton(
              label: 'Toast · ok',
              variant: LabButtonVariant.success,
              onPressed: () => showLabToast(context,
                  title: 'Simulation started',
                  kind: LabStatus.ok,
                  message: 'sim-01 · advanced · 1,000 devices'),
            ),
            LabButton(
              label: 'Toast · error',
              variant: LabButtonVariant.danger,
              onPressed: () => showLabToast(context,
                  title: 'Broker unreachable', kind: LabStatus.error),
            ),
            LabButton(
              label: 'Confirm dialog',
              onPressed: () => showLabConfirm(context,
                  destructive: true,
                  title: '停止当前模拟会话?',
                  summary: 'sim-01 · advanced · 1,000 devices',
                  body: '将停止所有设备发送并丢弃 in-flight 消息。',
                  primaryLabel: '停止',
                  secondaryLabel: '继续运行'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _data(LabTokens tokens) {
    return const LabSection(
      title: 'Data',
      hint: '// log rows',
      padded: false,
      child: Column(
        children: [
          LabLogRow(
            timestamp: '2026-05-18 14:22:18.844',
            level: LabLogLevel.ok,
            tag: 'mqtt',
            message: 'PUBLISH dt/dev-0427/telemetry  qos=1  payload=132B',
          ),
          LabLogRow(
            timestamp: '2026-05-18 14:22:18.831',
            level: LabLogLevel.info,
            tag: 'sched',
            message: 'batch flush · 200 devices / 198ms / 0 retry',
          ),
          LabLogRow(
            timestamp: '2026-05-18 14:22:17.001',
            level: LabLogLevel.warn,
            tag: 'net',
            message: 'RTT spike 142ms · broker tcp://192.168.1.100:1883',
          ),
          LabLogRow(
            timestamp: '2026-05-18 14:22:16.220',
            level: LabLogLevel.error,
            tag: 'conn',
            message: 'CONNACK refused · not authorized',
          ),
          LabLogRow(
            timestamp: '2026-05-18 14:22:15.998',
            level: LabLogLevel.debug,
            tag: 'boot',
            message: 'simulation start · mode=advanced · 1000 devices',
            dim: true,
          ),
        ],
      ),
    );
  }
}
