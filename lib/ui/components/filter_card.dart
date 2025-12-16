import 'package:flutter/material.dart';
import 'app_spacing.dart';

class FilterCard extends StatelessWidget {
  const FilterCard({
    super.key,
    required this.title,
    required this.children,
    this.actions,
    this.padding = const EdgeInsets.all(Gaps.md),
    this.gap = Gaps.sm,
  });

  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  final EdgeInsets padding;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (actions != null) ...actions!,
              ],
            ),
            SizedBox(height: gap),
            ...[
              Wrap(
                spacing: Gaps.sm,
                runSpacing: Gaps.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: children,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
