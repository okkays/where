import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:where/background.dart';

import './landing_page.dart';
import './map_page.dart';
import './sharing_page.dart';
import './permissions_page.dart';

import './keys.dart';
import './streams.dart';

void main() {
  runApp(const WhereApp());
  startBackground();
  startSingletonTimer();
}

class WhereApp extends StatefulWidget {
  const WhereApp({super.key});

  @override
  State<WhereApp> createState() => _WhereAppState();
}

List<String> routeHistory = [];

class _WhereAppState extends State<WhereApp> {
  late final AppLifecycleListener _listener;
  bool backgroundMode = false;

  late final Stream<AppBarStreamSnapshot> appBarStream;
  late final Stream<String> routeChangedStream;
  late final StreamSubscription routeChangedListener;
  final NavigatorObserver navigatorObserver = NavigatorObserver();

  @override
  void initState() {
    appBarController = StreamController.broadcast();
    appBarStream = appBarController.stream;
    routeChangedController = StreamController.broadcast();
    routeChangedStream = routeChangedController.stream;

    routeChangedListener = routeChangedStream.listen((uri) {
      routeHistory.clear();
      routeHistory.add(uri);
      print('Route updated: $routeHistory');
    });

    super.initState();
    _handleStateChange(SchedulerBinding.instance.lifecycleState);
    _listener = AppLifecycleListener(onStateChange: _handleStateChange);
  }

  @override
  void dispose() {
    _listener.dispose();
    routeChangedListener.cancel();
    appBarController.close();
    super.dispose();
  }

  void _handleStateChange(AppLifecycleState? state) {
    switch (state) {
      case .resumed:
        setState(() {
          backgroundMode = false;
        });
        break;
      case .paused:
        setState(() {
          backgroundMode = true;
        });
        break;
      default:
    }

    setState(() {
      print('APP STATE: $state');
    });
  }

  @override
  Widget build(BuildContext context) {
    return backgroundMode
        ? MaterialApp(
            title: defaultAppBarSnapshot.title,
            theme: ThemeData(
              colorScheme: .fromSeed(seedColor: defaultAppBarSnapshot.color),
            ),
            home: Scaffold(
              backgroundColor: Colors.grey.shade900,
              body: Padding(
                padding: const .fromLTRB(40, 0, 40, 0),
                child: Center(
                  child: Wrap(
                    alignment: .center,
                    children: [
                      Row(
                        mainAxisAlignment: .center,
                        children: [
                          Icon(
                            Icons.bedtime,
                            color: Colors.yellow.shade700,
                            size: 200,
                          ),
                        ],
                      ),
                      const Text(
                        style: TextStyle(color: Colors.white),
                        textAlign: .center,
                        "Zzz...\n\nI am in a deep and dreamless slumber.\n\nThis page exists to save battery while location is updated in the background.\n\nIf the app doesn't resume on its own in a few seconds, try quitting and reopening the app.",
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        : MaterialApp.router(
            title: defaultAppBarSnapshot.title,
            theme: ThemeData(
              colorScheme: .fromSeed(seedColor: defaultAppBarSnapshot.color),
            ),
            routerConfig: GoRouter(
              observers: [navigatorObserver],
              debugLogDiagnostics: true,
              initialLocation: routeHistory.isEmpty ? '/' : routeHistory.last,
              routes: [
                ShellRoute(
                  builder:
                      (
                        BuildContext context,
                        GoRouterState state,
                        Widget child,
                      ) {
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
                            key: scaffoldKey,
                            resizeToAvoidBottomInset: false,
                            appBar: PreferredSize(
                              preferredSize: const Size(
                                double.infinity,
                                kToolbarHeight,
                              ),
                              child: StreamBuilder<AppBarStreamSnapshot>(
                                initialData: defaultAppBarSnapshot,
                                stream: appBarStream,
                                builder: (context, snapshot) => AppBar(
                                  leading: IconButton(
                                    key: const Key('main.home'),
                                    onPressed: () {
                                      appBarController.sink.add(
                                        defaultAppBarSnapshot,
                                      );
                                      routeChangedController.sink.add('/');
                                      context.go('/');
                                    },
                                    icon: const Icon(Icons.home),
                                    color: snapshot.data?.textColor,
                                  ),
                                  actions: snapshot.data?.actions,
                                  backgroundColor: snapshot.data?.color,
                                  title: Text(
                                    snapshot.data?.title ??
                                        defaultAppBarSnapshot.title,
                                    style: TextStyle(
                                      color: snapshot.data?.textColor,
                                    ),
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
                          const AppBarStreamSnapshot(
                            title: 'Permissions settings',
                          ),
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
