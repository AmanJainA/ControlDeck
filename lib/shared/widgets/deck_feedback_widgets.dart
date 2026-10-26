import 'package:flutter/material.dart';

import '../theme/deck_theme.dart';
import 'deck_components.dart';

/// Reusable informational notice for inline guidance and non-blocking feedback.
class DeckNotice extends StatelessWidget {
  const DeckNotice({super.key, required this.text, required this.icon});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 19, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant, height: 1.4))),
      ]),
    );
  }
}

/// Reusable connection/error panel with an optional retry action.
class DeckConnectionNotice extends StatelessWidget {
  const DeckConnectionNotice({super.key, required this.title, required this.detail, this.onRetry});
  final String title;
  final String detail;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 540),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: DeckCard(
          margin: EdgeInsets.zero,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.cloud_off_rounded, color: DeckColors.accent, size: 34),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(detail, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(onPressed: () => onRetry?.call(), icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
            ],
          ]),
        ),
      ),
    ),
  );
}

/// Empty state for the launcher, reusable when a filter returns no apps.
class DeckLauncherEmptyState extends StatelessWidget {
  const DeckLauncherEmptyState({super.key});
  @override
  Widget build(BuildContext context) => const DeckEmptyState(
    title: 'Nothing here yet',
    detail: 'No apps are available to display.',
    icon: Icons.widgets_outlined,
  );
}
