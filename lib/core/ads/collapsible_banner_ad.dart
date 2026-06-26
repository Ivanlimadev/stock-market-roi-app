import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';

/// An anchored adaptive **collapsible** banner — it loads expanded and the user
/// can collapse it to a slim bar, which earns a materially higher eCPM than a
/// plain anchored banner. Designed to sit just above a bottom navigation bar.
///
/// Renders nothing until an ad loads, so it never leaves an empty gap.
class CollapsibleBannerAd extends StatefulWidget {
  const CollapsibleBannerAd({super.key});

  @override
  State<CollapsibleBannerAd> createState() => _CollapsibleBannerAdState();
}

class _CollapsibleBannerAdState extends State<CollapsibleBannerAd> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    // Needs the screen width for the adaptive size — defer to the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final width = MediaQuery.of(context).size.width.truncate();
    final size =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    if (size == null || !mounted) return;

    final ad = BannerAd(
      adUnitId: AdConfig.bannerUnitId,
      size: size,
      // 'collapsible' makes this an expandable/collapsible banner.
      request: const AdRequest(extras: {'collapsible': 'bottom'}),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('[Ads] banner failed: ${error.message}');
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      height: ad.size.height.toDouble(),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}
