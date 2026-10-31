import 'package:flutter_background/flutter_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:where/settings.dart';

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

Future<void> runInBackground() async {
  final settings = await Settings.getSingleton();

  if (!settings.background) return;

  if (await FlutterBackground.hasPermissions &&
      await Permission.location.isGranted) {
    final granted = await FlutterBackground.initialize(
      androidConfig: androidBackgroundConfig,
    );
    if (granted && !FlutterBackground.isBackgroundExecutionEnabled) {
      await FlutterBackground.enableBackgroundExecution();
    }
  }
}
