import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/status_registry.dart';
import '../lab/lab.dart';

class StatusBanner extends StatelessWidget {
  const StatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StatusRegistry>(
      builder: (context, registry, child) {
        final color = Theme.of(context).colorScheme.error;
        final msg = registry.message;
        final tokens = LabTokens.of(context);

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(sizeFactor: animation, child: child),
            );
          },
          child: msg.isEmpty
              ? const SizedBox(key: ValueKey('empty_status'))
              : Container(
                  key: const ValueKey('active_status'),
                  padding: EdgeInsets.symmetric(
                      horizontal: tokens.sLg, vertical: tokens.sMd),
                  margin: EdgeInsets.fromLTRB(
                      tokens.sLg, tokens.sXs, tokens.sLg, tokens.sLg),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(tokens.rLg),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: color),
                      SizedBox(width: tokens.sMd),
                      Expanded(
                        child: Text(
                          msg,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
