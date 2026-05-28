import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/subscription_config.dart';
import '../lab/lab.dart';

/// Editor for the per-profile MQTT subscription list. Shared across Basic and
/// Advanced modes — every simulated client picks up the same set after connect.
///
/// Designed with Lab tokens / atoms only so it passes lab_lints with no
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

  void _add(SubscriptionConfig sub) {
    onChanged([...subscriptions, sub]);
  }

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
    final dup = subscriptions.any((s) => s.topic == preset.topic);
    if (dup) return;
    _add(preset);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = LabTokens.of(context);

    // Icon-only trailing controls keep the section header narrow enough to
    // fit even on the minimum-window-size smoke test (~720 px wide).
    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LabIconButton(
          icon: Icons.bolt,
          tooltip: l10n.subscriptionPresetThingsBoardRpc,
          onPressed: isLocked
              ? null
              : () => _addPresetIfMissing(
                  SubscriptionConfig.thingsboardRpcPreset()),
        ),
        SizedBox(width: tokens.sXs),
        LabIconButton(
          icon: Icons.tune,
          tooltip: l10n.subscriptionPresetThingsBoardAttributes,
          onPressed: isLocked
              ? null
              : () => _addPresetIfMissing(
                  SubscriptionConfig.thingsboardAttributesPreset()),
        ),
        SizedBox(width: tokens.sXs),
        LabIconButton(
          icon: Icons.add,
          tooltip: l10n.subscriptionAdd,
          onPressed: isLocked ? null : () => _add(SubscriptionConfig()),
        ),
      ],
    );

    if (subscriptions.isEmpty) {
      // Compact empty state — single line header only; no body padding, no
      // hint text (hint omitted to avoid horizontal overflow on narrow
      // windows). Smoke test asserts no RenderFlex overflow at min size.
      return LabSection(
        title: l10n.subscriptionsTitle,
        trailing: trailing,
        padded: false,
        child: const SizedBox.shrink(),
      );
    }

    // Mounted inside the basic / advanced tab's SingleChildScrollView,
    // so we let the outer scroll handle vertical overflow.
    return LabSection(
      title: l10n.subscriptionsTitle,
      hint: l10n.subscriptionsHint,
      trailing: trailing,
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
