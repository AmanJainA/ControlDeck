import 'package:flutter/material.dart';

/// Consistent max-width and page padding for responsive workspace pages.
class DeckPageContainer extends StatelessWidget {
  const DeckPageContainer({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.padding = const EdgeInsets.all(20),
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => Align(
    alignment: alignment,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(padding: padding, child: child),
    ),
  );
}

/// Responsive grid that adapts its column count to the available width.
class DeckResponsiveGrid extends StatelessWidget {
  const DeckResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 220,
    this.maxColumns = 4,
    this.spacing = 12,
    this.runSpacing = 12,
    this.childAspectRatio = 1.2,
    this.itemExtent,
    this.padding = EdgeInsets.zero,
  });

  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;
  final double spacing;
  final double runSpacing;
  final double childAspectRatio;
  final double? itemExtent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = (constraints.maxWidth / (minItemWidth + spacing))
          .floor()
          .clamp(1, maxColumns)
          .toInt();
      return GridView.builder(
        padding: padding,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: children.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: runSpacing,
          crossAxisSpacing: spacing,
          mainAxisExtent: itemExtent,
          childAspectRatio: itemExtent == null ? childAspectRatio : 1,
        ),
        itemBuilder: (context, index) => children[index],
      );
    },
  );
}
