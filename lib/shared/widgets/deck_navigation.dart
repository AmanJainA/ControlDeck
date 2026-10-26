import 'package:flutter/material.dart';

import '../theme/deck_theme.dart';

/// Reusable side navigation for workspaces with a small fixed menu.
class DeckSideNavigation extends StatelessWidget {
  const DeckSideNavigation({
    super.key,
    required this.selected,
    required this.onSelect,
    this.header = 'WORKSPACE',
    this.footer = 'ONE HUB. YOUR TOOLS.',
    this.width = 220,
    this.items = const [
      DeckNavigationItem(icon: Icons.dashboard_rounded, label: 'Overview'),
      DeckNavigationItem(icon: Icons.account_circle_outlined, label: 'Profile'),
    ],
    this.footerItems = const [
      DeckNavigationItem(icon: Icons.tune_rounded, label: 'Settings'),
    ],
  });

  final String selected;
  final ValueChanged<String> onSelect;
  final String header;
  final String footer;
  final double width;
  final List<DeckNavigationItem> items;
  final List<DeckNavigationItem> footerItems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: theme.dividerColor.withValues(alpha: .35))),
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 12, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 10),
            child: Text(header, style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.4, color: theme.colorScheme.onSurfaceVariant,
            )),
          ),
          for (final item in items) _buildItem(context, item),
          const Spacer(),
          for (final item in footerItems) _buildItem(context, item),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(footer, style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.1, color: theme.colorScheme.onSurfaceVariant,
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, DeckNavigationItem item) {
    final theme = Theme.of(context);
    final isSelected = selected == item.label;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        selected: isSelected,
        selectedTileColor: DeckColors.accent.withValues(alpha: .15),
        leading: Icon(item.icon, size: 20,
          color: isSelected ? DeckColors.accent : theme.colorScheme.onSurfaceVariant),
        title: Text(item.label, style: TextStyle(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        )),
        onTap: () => onSelect(item.label),
      ),
    );
  }
}

/// Immutable navigation item used by [DeckSideNavigation].
class DeckNavigationItem {
  const DeckNavigationItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}
