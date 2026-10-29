import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:where/background.dart';

import './landing_page.dart';
import './map_page.dart';
import './sharing_page.dart';
import './permissions_page.dart';

import './keys.dart';
import './streams.dart';

void main() async {
  runApp(const WhereApp());

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

class WhereApp extends StatefulWidget {
  const WhereApp({super.key});

  @override
  State<WhereApp> createState() => _WhereAppState();
}

class _WhereAppState extends State<WhereApp> {
  late final Stream<AppBarStreamSnapshot> appBarStream;

  @override
  void initState() {
    appBarController = StreamController();
    appBarStream = appBarController.stream;

    super.initState();
  }

  @override
  void dispose() {
    appBarController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: defaultAppBarSnapshot.title,
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: defaultAppBarSnapshot.color),
      ),
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
                    child: StreamBuilder<AppBarStreamSnapshot>(
                      initialData: defaultAppBarSnapshot,
                      stream: appBarStream,
                      builder: (context, snapshot) => AppBar(
                        leading: IconButton(
                          key: const Key('main.home'),
                          onPressed: () {
                            appBarController.sink.add(defaultAppBarSnapshot);
                            context.go('/');
                          },
                          icon: const Icon(Icons.home),
                          color: snapshot.data?.textColor,
                        ),
                        actions: snapshot.data?.actions,
                        backgroundColor: snapshot.data?.color,
                        title: Text(
                          snapshot.data?.title ?? defaultAppBarSnapshot.title,
                          style: TextStyle(color: snapshot.data?.textColor),
                        ),
                      ),
                    ),
                  ),
                  body: child,
                ),
              );
            },
            routes: <RouteBase>[
              GoRoute(
                path: '/',
                builder: (context, state) {
                  appBarController.sink.add(defaultAppBarSnapshot);
                  return const LandingPage();
                },
              ),
              GoRoute(
                path: '/map',
                builder: (context, state) {
                  appBarController.sink.add(
                    const AppBarStreamSnapshot(title: 'Map'),
                  );
                  return const MapPage();
                },
              ),
              GoRoute(
                path: '/sharing',
                builder: (context, state) {
                  appBarController.sink.add(
                    const AppBarStreamSnapshot(title: 'Sharing settings'),
                  );
                  return const SharingPage();
                },
              ),
              GoRoute(
                path: '/permissions',
                builder: (context, state) {
                  appBarController.sink.add(
                    const AppBarStreamSnapshot(title: 'Permissions settings'),
                  );
                  return const PermissionsPage();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
