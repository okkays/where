import 'dart:async';

import 'package:flutter_background/flutter_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:where/settings.dart';
import 'package:where/store.dart';

final androidBackgroundConfig = FlutterBackgroundAndroidConfig(
  notificationTitle: "Where Location Sharing",
  notificationText: "The Where app is sharing your location in the background.",
  notificationImportance: AndroidNotificationImportance.normal,
  notificationIcon: AndroidResource(
    name: 'background_icon',
    defType: 'drawable',
  ),
  enableWifiLock: false,
);

final _backgroundDuration = Duration(minutes: 15);

Timer? backgroundTimer;

void startSingletonTimer() {
  if (backgroundTimer != null && backgroundTimer!.isActive) return;
  backgroundTimer = Timer.periodic(_backgroundDuration, (timer) async {
    final settings = await Settings.getSingleton();
    print('Uploading in background ${settings.background}...');
    if (!settings.background) return;

    final store = await Store.fromSettings();
    if (store == null) return;
    await store.upload(fresh: false);
    print('Uploaded!');
  });
}

Future<void> startBackground() async {
  if (FlutterBackground.isBackgroundExecutionEnabled) return; // already running

  print('Starting background service...');
  final settings = await Settings.getSingleton();
  if (!settings.background) return;
  print('Background setting enabled');
  if (!await FlutterBackground.hasPermissions) return;
  print('Has background permissions');
  if (!await Permission.location.isGranted) return;
  print('Has location permissions');

  final granted = await FlutterBackground.initialize(
    androidConfig: androidBackgroundConfig,
  );
  if (!granted) return;
  print('Initialized background');

  await FlutterBackground.enableBackgroundExecution();
  print('Enabled background');
}
