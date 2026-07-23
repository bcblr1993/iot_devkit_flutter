import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../lab/lab.dart';

class VirtualizedTextBlock {
  const VirtualizedTextBlock({
    required this.id,
    required this.text,
    required this.separator,
  });

  final int id;
  final String text;
  final String separator;

  int get sourceLength => text.length + separator.length;
}

class VirtualizedTextController extends ChangeNotifier {
  VirtualizedTextController({
    String text = '',
    this.targetBlockCharacters = 8 * 1024,
    this.maxLinesPerBlock = 120,
  }) {
    replaceAll(text, notify: false);
  }

  final int targetBlockCharacters;
  final int maxLinesPerBlock;

  List<VirtualizedTextBlock> _blocks = const [];
  final Map<int, int> _blockIndexById = {};
  int _length = 0;
  int _nextBlockId = 0;

  List<VirtualizedTextBlock> get blocks => _blocks;

  int get length => _length;

  bool get isEmpty => _length == 0;

  String get text {
    if (_blocks.length == 1) {
      final block = _blocks.single;
      return '${block.text}${block.separator}';
    }
    final buffer = StringBuffer();
    for (final block in _blocks) {
      buffer
        ..write(block.text)
        ..write(block.separator);
    }
    return buffer.toString();
  }

  void replaceAll(String source, {bool notify = true}) {
    _blocks = _split(source);
    _reindexBlocks();
    _length = source.length;
    if (notify) {
      notifyListeners();
    }
  }

  void updateBlock(int id, String value) {
    final index = _blockIndexById[id];
    if (index == null || _blocks[index].text == value) {
      return;
    }
    final previous = _blocks[index];
    _blocks[index] = VirtualizedTextBlock(
      id: previous.id,
      text: value,
      separator: previous.separator,
    );
    _length += value.length - previous.text.length;
  }

  void replaceBlockText(int id, String value) {
    final index = _blockIndexById[id];
    if (index == null) {
      return;
    }
    final previous = _blocks[index];
    final replacementSource = '$value${previous.separator}';
    final replacement = _split(replacementSource);
    _length += replacementSource.length - previous.sourceLength;
    _blocks = [
      ..._blocks.take(index),
      ...replacement,
      ..._blocks.skip(index + 1),
    ];
    _reindexBlocks();
    notifyListeners();
  }

  _MergeTarget? _mergeAtStart(int id) {
    final index = _blockIndexById[id];
    if (index == null || index <= 0) {
      return null;
    }

    final previous = _blocks[index - 1];
    final current = _blocks[index];
    var previousText = previous.text;
    if (previous.separator.isEmpty && previousText.isNotEmpty) {
      previousText = previousText.substring(0, previousText.length - 1);
      _length--;
    } else {
      _length -= previous.separator.length;
    }
    final caretOffset = previousText.length;
    final merged = VirtualizedTextBlock(
      id: previous.id,
      text: '$previousText${current.text}',
      separator: current.separator,
    );
    _blocks = [
      ..._blocks.take(index - 1),
      merged,
      ..._blocks.skip(index + 1),
    ];
    _reindexBlocks();
    notifyListeners();
    return _MergeTarget(merged.id, caretOffset);
  }

  _MergeTarget? _mergeAtEnd(int id) {
    final index = _blockIndexById[id];
    if (index == null || index >= _blocks.length - 1) {
      return null;
    }

    final current = _blocks[index];
    final next = _blocks[index + 1];
    var nextText = next.text;
    if (current.separator.isEmpty && nextText.isNotEmpty) {
      nextText = nextText.substring(1);
      _length--;
    } else {
      _length -= current.separator.length;
    }
    final merged = VirtualizedTextBlock(
      id: current.id,
      text: '${current.text}$nextText',
      separator: next.separator,
    );
    _blocks = [
      ..._blocks.take(index),
      merged,
      ..._blocks.skip(index + 2),
    ];
    _reindexBlocks();
    notifyListeners();
    return _MergeTarget(merged.id, current.text.length);
  }

  void _reindexBlocks() {
    _blockIndexById
      ..clear()
      ..addEntries(
        _blocks.indexed.map((entry) => MapEntry(entry.$2.id, entry.$1)),
      );
  }

  List<VirtualizedTextBlock> _split(String source) {
    if (source.isEmpty) {
      return [
        VirtualizedTextBlock(
          id: _nextBlockId++,
          text: '',
          separator: '',
        ),
      ];
    }

    final result = <VirtualizedTextBlock>[];
    var start = 0;
    while (start < source.length) {
      final hardEnd =
          (start + targetBlockCharacters).clamp(start + 1, source.length);
      var scan = start;
      var lineCount = 0;
      var boundaryTextEnd = -1;
      var boundarySourceEnd = -1;
      var boundarySeparator = '';

      while (scan < hardEnd) {
        final codeUnit = source.codeUnitAt(scan);
        if (codeUnit == 0x0A) {
          final hasCarriageReturn =
              scan > start && source.codeUnitAt(scan - 1) == 0x0D;
          boundaryTextEnd = hasCarriageReturn ? scan - 1 : scan;
          boundarySourceEnd = scan + 1;
          boundarySeparator = hasCarriageReturn ? '\r\n' : '\n';
          lineCount++;
          if (lineCount >= maxLinesPerBlock) {
            break;
          }
        }
        scan++;
      }

      if (boundarySourceEnd > start) {
        result.add(
          VirtualizedTextBlock(
            id: _nextBlockId++,
            text: source.substring(start, boundaryTextEnd),
            separator: boundarySeparator,
          ),
        );
        start = boundarySourceEnd;
        continue;
      }

      final end = hardEnd;
      result.add(
        VirtualizedTextBlock(
          id: _nextBlockId++,
          text: source.substring(start, end),
          separator: '',
        ),
      );
      start = end;
    }
    return result;
  }
}

class LargeJsonTextInputFormatter extends TextInputFormatter {
  LargeJsonTextInputFormatter({
    required this.onLargeText,
    this.maxEditableCharacters = 512 * 1024,
  });

  final ValueChanged<String> onLargeText;
  final int maxEditableCharacters;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length <= maxEditableCharacters) {
      return newValue;
    }

    final largeText = newValue.text;
    scheduleMicrotask(() => onLargeText(largeText));
    return oldValue;
  }
}

class VirtualizedJsonEditor extends StatefulWidget {
  const VirtualizedJsonEditor({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final VirtualizedTextController controller;
  final VoidCallback onChanged;

  @override
  State<VirtualizedJsonEditor> createState() => _VirtualizedJsonEditorState();
}

class _VirtualizedJsonEditorState extends State<VirtualizedJsonEditor> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey<_VirtualTextBlockEditorState>> _blockKeys = {};

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(VirtualizedJsonEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      final activeIds =
          widget.controller.blocks.map((block) => block.id).toSet();
      _blockKeys.removeWhere((id, _) => !activeIds.contains(id));
    });
  }

  void _replaceOversizedBlock(int id, String value) {
    widget.controller.replaceBlockText(id, value);
    widget.onChanged();
  }

  KeyEventResult _handleBoundaryKey(
    int id,
    TextEditingValue value,
    KeyEvent event,
  ) {
    if (event is! KeyDownEvent || !value.selection.isCollapsed) {
      return KeyEventResult.ignored;
    }

    _MergeTarget? target;
    if (event.logicalKey == LogicalKeyboardKey.backspace &&
        value.selection.baseOffset == 0) {
      target = widget.controller._mergeAtStart(id);
    } else if (event.logicalKey == LogicalKeyboardKey.delete &&
        value.selection.baseOffset == value.text.length) {
      target = widget.controller._mergeAtEnd(id);
    }

    if (target == null) {
      return KeyEventResult.ignored;
    }
    widget.onChanged();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _blockKeys[target!.blockId]?.currentState?.requestFocus(target.offset);
    });
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LabTokens.of(context);
    final blocks = widget.controller.blocks;
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(
          horizontal: tokens.sXl,
          vertical: tokens.sLg,
        ),
        // A zero cache extent is intentional. On Windows every off-screen
        // EditableText keeps a native text-input/semantics subtree alive, so
        // prebuilding several large blocks can make the window unresponsive.
        cacheExtent: 0,
        itemCount: blocks.length,
        itemBuilder: (context, index) {
          final block = blocks[index];
          final blockKey = _blockKeys.putIfAbsent(
            block.id,
            () => GlobalKey<_VirtualTextBlockEditorState>(),
          );
          return _VirtualTextBlockEditor(
            key: blockKey,
            block: block,
            onChanged: (value) {
              widget.controller.updateBlock(block.id, value);
              widget.onChanged();
            },
            onOversizedEdit: (value) => _replaceOversizedBlock(block.id, value),
            onBoundaryKey: (value, event) =>
                _handleBoundaryKey(block.id, value, event),
          );
        },
      ),
    );
  }
}

class _VirtualTextBlockEditor extends StatefulWidget {
  const _VirtualTextBlockEditor({
    super.key,
    required this.block,
    required this.onChanged,
    required this.onOversizedEdit,
    required this.onBoundaryKey,
  });

  final VirtualizedTextBlock block;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onOversizedEdit;
  final KeyEventResult Function(TextEditingValue value, KeyEvent event)
      onBoundaryKey;

  @override
  State<_VirtualTextBlockEditor> createState() =>
      _VirtualTextBlockEditorState();
}

class _VirtualTextBlockEditorState extends State<_VirtualTextBlockEditor> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.block.text);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(_VirtualTextBlockEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.block.text == _controller.text) {
      return;
    }
    final offset =
        _controller.selection.baseOffset.clamp(0, widget.block.text.length);
    _controller.value = TextEditingValue(
      text: widget.block.text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void requestFocus(int offset) {
    _focusNode.requestFocus();
    _controller.selection = TextSelection.collapsed(
      offset: offset.clamp(0, _controller.text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = LabTokens.of(context);
    return Focus(
      onKeyEvent: (_, event) => widget.onBoundaryKey(_controller.value, event),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        maxLines: null,
        minLines: 1,
        keyboardType: TextInputType.multiline,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontFamily: tokens.monoFamily,
          fontSize: 13,
          height: 1.35,
        ),
        autocorrect: false,
        enableSuggestions: false,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        scrollPadding: EdgeInsets.zero,
        decoration: const InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          filled: false,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        inputFormatters: [
          _OversizedBlockInputFormatter(
            onOversizedEdit: widget.onOversizedEdit,
          ),
        ],
        onChanged: widget.onChanged,
      ),
    );
  }
}

class _OversizedBlockInputFormatter extends TextInputFormatter {
  _OversizedBlockInputFormatter({
    required this.onOversizedEdit,
  });

  final ValueChanged<String> onOversizedEdit;
  static const int _maxBlockCharacters = 64 * 1024;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length <= _maxBlockCharacters) {
      return newValue;
    }
    final replacement = newValue.text;
    scheduleMicrotask(() => onOversizedEdit(replacement));
    return oldValue;
  }
}

class _MergeTarget {
  const _MergeTarget(this.blockId, this.offset);

  final int blockId;
  final int offset;
}
