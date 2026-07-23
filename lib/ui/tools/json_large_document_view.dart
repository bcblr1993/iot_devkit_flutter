import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../lab/lab.dart';

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

class LargeJsonDocumentPreview extends StatelessWidget {
  const LargeJsonDocumentPreview({
    super.key,
    required this.content,
    required this.title,
    required this.description,
    this.previewLineLimit = 400,
    this.previewCharacterLimit = 4 * 1024,
  });

  final String content;
  final String title;
  final String description;
  final int previewLineLimit;
  final int previewCharacterLimit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = LabTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: theme.colorScheme.surfaceContainerHighest,
          padding: EdgeInsets.all(tokens.sLg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.article_outlined,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              SizedBox(width: tokens.sMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: tokens.sXxs),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(tokens.sXl),
            child: Text(
              _preview(
                content,
                lineLimit: previewLineLimit,
                characterLimit: previewCharacterLimit,
              ),
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontFamily: tokens.monoFamily,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _preview(
    String content, {
    required int lineLimit,
    required int characterLimit,
  }) {
    if (content.isEmpty || lineLimit <= 0 || characterLimit <= 0) {
      return '';
    }

    final scanLength =
        content.length < characterLimit ? content.length : characterLimit;
    var lines = 0;
    for (var index = 0; index < scanLength; index++) {
      if (content.codeUnitAt(index) != 0x0A) {
        continue;
      }
      lines++;
      if (lines == lineLimit) {
        return content.substring(0, index);
      }
    }
    return content.substring(0, scanLength);
  }
}
