import 'package:flutter/material.dart';

import '../theme/deck_theme.dart';

/// Shared hero header for native workspaces and feature landing pages.
class DeckWorkspaceHero extends StatelessWidget {
  const DeckWorkspaceHero({super.key, required this.title, required this.subtitle, required this.icon});
  final String title;
  final String subtitle;
  /// Accepts Material IconData or a widget icon (for example, Font Awesome).
  final Object icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = DeckColors.accent;
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(colors: [accent.withValues(alpha: .18), theme.colorScheme.surfaceContainerHighest]),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 54, height: 54,
          decoration: BoxDecoration(color: accent.withValues(alpha: .18), borderRadius: BorderRadius.circular(16)),
          child: icon is IconData
              ? Icon(icon as IconData, color: accent, size: 28)
              : IconTheme(data: IconThemeData(color: accent, size: 28), child: icon as Widget),
        ),
        const SizedBox(height: 18),
        Text(title, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(subtitle, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ]),
    );
  }
}
