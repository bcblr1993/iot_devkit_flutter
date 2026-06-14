import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/subscription_config.dart';
import '../lab/lab.dart';

/// Inline editor for the MQTT subscription list, intended to be embedded
/// **inside** [MqttConfigSection]'s LabSection child column (gated by the
/// "enable subscriptions" toggle there). No LabSection wrapper of its own —
/// the parent section provides the visual frame.
///
/// Lab tokens / atoms only, so lab_lints stays clean without
/// `ignore_for_file`.
class SubscriptionsSection extends StatelessWidget {
  final List<SubscriptionConfig> subscriptions;
  final bool isLocked;
  final ValueChanged<List<SubscriptionConfig>> onChanged;

  const SubscriptionsSection({
    super.key,
    required this.subscriptions,
    required this.isLocked,
    required this.onChanged,
  });

  void _add(SubscriptionConfig sub) => onChanged([...subscriptions, sub]);

  void _replace(int index, SubscriptionConfig sub) {
    final next = List<SubscriptionConfig>.from(subscriptions);
    next[index] = sub;
    onChanged(next);
  }

  void _removeAt(int index) {
    final next = List<SubscriptionConfig>.from(subscriptions);
    next.removeAt(index);
    onChanged(next);
  }

  void _addPresetIfMissing(SubscriptionConfig preset) {
    if (subscriptions.any((s) => s.topic == preset.topic)) return;
    _add(preset);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = LabTokens.of(context);
    final theme = Theme.of(context);

    // Compact toolbar: preset shortcuts on the left, add-blank on the right.
    final toolbar = Row(
      children: [
        LabIconButton(
          icon: Icons.bolt,
          size: LabButtonSize.sm,
          tooltip: l10n.subscriptionPresetThingsBoardRpc,
          onPressed: isLocked
              ? null
              : () => _addPresetIfMissing(
                  SubscriptionConfig.thingsboardRpcPreset()),
        ),
        SizedBox(width: tokens.sXs),
        LabIconButton(
          icon: Icons.tune,
          size: LabButtonSize.sm,
          tooltip: l10n.subscriptionPresetThingsBoardAttributes,
          onPressed: isLocked
              ? null
              : () => _addPresetIfMissing(
                  SubscriptionConfig.thingsboardAttributesPreset()),
        ),
        const Spacer(),
        LabButton(
          label: l10n.subscriptionAdd,
          icon: Icons.add,
          size: LabButtonSize.sm,
          onPressed: isLocked ? null : () => _add(SubscriptionConfig()),
        ),
      ],
    );

    final hasRpcFilter = subscriptions.any((s) => s.isThingsBoardRpcFilter);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        toolbar,
        SizedBox(height: tokens.sMd),
        // Explain auto-ack once at the section level when an RPC filter is
        // present (rather than only via the per-row tooltip).
        if (hasRpcFilter) ...[
          LabInlineAlert(
            kind: LabStatus.info,
            child: Text(l10n.subscriptionAutoAckHint),
          ),
          SizedBox(height: tokens.sMd),
        ],
        if (subscriptions.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: tokens.sMd),
            child: Center(
              child: Text(
                l10n.subscriptionsEmpty,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.faint,
                ),
              ),
            ),
          )
        else
          // Cap row area so long lists don't push the mode tabs / log dock
          // off-screen on small windows. Internal scroll handles overflow.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (var i = 0; i < subscriptions.length; i++) ...[
                    if (i > 0) SizedBox(height: tokens.sMd),
                    _SubscriptionRow(
                      key: ValueKey(subscriptions[i].id),
                      sub: subscriptions[i],
                      isLocked: isLocked,
                      onChanged: (s) => _replace(i, s),
                      onRemove: () => _removeAt(i),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SubscriptionRow extends StatefulWidget {
  final SubscriptionConfig sub;
  final bool isLocked;
  final ValueChanged<SubscriptionConfig> onChanged;
  final VoidCallback onRemove;

  const _SubscriptionRow({
    super.key,
    required this.sub,
    required this.isLocked,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_SubscriptionRow> createState() => _SubscriptionRowState();
}

class _SubscriptionRowState extends State<_SubscriptionRow> {
  late final TextEditingController _topicController;

  @override
  void initState() {
    super.initState();
    _topicController = TextEditingController(text: widget.sub.topic);
  }

  @override
  void didUpdateWidget(covariant _SubscriptionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sub.topic != widget.sub.topic &&
        _topicController.text != widget.sub.topic) {
      _topicController.text = widget.sub.topic;
    }
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = LabTokens.of(context);
    final sub = widget.sub;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Narrow window → wrap the right-side controls below the topic field.
        final compact = constraints.maxWidth < 640;

        final controls = Wrap(
          spacing: tokens.sMd,
          runSpacing: tokens.sSm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // 'RPC' is a protocol token, not localized copy.
            if (sub.isThingsBoardRpcFilter)
              LabPill(label: 'RPC', color: tokens.info, small: true),
            LabSegmented<int>(
              value: sub.qos,
              segments: const [
                LabSegment(0, '0'),
                LabSegment(1, '1'),
                LabSegment(2, '2'),
              ],
              onChanged: widget.isLocked
                  ? (_) {}
                  : (v) => widget.onChanged(sub.copyWith(qos: v)),
            ),
            if (sub.isThingsBoardRpcFilter)
              Tooltip(
                message: l10n.subscriptionAutoAckHint,
                child: LabCheckbox(
                  value: sub.autoAck,
                  label: l10n.subscriptionAutoAck,
                  onChanged: widget.isLocked
                      ? null
                      : (v) =>
                          widget.onChanged(sub.copyWith(autoAck: v ?? false)),
                ),
              ),
            LabIconButton(
              icon: Icons.delete_outline,
              tooltip: l10n.subscriptionDelete,
              onPressed: widget.isLocked ? null : widget.onRemove,
            ),
          ],
        );

        final enableToggle = Tooltip(
          message: l10n.subscriptionEnabledTooltip,
          child: LabCheckbox(
            value: sub.enabled,
            onChanged: widget.isLocked
                ? null
                : (v) => widget.onChanged(sub.copyWith(enabled: v ?? false)),
          ),
        );

        final topicField = LabField(
          controller: _topicController,
          hintText: l10n.subscriptionTopicHint,
          mono: true,
          readOnly: widget.isLocked,
          inputFormatters: const <TextInputFormatter>[],
          onChanged: (v) => widget.onChanged(sub.copyWith(topic: v)),
        );

        if (compact) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: tokens.sXs),
                child: enableToggle,
              ),
              SizedBox(width: tokens.sMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    topicField,
                    SizedBox(height: tokens.sSm),
                    controls,
                  ],
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            enableToggle,
            SizedBox(width: tokens.sMd),
            Expanded(child: topicField),
            SizedBox(width: tokens.sMd),
            controls,
          ],
        );
      },
    );
  }
}
