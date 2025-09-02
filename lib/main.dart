// lib/main.dart

import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:newer_version_snake/routes/app_pages.dart';

import 'data/service/ad_service.dart';
import 'data/service/settings_service.dart';

void main() async {
  // Ensure Flutter bindings are initialized before running the app.
  WidgetsFlutterBinding.ensureInitialized();
  // await Flame.device.fullScreen();
  MobileAds.instance.initialize();
  await GetStorage.init();
  await SettingsService().init();

  Get.put(AdService()).loadRewardedAd();


  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Using GetMaterialApp to enable GetX routing and state management.
    return GetMaterialApp(
      title: 'Slither.io Clone',
      debugShowCheckedModeBanner: false,
      initialRoute: AppPages.INITIAL, // Set the first screen to show.
      getPages: AppPages.routes,     // Define all the available screens/routes.
      theme: ThemeData(
        fontFamily: 'LuckiestGuy',
      ),
    );
  }
}
