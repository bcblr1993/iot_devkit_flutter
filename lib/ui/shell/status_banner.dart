import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/status_registry.dart';

class StatusBanner extends StatelessWidget {
  const StatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StatusRegistry>(
      builder: (context, registry, child) {
        final color = registry.color;
        final msg = registry.message;

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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: color),
                      const SizedBox(width: 8),
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
