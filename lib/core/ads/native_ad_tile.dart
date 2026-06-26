import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';

/// A native ad rendered with the SDK's built-in medium template — no
/// platform-side factory code required. Renders nothing until/unless an ad
/// loads, so it never leaves an empty gap in a feed.
///
/// When [label] is set (e.g. for in-article placement) a small caption is shown
/// above the ad — but only once the ad has actually loaded, so there is never an
/// orphan label hanging over empty space.
class NativeAdTile extends StatefulWidget {
  final String? label;
  const NativeAdTile({super.key, this.label});

  @override
  State<NativeAdTile> createState() => _NativeAdTileState();
}

class _NativeAdTileState extends State<NativeAdTile> {
  NativeAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _ad = NativeAd(
      adUnitId: AdConfig.nativeUnitId,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
      ),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() => _ad = null);
          debugPrint('[Ads] native failed: ${error.message}');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    final ad = Container(
      constraints: const BoxConstraints(minHeight: 300, maxHeight: 360),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AdWidget(ad: _ad!),
    );
    if (widget.label == null) return ad;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            widget.label!.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).hintColor,
            ),
          ),
        ),
        ad,
      ],
    );
  }
}
