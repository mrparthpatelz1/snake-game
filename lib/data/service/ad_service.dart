import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';

class AdService extends GetxService {
  RewardedAd? _rewardedAd;
  final RxBool isRewardedAdReady = false.obs;

  // Use test ad unit IDs for development
  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313';
    } else {
      // For non-mobile platforms
      return 'ca-app-pub-3940256099942544/5224354917';
    }
  }

  // Method to load a rewarded ad
  void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          isRewardedAdReady.value = true;
          debugPrint('Rewarded ad loaded.');
        },
        onAdFailedToLoad: (error) {
          isRewardedAdReady.value = false;
          debugPrint('Failed to load a rewarded ad: ${error.message}');
        },
      ),
    );
  }

  // FIXED: Method to show the ad and handle the reward properly
  void showRewardedAd({required VoidCallback onReward}) {
    if (!isRewardedAdReady.value || _rewardedAd == null) {
      debugPrint('Tried to show ad but it was not ready.');
      loadRewardedAd(); // Try to load another one for next time
      return;
    }

    // Track if reward was earned to handle proper game resume
    bool rewardEarned = false;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        isRewardedAdReady.value = false;
        debugPrint('Ad dismissed. Reward earned: $rewardEarned');

        // FIXED: Only call onReward if user actually earned the reward
        if (rewardEarned) {
          onReward();
        }

        loadRewardedAd(); // Pre-load the next ad
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        isRewardedAdReady.value = false;
        debugPrint('Failed to show the ad: $error');
        loadRewardedAd(); // Pre-load the next ad
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        debugPrint('User earned reward: ${reward.amount} ${reward.type}');
        rewardEarned = true;
        // Note: Don't call onReward here immediately, wait for ad dismissal
        // This ensures proper timing and prevents multiple calls
      },
    );
    _rewardedAd = null;
  }
}