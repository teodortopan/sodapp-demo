import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'database/app_database.dart';
import 'screens/splash_screen.dart';
import 'services/banner_service.dart';
import 'utils/app_tokens.dart';
import 'utils/logical_clock.dart';
import 'utils/theme_controller.dart';
import 'widgets/web_phone_frame.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  LogicalClock.warmUp();
  unawaited(AppDatabase.instance.recomputeClientesWithExpiringRows());
  BannerService.instance.bindNavigatorKey(appNavigatorKey);

  final mobileController = await MobileThemeController.bootstrap();
  runApp(SodappDemo(themeController: mobileController));
}

class SodappDemo extends StatelessWidget {
  final MobileThemeController themeController;

  const SodappDemo({super.key, required this.themeController});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        final brightness = themeController.brightness;
        return AppTheme(
          controller: themeController,
          child: MaterialApp(
            navigatorKey: appNavigatorKey,
            navigatorObservers: [BannerService.instance.routeObserver],
            title: 'SODAPP Demo',
            debugShowCheckedModeBanner: false,
            locale: const Locale('es', 'AR'),
            supportedLocales: const [Locale('es', 'AR')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData(
              brightness: Brightness.light,
              fontFamily: 'Roboto',
              scaffoldBackgroundColor: AppTokens.light().bg,
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              fontFamily: 'Roboto',
              scaffoldBackgroundColor: AppTokens.dark().bg,
            ),
            themeMode: brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            builder: (context, child) {
              final mediaQuery = MediaQuery.of(context);
              final clampedScaler = mediaQuery.textScaler.clamp(
                minScaleFactor: 1.0,
                maxScaleFactor: 1.35,
              );
              return MediaQuery(
                data: mediaQuery.copyWith(textScaler: clampedScaler),
                child: WebPhoneFrame(child: child!),
              );
            },
            home: const SplashScreen(),
          ),
        );
      },
    );
  }
}
