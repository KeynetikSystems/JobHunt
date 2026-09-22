import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../ad_config.dart';
import '../theme.dart';

/// Persistent banner ad, meant to be pinned at the bottom of a screen.
/// On platforms the google_mobile_ads plugin doesn't support (web, desktop),
/// this renders a labeled placeholder instead, so the layout is still
/// visible while developing outside a real Android/iOS target.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    if (AdConfig.adsSupported) {
      _bannerAd = BannerAd(
        adUnitId: AdConfig.bannerAdUnitId,
        size: AdSize.banner,
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
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!AdConfig.adsSupported) {
      return Container(
        height: 50,
        alignment: Alignment.center,
        color: theme.colorScheme.surface,
        child: Text(
          'Banner ad (Android/iOS only)',
          style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 11),
        ),
      );
    }
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox(height: 50);
    }
    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
