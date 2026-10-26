import 'package:flutter/material.dart';

/// Shared spacing scale for consistent layouts across ControlDeck workspaces.
abstract final class DeckSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double cardGap = 5;
}

/// Reusable surface for workspace cards. Keep spacing and surface styling in one place.
class DeckCard extends StatelessWidget {
  const DeckCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: DeckSpacing.cardGap),
    this.color,
    this.onTap,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final VoidCallback? onTap;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Card(
      margin: margin,
      color: color,
      clipBehavior: clipBehavior,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// Consistent page/workspace hero with configurable brand colors.
class DeckPageHero extends StatelessWidget {
  const DeckPageHero({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.gradientColors,
    this.iconColor,
    this.padding = const EdgeInsets.all(20),
    this.horizontal = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color>? gradientColors;
  final Color? iconColor;
  final EdgeInsetsGeometry padding;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final colors = gradientColors ??
        <Color>[
          const Color(0xFF8FA600).withValues(alpha: .18),
          Theme.of(context).colorScheme.surfaceContainerHighest,
        ];
    final foreground = iconColor ?? Theme.of(context).colorScheme.onSurface;
    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: horizontal ? Colors.white : null,
        );
    final subtitleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          height: 1.4,
          color: horizontal ? Colors.white70 : null,
        );
    final iconWidget = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: horizontal
            ? Colors.white.withValues(alpha: .13)
            : foreground.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: foreground, size: 28),
    );
    final textContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: titleStyle),
        const SizedBox(height: 6),
        Text(subtitle, style: subtitleStyle),
      ],
    );
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: horizontal
          ? Row(
              children: [
                iconWidget,
                const SizedBox(width: 14),
                Expanded(child: textContent),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                iconWidget,
                const SizedBox(height: 12),
                textContent,
              ],
            ),
    );
  }
}

/// Shared metric tile for dashboards and summary screens.
class DeckMetricCard extends StatelessWidget {
  const DeckMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.iconColor,
    this.margin = const EdgeInsets.only(bottom: DeckSpacing.cardGap),
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? iconColor;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? Theme.of(context).colorScheme.primary;
    return DeckCard(
      margin: margin,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 27),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 5),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable titled information card for details and report summaries.
class DeckInfoCard extends StatelessWidget {
  const DeckInfoCard({
    super.key,
    required this.title,
    required this.body,
    this.icon,
    this.margin = const EdgeInsets.only(bottom: DeckSpacing.cardGap),
    this.selectable = false,
  });

  final String title;
  final String body;
  final IconData? icon;
  final EdgeInsetsGeometry? margin;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final titleWidget = Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );
    final bodyWidget = selectable
        ? SelectableText(body, style: const TextStyle(height: 1.5))
        : Text(body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45));
    return DeckCard(
      margin: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Row(
              children: [
                Icon(icon, color: const Color(0xFF8FA600)),
                const SizedBox(width: 8),
                Expanded(child: titleWidget),
              ],
            ),
            const SizedBox(height: 10),
          ] else ...[
            titleWidget,
            const SizedBox(height: 6),
          ],
          bodyWidget,
        ],
      ),
    );
  }
}

/// Consistent empty state with a clear title and next-step explanation.
class DeckEmptyState extends StatelessWidget {
  const DeckEmptyState({
    super.key,
    required this.title,
    required this.detail,
    this.icon = Icons.inbox_outlined,
  });

  final String title;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// A consistent section heading for forms, lists and dashboard groups.
class DeckSectionTitle extends StatelessWidget {
  const DeckSectionTitle({
    super.key,
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      );
}
