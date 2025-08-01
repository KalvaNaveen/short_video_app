import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager extends StatefulWidget {
  final String bannerAdUnitId;
  final String nativeAdUnitId;
  final String rewardedInterstitialAdUnitId;

  final double bannerHeight;

  const AdManager({
    Key? key,
    required this.bannerAdUnitId,
    required this.nativeAdUnitId,
    required this.rewardedInterstitialAdUnitId,
    this.bannerHeight = 50,
  }) : super(key: key);

  @override
  _AdManagerState createState() => _AdManagerState();

  static _AdManagerState? of(BuildContext context) =>
      context.findAncestorStateOfType<_AdManagerState>();
}

class _AdManagerState extends State<AdManager> {
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  NativeAd? _nativeAd;
  bool _isNativeLoaded = false;

  RewardedInterstitialAd? _rewardedInterstitialAd;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    _loadNativeAd();
    _loadRewardedInterstitialAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: widget.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() => _isBannerLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('BannerAd failed to load: $error');
          setState(() => _isBannerLoaded = false);
        },
      ),
    );
    _bannerAd?.load();
  }

  Widget bannerAdWidget() {
    if (_isBannerLoaded && _bannerAd != null) {
      return SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: widget.bannerHeight,
        child: AdWidget(ad: _bannerAd!),
      );
    }
    return SizedBox(height: widget.bannerHeight);
  }

  void _loadNativeAd() {
    _nativeAd = NativeAd(
      adUnitId: widget.nativeAdUnitId,
      factoryId: 'listTile', // Your platform-side factory name
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) => setState(() => _isNativeLoaded = true),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('NativeAd failed to load: $error');
          setState(() => _isNativeLoaded = false);
        },
      ),
    );
    _nativeAd?.load();
  }

  Widget nativeAdWidget({double height = 80}) {
    if (_isNativeLoaded && _nativeAd != null) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: AdWidget(ad: _nativeAd!),
      );
    }
    return SizedBox(height: height);
  }

  void _loadRewardedInterstitialAd() {
    RewardedInterstitialAd.load(
      adUnitId: widget.rewardedInterstitialAdUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedInterstitialAd = ad;
          debugPrint('RewardedInterstitialAd loaded');
        },
        onAdFailedToLoad: (error) {
          debugPrint('Failed to load RewardedInterstitialAd: $error');
          _rewardedInterstitialAd = null;
        },
      ),
    );
  }

  Future<bool> showRewardedInterstitialAd(BuildContext context) async {
    if (_rewardedInterstitialAd == null) {
      debugPrint('RewardedInterstitialAd not ready yet');
      return false;
    }

    final completer = Completer<bool>();

    _rewardedInterstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadRewardedInterstitialAd(); // Load next
        if (!completer.isCompleted) completer.complete(false);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadRewardedInterstitialAd();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    _rewardedInterstitialAd!.show(
      onUserEarnedReward: (ad, reward) {
        if (!completer.isCompleted) completer.complete(true);
      },
    );
    _rewardedInterstitialAd = null;
    return completer.future;
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _nativeAd?.dispose();
    _rewardedInterstitialAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
