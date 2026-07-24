import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/text_diff_service.dart';
import '../components/app_empty_state.dart';
import '../lab/lab.dart';

class TextDiffTool extends StatefulWidget {
  const TextDiffTool({super.key});

  @override
  State<TextDiffTool> createState() => _TextDiffToolState();
}

class _TextDiffToolState extends State<TextDiffTool> {
  static const String _originalStorageKey = 'text_diff_original';
  static const String _modifiedStorageKey = 'text_diff_modified';
  static const int _maxPersistedLength = 1024 * 1024;

  final TextEditingController _originalController = TextEditingController();
  final TextEditingController _modifiedController = TextEditingController();

  Timer? _compareTimer;
  Timer? _saveTimer;
  TextDiffResult? _result;
  int _compareGeneration = 0;
  bool _isComparing = false;
  bool _suppressControllerEvents = false;

  bool get _isEmpty =>
      _originalController.text.isEmpty && _modifiedController.text.isEmpty;

  @override
  void initState() {
    super.initState();
    _originalController.addListener(_onTextChanged);
    _modifiedController.addListener(_onTextChanged);
    _loadState();
  }

  @override
  void dispose() {
    _compareTimer?.cancel();
    _saveTimer?.cancel();
    _originalController.dispose();
    _modifiedController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final preferences = await SharedPreferences.getInstance();
    final original = preferences.getString(_originalStorageKey) ?? '';
    final modified = preferences.getString(_modifiedStorageKey) ?? '';
    if (!mounted) return;

    _replaceTexts(original, modified);
    if (!_isEmpty) {
      _compare(immediate: true);
    }
  }

  void _onTextChanged() {
    if (_suppressControllerEvents) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), _saveState);
    _compare();
  }

  void _compare({bool immediate = false}) {
    _compareTimer?.cancel();
    final generation = ++_compareGeneration;

    if (_isEmpty) {
      if (mounted) {
        setState(() {
          _result = null;
          _isComparing = false;
        });
      }
      return;
    }

    if (mounted && !_isComparing) {
      setState(() => _isComparing = true);
    }
    _compareTimer = Timer(
      immediate ? Duration.zero : const Duration(milliseconds: 220),
      () => _runComparison(generation),
    );
  }

  Future<void> _runComparison(int generation) async {
    final original = _originalController.text;
    final modified = _modifiedController.text;
    final result = await TextDiffService.compare(original, modified);
    if (!mounted || generation != _compareGeneration) return;

    setState(() {
      _result = result;
      _isComparing = false;
    });
  }

  Future<void> _saveState() async {
    final preferences = await SharedPreferences.getInstance();
    await _persistText(
      preferences,
      _originalStorageKey,
      _originalController.text,
    );
    await _persistText(
      preferences,
      _modifiedStorageKey,
      _modifiedController.text,
    );
  }

  Future<void> _persistText(
    SharedPreferences preferences,
    String key,
    String value,
  ) {
    if (value.length > _maxPersistedLength) {
      return preferences.remove(key);
    }
    return preferences.setString(key, value);
  }

  void _replaceTexts(String original, String modified) {
    _suppressControllerEvents = true;
    _originalController.text = original;
    _modifiedController.text = modified;
    _suppressControllerEvents = false;
  }

  void _swap() {
    final original = _originalController.text;
    _replaceTexts(_modifiedController.text, original);
    _saveState();
    _compare(immediate: true);
  }

  void _clear() {
    _compareGeneration++;
    _compareTimer?.cancel();
    _replaceTexts('', '');
    setState(() {
      _result = null;
      _isComparing = false;
    });
    _saveState();
  }

  Future<void> _copyPatch() async {
    final l10n = AppLocalizations.of(context)!;
    final patch = TextDiffService.createUnifiedDiff(
      _originalController.text,
      _modifiedController.text,
      originalLabel: l10n.textDiffOriginal,
      modifiedLabel: l10n.textDiffModified,
    );
    if (patch.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: patch));
    if (!mounted) return;
    showLabToast(
      context,
      title: l10n.copySuccess,
      kind: LabStatus.ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final tokens = LabTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.all(tokens.sXl),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final editorHeight =
              (constraints.maxHeight * 0.42).clamp(220.0, 310.0);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(tokens.rLg),
                    ),
                    child: Icon(
                      Icons.difference_outlined,
                      color: scheme.primary,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: tokens.sLg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.navTextDiff,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: tokens.sXxs),
                        Text(
                          l10n.textDiffDescription,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  LabButton(
                    label: l10n.textDiffSwap,
                    icon: Icons.swap_horiz,
                    size: LabButtonSize.sm,
                    onPressed: _isEmpty ? null : _swap,
                  ),
                  SizedBox(width: tokens.sMd),
                  LabButton(
                    label: l10n.clearAction,
                    icon: Icons.clear_all,
                    size: LabButtonSize.sm,
                    variant: LabButtonVariant.ghost,
                    onPressed: _isEmpty ? null : _clear,
                  ),
                ],
              ),
              SizedBox(height: tokens.sLg),
              SizedBox(
                height: editorHeight,
                child: LabSection(
                  title: l10n.navTextDiff,
                  hint: l10n.textDiffDescription,
                  expandBody: true,
                  child: LayoutBuilder(
                    builder: (context, editorConstraints) {
                      final useColumns = editorConstraints.maxWidth >= 620;
                      final originalEditor = _TextDiffEditor(
                        label: l10n.textDiffOriginal,
                        hint: l10n.textDiffOriginalHint,
                        controller: _originalController,
                      );
                      final modifiedEditor = _TextDiffEditor(
                        label: l10n.textDiffModified,
                        hint: l10n.textDiffModifiedHint,
                        controller: _modifiedController,
                      );

                      if (!useColumns) {
                        return Column(
                          children: [
                            Expanded(child: originalEditor),
                            SizedBox(height: tokens.sMd),
                            Expanded(child: modifiedEditor),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: originalEditor),
                          SizedBox(width: tokens.sLg),
                          Expanded(child: modifiedEditor),
                        ],
                      );
                    },
                  ),
                ),
              ),
              SizedBox(height: tokens.sLg),
              Expanded(
                child: LabSection(
                  title: l10n.textDiffResult,
                  padded: false,
                  expandBody: true,
                  trailing: _buildResultActions(context),
                  child: _buildResult(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget? _buildResultActions(BuildContext context) {
    final result = _result;
    if (result == null || _isEmpty) return null;

    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final tokens = LabTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!result.isIdentical) ...[
          LabPill(
            label: '${l10n.textDiffAdded} ${result.addedLines}',
            color: tokens.ok,
            small: true,
          ),
          SizedBox(width: tokens.sXs),
          LabPill(
            label: '${l10n.textDiffRemoved} ${result.removedLines}',
            color: scheme.error,
            small: true,
          ),
          SizedBox(width: tokens.sXs),
          LabPill(
            label: '${l10n.textDiffChanged} ${result.changedLines}',
            color: tokens.warn,
            small: true,
          ),
          SizedBox(width: tokens.sMd),
        ],
        LabButton(
          label: l10n.textDiffCopyPatch,
          icon: Icons.content_copy,
          size: LabButtonSize.sm,
          variant: LabButtonVariant.ghost,
          onPressed: result.isIdentical ? null : _copyPatch,
        ),
      ],
    );
  }

  Widget _buildResult(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_isComparing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_isEmpty || _result == null) {
      return AppEmptyState(
        icon: Icons.compare_arrows,
        message: l10n.textDiffEmpty,
      );
    }
    if (_result!.isIdentical) {
      return AppEmptyState(
        icon: Icons.check_circle_outline,
        message: l10n.textDiffNoChanges,
      );
    }
    return _DiffResultList(result: _result!);
  }
}

class _TextDiffEditor extends StatelessWidget {
  const _TextDiffEditor({
    required this.label,
    required this.hint,
    required this.controller,
  });

  final String label;
  final String hint;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = LabTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: textTheme.labelSmall?.copyWith(color: tokens.faint),
        ),
        SizedBox(height: tokens.sXs),
        Expanded(
          child: TextField(
            controller: controller,
            expands: true,
            minLines: null,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textAlignVertical: TextAlignVertical.top,
            style: textTheme.labelLarge?.copyWith(
              color: scheme.onSurface,
              fontFamily: tokens.monoFamily,
              fontSize: 12.5,
              height: 1.45,
            ),
            decoration: InputDecoration(
              hintText: hint,
              alignLabelWithHint: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _DiffResultList extends StatelessWidget {
  const _DiffResultList({required this.result});

  final TextDiffResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      itemCount: result.rows.length,
      itemBuilder: (context, index) {
        final row = result.rows[index];
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: scheme.outlineVariant),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _DiffCell(
                  lineNumber: row.leftLineNumber,
                  text: row.leftText,
                  kind: row.leftKind,
                  isLeft: true,
                ),
              ),
              Container(width: 1, color: scheme.outline),
              Expanded(
                child: _DiffCell(
                  lineNumber: row.rightLineNumber,
                  text: row.rightText,
                  kind: row.rightKind,
                  isLeft: false,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DiffCell extends StatelessWidget {
  const _DiffCell({
    required this.lineNumber,
    required this.text,
    required this.kind,
    required this.isLeft,
  });

  final int? lineNumber;
  final String? text;
  final TextDiffKind kind;
  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = LabTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final color = _accentColor(scheme, tokens);
    final hasText = text != null;

    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      color: color?.withValues(alpha: hasText ? 0.12 : 0.04),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            constraints: const BoxConstraints(minHeight: 28),
            padding: EdgeInsets.symmetric(
              horizontal: tokens.sMd,
              vertical: tokens.sSm,
            ),
            color: scheme.surfaceContainerLow.withValues(alpha: 0.72),
            alignment: Alignment.topRight,
            child: Text(
              lineNumber?.toString() ?? '',
              style: textTheme.labelSmall?.copyWith(
                color: tokens.faint,
                fontFamily: tokens.monoFamily,
                fontSize: 10,
              ),
            ),
          ),
          SizedBox(
            width: 24,
            child: Padding(
              padding: EdgeInsets.only(top: tokens.sSm),
              child: Text(
                _marker,
                textAlign: TextAlign.center,
                style: textTheme.labelLarge?.copyWith(
                  color: color ?? tokens.faint,
                  fontFamily: tokens.monoFamily,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: tokens.sSm,
                right: tokens.sMd,
                bottom: tokens.sSm,
              ),
              child: SelectableText(
                text ?? '',
                style: textTheme.labelLarge?.copyWith(
                  color: scheme.onSurface,
                  fontFamily: tokens.monoFamily,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color? _accentColor(ColorScheme scheme, LabTokens tokens) {
    return switch (kind) {
      TextDiffKind.unchanged => null,
      TextDiffKind.added => tokens.ok,
      TextDiffKind.removed => scheme.error,
      TextDiffKind.changed => isLeft ? scheme.error : tokens.ok,
    };
  }

  String get _marker {
    return switch (kind) {
      TextDiffKind.unchanged => '',
      TextDiffKind.added => isLeft ? '' : '+',
      TextDiffKind.removed => isLeft ? '-' : '',
      TextDiffKind.changed => isLeft ? '-' : '+',
    };
  }
}
