import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import 'package:iot_devkit/utils/platform_ui_helper.dart';
import 'version_helper.dart';

/// Utility class for displaying the About dialog across all platforms.
class AboutDialogHelper {
  /// Shows the About dialog with app info, author, and version details.
  static Future<void> showAboutDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final version = await VersionHelper.getAppVersion();
    
    if (!context.mounted) return;
    
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark 
                  ? [
                      theme.colorScheme.surface,
                      theme.colorScheme.surface.withOpacity(0.95),
                    ]
                  : [
                      Colors.white,
                      primaryColor.withOpacity(0.03),
                    ],
              ),
              boxShadow: PlatformUIHelper.optimizeShadows([
                BoxShadow(
                  color: primaryColor.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App Icon with decorative background
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          primaryColor.withOpacity(0.1),
                          primaryColor.withOpacity(0.05),
                        ],
                      ),
                      boxShadow: PlatformUIHelper.optimizeShadows([
                        BoxShadow(
                          color: primaryColor.withOpacity(0.2),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ]),
                    ),
                    child: Image.asset(
                      'assets/icon/original_icon.png',
                      width: 80,
                      height: 80,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // App Title
                  Text(
                    'IoT DevKit',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Version
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'v$version',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Release Date
                  Text(
                    '${l10n.releaseDate}: 2025-12-23',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  Divider(color: theme.colorScheme.onSurface.withOpacity(0.1)),
                  const SizedBox(height: 24),
                  
                  // Author
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_rounded,
                        size: 18,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${l10n.author}: ',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      Text(
                        l10n.authorName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Description
                  Text(
                    l10n.aboutDescription,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  Divider(color: theme.colorScheme.onSurface.withOpacity(0.1)),
                  const SizedBox(height: 16),
                  
                  // Footer
                  Text(
                    l10n.aboutFooter,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Close Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        l10n.close,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
