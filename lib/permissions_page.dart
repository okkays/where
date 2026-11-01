import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:where/background.dart';
import 'package:where/settings.dart';

const successIcon = Icon(Icons.check_circle, color: Colors.green, size: 30);
const errorIcon = Icon(Icons.error_outline, color: Colors.red, size: 30);
const pendingIcon = Icon(Icons.change_circle, color: Colors.orange, size: 30);
const offIcon = Icon(Icons.toggle_off, color: Colors.red, size: 30);
const onIcon = Icon(Icons.toggle_on, color: Colors.green, size: 30);

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
    if (await FlutterBackground.hasPermissions) {
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

    icon = successIcon;
    notifyListeners();
    return true;
  }

  _BackgroundAction({required super.title, required super.subtitle}) : super() {
    FlutterBackground.hasPermissions.then((isGranted) {
      super.icon = isGranted ? successIcon : errorIcon;
      notifyListeners();
    });
  }
}

class _ToggleService extends _Action {
  @override
  request(BuildContext context) async {
    final settings = await Settings.getSingleton();

    if (!(await FlutterBackground.hasPermissions)) {
      icon = offIcon;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Enable permissions above first')),
        );
      }
      notifyListeners();
      print('No permissions, disabling background');
      return false;
    }

    if (FlutterBackground.isBackgroundExecutionEnabled) {
      await FlutterBackground.disableBackgroundExecution();
      icon = offIcon;
      notifyListeners();
      settings.background = false;
      await settings.save();
      print('Toggling off background');
      return false;
    }

    final initialized = await FlutterBackground.initialize();
    if (!initialized) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Unable to initialize plugin.')),
        );
      }
      print('Background failed initialize');
      return false;
    }
    final enabled = await FlutterBackground.enableBackgroundExecution();

    if (!enabled) {
      icon = errorIcon;
      notifyListeners();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Something went wrong...')),
        );
      }
      print('Background failed enable');
      return false;
    }

    icon = onIcon;
    notifyListeners();
    settings.background = true;
    await settings.save();
    startSingletonTimer();
    return true;
  }

  _ToggleService({required super.title, required super.subtitle}) : super() {
    icon = FlutterBackground.isBackgroundExecutionEnabled ? onIcon : offIcon;
    notifyListeners();
  }
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
      subtitle: 'To map and share your location',
    ),
    _PermissionAction(
      permission: Permission.locationAlways,
      title: 'Location always',
      subtitle: 'For all-the-time sharing',
    ),
    _BackgroundAction(
      title: 'Background permission',
      subtitle: 'Permission to keep the app running always',
    ),
    _ToggleService(
      title: 'Background service',
      subtitle: 'Start/stop background sharing',
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
            Expanded(
              child: Column(
                mainAxisSize: .min,
                crossAxisAlignment: .start,
                children: [
                  FittedBox(
                    fit: .scaleDown,
                    alignment: .bottomStart,
                    child: Text(
                      permission.title,
                      style: TextTheme.of(context).headlineSmall!
                          .copyWith(color: ColorScheme.of(context).primary),
                    ),
                  ),
                  FittedBox(
                    fit: .scaleDown,
                    alignment: .topStart,
                    child: Text(
                      permission.subtitle,
                      style: TextTheme.of(context).labelMedium!
                          .copyWith(color: ColorScheme.of(context).primary),
                    ),
                  ),
                ],
              ),
            ),
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
            Column(
              children: [
                Text(
                  "ℹ️ Once enabled, background location will be uploaded every 15 minutes. This might not happen if the phone doesn't have internet access, is on battery saver mode, etc.",
                ),
                Text(
                  "You can also send a manual, fresh location update by going to the Map page and choosing the cloud upload icon.",
                ),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
