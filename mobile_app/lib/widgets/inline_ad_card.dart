import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../ad_config.dart';
import '../theme.dart';

/// A banner-format ad styled to sit inline within the job/news feed, with
/// a small "Ad" label (ad networks require ads to be clearly distinguished
/// from real content). Uses AdMob's banner format rather than its native-ad
/// format — native ads need a platform-specific layout factory registered
/// in Kotlin/Swift outside Flutter, which isn't practical to add (or verify
/// without a real Android/iOS build) for this prototype.
class InlineAdCard extends StatefulWidget {
  const InlineAdCard({super.key});

  @override
  State<InlineAdCard> createState() => _InlineAdCardState();
}

class _InlineAdCardState extends State<InlineAdCard> {
  BannerAd? _ad;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    if (AdConfig.adsSupported) {
      _ad = BannerAd(
        adUnitId: AdConfig.bannerAdUnitId,
        size: AdSize.mediumRectangle,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) => setState(() => _isLoaded = true),
          onAdFailedToLoad: (ad, error) => ad.dispose(),
        ),
      )..load();
    }
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: LedgerColors.inkPanel,
        border: Border.all(color: LedgerColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AD',
            style: TextStyle(color: LedgerColors.slate, fontSize: 10, letterSpacing: 1),
          ),
          const SizedBox(height: 6),
          Center(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (!AdConfig.adsSupported) {
      return Container(
        height: 250,
        alignment: Alignment.center,
        child: const Text(
          'Inline ad slot (Android/iOS only)',
          style: TextStyle(color: LedgerColors.slate, fontSize: 11),
        ),
      );
    }
    if (!_isLoaded || _ad == null) {
      return const SizedBox(height: 250);
    }
    return SizedBox(
      width: _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}
