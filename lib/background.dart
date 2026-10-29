import 'package:flutter_background/flutter_background.dart';

final androidBackgroundConfig = FlutterBackgroundAndroidConfig(
  notificationTitle: "Where Location Sharing",
  notificationText: "The Where app is sharing your location in the background.",
  notificationImportance: AndroidNotificationImportance.normal,
  notificationIcon: AndroidResource(
    name: 'background_icon',
    defType: 'drawable',
  ),
);
