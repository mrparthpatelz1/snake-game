// lib/main.dart

import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:newer_version_snake/routes/app_pages.dart';

import 'data/service/ad_service.dart';
import 'data/service/audio_service.dart';
import 'data/service/haptic_service.dart';
import 'data/service/settings_service.dart';

void main() async {
  // Ensure Flutter bindings are initialized before running the app.
  WidgetsFlutterBinding.ensureInitialized();
  // await Flame.device.fullScreen();
  MobileAds.instance.initialize();
  await GetStorage.init();
  await SettingsService().init();

  // 🔧 IMPROVED: Better audio service initialization
  await Get.putAsync<AudioService>(() async => AudioService());
  await Get.putAsync<HapticService>(() async => HapticService());


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
    // A reusable ButtonStyle that disables feedback and splash for M3 buttons.
    final ButtonStyle _noFeedbackButtonStyle = ButtonStyle(
      enableFeedback: false,
      splashFactory: NoSplash.splashFactory,
    );

    return GetMaterialApp(
      title: 'Slither.io Clone',
      debugShowCheckedModeBanner: false,
      initialRoute: AppPages.INITIAL,
      getPages: AppPages.routes,

      theme: ThemeData(
        fontFamily: 'LuckiestGuy',
        useMaterial3: true,

        // Remove ripple visuals and related ink splash everywhere by default
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,

        // Buttons (Elevated, Text, Outlined) - disable acoustic/haptic feedback
        elevatedButtonTheme:
        ElevatedButtonThemeData(style: _noFeedbackButtonStyle),
        textButtonTheme: TextButtonThemeData(style: _noFeedbackButtonStyle),
        outlinedButtonTheme:
        OutlinedButtonThemeData(style: _noFeedbackButtonStyle),

        // IconButton (Material 3 uses ButtonStyle)
        iconButtonTheme: IconButtonThemeData(style: _noFeedbackButtonStyle),

        // FloatingActionButton - theme has enableFeedback
        floatingActionButtonTheme:
        const FloatingActionButtonThemeData(enableFeedback: false),

        // ListTile, Tooltip (disable feedback via theme)
        listTileTheme: const ListTileThemeData(enableFeedback: false),
        tooltipTheme: const TooltipThemeData(enableFeedback: false),

        // Other theme tweaks as needed...
      ),

      // builder kept simple (no MediaQuery.copyWith for a property that doesn't exist)
      builder: (context, child) {
        return child!;
      },
    );
  }
}

