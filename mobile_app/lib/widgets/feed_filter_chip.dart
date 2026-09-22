import 'package:flutter/material.dart';
import '../theme.dart';

/// A tappable All/Jobs/News-style filter chip, styled to match the Ledger theme.
/// Shared between Dashboard and History so both feeds filter identically.
class FeedFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const FeedFilterChip({super.key, required this.label, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: selected ? theme.colorScheme.onSecondary : theme.colorScheme.onSurface,
        ),
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surface,
      side: BorderSide(color: theme.colorScheme.outline),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
