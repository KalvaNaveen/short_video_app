package com.example.short_video_app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin


class MainActivity: FlutterFragmentActivity() {
    
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GoogleMobileAdsPlugin.registerNativeAdFactory(flutterEngine, "listTile", ListTileNativeAdFactory(this))
}
 override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
    GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "listTile")
    super.cleanUpFlutterEngine(flutterEngine)
  }

}