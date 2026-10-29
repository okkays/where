import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:where/background.dart';

const successIcon = Icon(Icons.check_circle, color: Colors.green, size: 30);
const errorIcon = Icon(Icons.error_outline, color: Colors.red, size: 30);
const pendingIcon = Icon(Icons.change_circle, color: Colors.orange, size: 30);

abstract class _Action extends ChangeNotifier {
  final String title;
  final String subtitle;

  Icon icon;

  _Action({
    required this.title,
    required this.subtitle,
    this.icon = pendingIcon,
  });

  Future<bool> request(BuildContext context);
}

class _PermissionAction extends _Action {
  final Permission permission;

  @override
  request(BuildContext context) async {
    if (await permission.isGranted) {
      openAppSettings();
      return true;
    }
    final result = await permission.request();
    icon = result.isGranted ? successIcon : errorIcon;
    return result.isGranted;
  }

  _PermissionAction({
    required this.permission,
    required super.title,
    required super.subtitle,
  }) : super() {
    permission.isGranted.then((isGranted) {
      super.icon = isGranted ? successIcon : errorIcon;
      notifyListeners();
    });
  }
}

class _BackgroundAction extends _Action {
  @override
  request(BuildContext context) async {
    if ((await FlutterBackground.hasPermissions) &&
        FlutterBackground.isBackgroundExecutionEnabled) {
      openAppSettings();
      return true;
    }
    final granted = await FlutterBackground.initialize(
      androidConfig: androidBackgroundConfig,
    );
    if (!granted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Permission not granted 😔')),
        );
      }
      icon = errorIcon;
      notifyListeners();
      return false;
    }
    bool enabled = FlutterBackground.isBackgroundExecutionEnabled;
    if (!enabled) {
      enabled = await FlutterBackground.enableBackgroundExecution();
    }
    if (enabled) {
      icon = successIcon;
      notifyListeners();
      return true;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('❗️Unable to start in background')),
      );
    }
    icon = errorIcon;
    notifyListeners();
    return false;
  }

  _BackgroundAction({required super.title, required super.subtitle})
    : super(
        icon: FlutterBackground.isBackgroundExecutionEnabled
            ? successIcon
            : errorIcon,
      );
}

class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  State<StatefulWidget> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  final List<_Action> allPermissions = [
    _PermissionAction(
      permission: Permission.location,
      title: 'Location',
      subtitle: 'To map and share',
    ),
    _PermissionAction(
      permission: Permission.locationAlways,
      title: 'Background location',
      subtitle: 'To get location to share',
    ),
    _BackgroundAction(
      title: 'Run in background',
      subtitle: 'To send shared location',
    ),
  ];

  late final AppLifecycleListener appLifecycleListener;

  @override
  void initState() {
    appLifecycleListener = AppLifecycleListener(
      onResume: () {
        setState(() {});
      },
    );
    super.initState();
  }

  Widget buildPermission(BuildContext context, _Action permission) {
    return Expanded(
      flex: 1,
      child: ElevatedButton(
        key: Key('permissions.${permission.title}'),
        onPressed: () async {
          final result = await permission.request(context);
          if (!result) {}
        },
        child: Row(
          mainAxisAlignment: .start,
          crossAxisAlignment: .center,
          spacing: 10,
          children: [
            Padding(
              padding: EdgeInsetsGeometry.fromLTRB(10, 0, 10, 0),
              child: ListenableBuilder(
                listenable: permission,
                builder: (context, widget) => permission.icon,
              ),
            ),
            const VerticalDivider(width: 1),
            Column(
              mainAxisSize: .min,
              crossAxisAlignment: .start,
              children: [
                Text(
                  permission.title,
                  style: TextTheme.of(context).headlineSmall!
                      .copyWith(color: ColorScheme.of(context).primary),
                ),
                Text(
                  permission.subtitle,
                  style: TextTheme.of(context).labelMedium!
                      .copyWith(color: ColorScheme.of(context).primary),
                ),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsetsGeometry.only(left: 20, right: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          spacing: 40,
          children: [
            const Spacer(),
            ...allPermissions.map((p) => buildPermission(context, p)),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
