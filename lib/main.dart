import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:go_router/go_router.dart';

import './landing_page.dart';
import './map_page.dart';
import './sharing_page.dart';
import './permissions_page.dart';

import './keys.dart';

void main() async {
  runApp(const WhereApp());

  final androidConfig = FlutterBackgroundAndroidConfig(
    notificationTitle: "Where Location Sharing",
    notificationText:
        "The Where app is sharing your location in the background.",
    notificationImportance: AndroidNotificationImportance.normal,
    notificationIcon: AndroidResource(
      name: 'background_icon',
      defType: 'drawable',
    ),
  );
  await FlutterBackground.initialize(androidConfig: androidConfig);
}

class WhereApp extends StatelessWidget {
  const WhereApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Where Location Sharing',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.lightBlue)),
      routerConfig: GoRouter(
        debugLogDiagnostics: true,
        initialLocation: '/',
        routes: [
          ShellRoute(
            builder: (BuildContext context, GoRouterState state, Widget child) {
              return BackButtonListener(
                onBackButtonPressed: () {
                  if (dialogKey.currentContext != null ||
                      subDialogKey.currentContext != null) {
                    Navigator.of(context).pop();
                    return Future.value(true);
                  }
                  var path = GoRouterState.of(context).fullPath;
                  if (path != '/' && path != null) {
                    var pathPieces = path.split('/');
                    var root = pathPieces
                        .sublist(0, pathPieces.length - 1)
                        .join('/');
                    context.go(root);
                    return Future.value(true);
                  }
                  return Future.value(false);
                },
                child: Scaffold(
                  resizeToAvoidBottomInset: false,
                  appBar: PreferredSize(
                    preferredSize: const Size(double.infinity, kToolbarHeight),
                    child: AppBar(
                      leading: IconButton(
                        key: const Key('main.home'),
                        onPressed: () {
                          context.go('/');
                        },
                        icon: const Icon(Icons.home),
                      ),
                      title: Text('Where Location Sharing'),
                    ),
                  ),
                  body: child,
                ),
              );
            },
            routes: <RouteBase>[
              GoRoute(
                path: '/',
                builder: (context, state) => const LandingPage(),
              ),
              GoRoute(
                path: '/map',
                builder: (context, state) => const MapPage(),
              ),
              GoRoute(
                path: '/sharing',
                builder: (context, state) => const SharingPage(),
              ),
              GoRoute(
                path: '/permissions',
                builder: (context, state) => const PermissionsPage(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
