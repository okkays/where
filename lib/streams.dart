import 'dart:async';

import 'package:flutter/material.dart';

class AppBarStreamSnapshot {
  final Color color;
  final String title;
  final Color textColor;
  final List<Widget> actions;

  const AppBarStreamSnapshot({
    this.color = Colors.lightBlue,
    this.title = 'Where location sharing',
    this.textColor = Colors.black,
    this.actions = const [],
  });

  AppBarStreamSnapshot copyWith({
    Color? color,
    String? title,
    Color? textColor,
    List<Widget>? actions,
  }) {
    return AppBarStreamSnapshot(
      color: color ?? this.color,
      title: title ?? this.title,
      textColor: textColor ?? this.textColor,
      actions: actions ?? this.actions,
    );
  }
}

// These should be initialized in main.dart, probably:
AppBarStreamSnapshot defaultAppBarSnapshot = const AppBarStreamSnapshot();
late StreamController<AppBarStreamSnapshot> appBarController;
late StreamController<String> routeChangedController;
