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
      // Empty list contributes ZERO vertical space — discovery lives in the
      // MQTT broker section's trailing area instead (see
      // SubscriptionsMenuButton.forMqttHeader). Keeping the empty state
      // collapsed lets the simulator panel fit the 800×600 minimum window.
      return const SizedBox.shrink();
    }

    // Populated — full LabSection. Wrap the rows in a bounded scroll so a
    // long subscription list can't push the mode tabs / log dock off-screen.
    return LabSection(
      title: l10n.subscriptionsTitle,
      hint: l10n.subscriptionsHint,
      trailing: trailing,
      child: ConstrainedBox(
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
    );
  }
}

/// Drop-in trailing widget for [MqttConfigSection.extraTrailing] — surfaces
/// the subscription presets and add-blank action in the section header so
/// users discover subscriptions are a connection-level concept even when
/// the list is empty.
///
/// Adds **zero** vertical height to the simulator panel layout because it
/// sits inside the LabSection's existing 30-px header strip.
class SubscriptionsMenuButton extends StatelessWidget {
  final List<SubscriptionConfig> subscriptions;
  final ValueChanged<List<SubscriptionConfig>> onChanged;
  final bool isLocked;

  const SubscriptionsMenuButton({
    super.key,
    required this.subscriptions,
    required this.onChanged,
    required this.isLocked,
  });

  void _add(SubscriptionConfig sub) {
    onChanged([...subscriptions, sub]);
  }

  void _addPresetIfMissing(SubscriptionConfig preset) {
    if (subscriptions.any((s) => s.topic == preset.topic)) return;
    _add(preset);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return PopupMenuButton<_SubMenuAction>(
      tooltip: l10n.subscriptionAdd,
      enabled: !isLocked,
      // Override the default 48×48 IconButton hit-area: render a compact
      // 24×24 chip that matches LabIconButton sm. Adding the button to the
      // MQTT header trailing must NOT grow LabSection's header strip.
      padding: EdgeInsets.zero,
      splashRadius: 14,
      child: SizedBox(
        width: 24,
        height: 24,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outline),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(Icons.add_link,
              size: 14, color: scheme.onSurfaceVariant),
        ),
      ),
      onSelected: (action) {
        switch (action) {
          case _SubMenuAction.rpcPreset:
            _addPresetIfMissing(SubscriptionConfig.thingsboardRpcPreset());
          case _SubMenuAction.attributesPreset:
            _addPresetIfMissing(
                SubscriptionConfig.thingsboardAttributesPreset());
          case _SubMenuAction.blank:
            _add(SubscriptionConfig());
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          key: const ValueKey('sub_menu_rpc_preset'),
          value: _SubMenuAction.rpcPreset,
          child: Row(children: [
            Icon(Icons.bolt, size: 16, color: scheme.primary),
            const SizedBox(width: 8),
            Text(l10n.subscriptionPresetThingsBoardRpc),
          ]),
        ),
        PopupMenuItem(
          key: const ValueKey('sub_menu_attrs_preset'),
          value: _SubMenuAction.attributesPreset,
          child: Row(children: [
            Icon(Icons.tune, size: 16, color: scheme.primary),
            const SizedBox(width: 8),
            Text(l10n.subscriptionPresetThingsBoardAttributes),
          ]),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          key: const ValueKey('sub_menu_blank'),
          value: _SubMenuAction.blank,
          child: Row(children: [
            Icon(Icons.add, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(l10n.subscriptionAdd),
          ]),
        ),
      ],
    );
  }
}

enum _SubMenuAction { rpcPreset, attributesPreset, blank }

/// Legacy compact bar kept for backwards-compat — currently unused after the
/// menu-button refactor. Retained in case we want to expose discovery in a
/// secondary location later.
// ignore: unused_element
class _DiscoveryBar extends StatelessWidget {
  final String title;
  final VoidCallback rpcPreset;
  final VoidCallback attrPreset;
  final VoidCallback addBlank;
  final bool isLocked;
  final AppLocalizations l10n;

  const _DiscoveryBar({
    required this.title,
    required this.rpcPreset,
    required this.attrPreset,
    required this.addBlank,
    required this.isLocked,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = LabTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: tokens.sLg, vertical: tokens.sXxs),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 12,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(tokens.rXs - 1),
            ),
          ),
          SizedBox(width: tokens.sMd),
          Text(
            title.toUpperCase(),
            style: textTheme.titleMedium?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(width: tokens.sMd),
          Text(
            l10n.subscriptionsEmpty,
            style: textTheme.labelLarge?.copyWith(
              fontSize: 11,
              color: tokens.faint,
            ),
          ),
          const Spacer(),
          LabIconButton(
            icon: Icons.bolt,
            size: LabButtonSize.sm,
            tooltip: l10n.subscriptionPresetThingsBoardRpc,
            onPressed: isLocked ? null : rpcPreset,
          ),
          SizedBox(width: tokens.sXs),
          LabIconButton(
            icon: Icons.tune,
            size: LabButtonSize.sm,
            tooltip: l10n.subscriptionPresetThingsBoardAttributes,
            onPressed: isLocked ? null : attrPreset,
          ),
          SizedBox(width: tokens.sXs),
          LabIconButton(
            icon: Icons.add,
            size: LabButtonSize.sm,
            tooltip: l10n.subscriptionAdd,
            onPressed: isLocked ? null : addBlank,
          ),
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
