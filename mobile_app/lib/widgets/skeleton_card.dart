import 'package:flutter/material.dart';
import '../theme.dart';

/// Placeholder shown in place of a JobCard/NewsCard while a search is in
/// flight and nothing has loaded yet, so a multi-second live Tavily+Groq
/// round trip reads as "working" rather than "did this do anything?".
class SkeletonCard extends StatefulWidget {
  const SkeletonCard({super.key});

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _bar(double width, double height) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.3 + _controller.value * 0.3,
          child: child,
        );
      },
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: LedgerColors.slate,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: LedgerColors.inkPanel,
        border: Border.all(color: LedgerColors.hairline),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: LedgerColors.hairline),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bar(double.infinity, 14),
                    const SizedBox(height: 8),
                    _bar(140, 11),
                    const SizedBox(height: 8),
                    _bar(double.infinity, 12),
                    const SizedBox(height: 4),
                    _bar(200, 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
