import 'package:flutter/material.dart';

import '../../features/apps/models/deck_app.dart';
import 'deck_components.dart';

/// Reusable launcher tile. Feature-specific icon selection is injected by the caller.
class DeckAppCard extends StatelessWidget {
  const DeckAppCard({super.key, required this.app, required this.icon, required this.onOpen});
  final DeckApp app;
  final Widget icon;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = Color(app.accentHex);
    return DeckCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      onTap: onOpen,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 42, height: 42, alignment: Alignment.center,
          decoration: BoxDecoration(color: tint.withValues(alpha: .15), borderRadius: BorderRadius.circular(13)),
          child: IconTheme(data: IconThemeData(color: tint, size: 23), child: icon),
        ),
        const SizedBox(height: 8),
        Text(app.name, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(app.description.isEmpty ? 'Open this workspace inside ControlDeck.' : app.description,
          maxLines: 2, overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.3)),
      ]),
    );
  }
}
