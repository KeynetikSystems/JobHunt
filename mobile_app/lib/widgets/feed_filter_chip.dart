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
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(fontSize: 11, color: selected ? LedgerColors.inkBg : LedgerColors.parchment),
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: LedgerColors.brass,
      backgroundColor: LedgerColors.inkPanel,
      side: const BorderSide(color: LedgerColors.hairline),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
