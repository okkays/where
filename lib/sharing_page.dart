import 'package:flutter/material.dart';
import 'package:where/store.dart';

import './settings.dart';

class SharingPage extends StatefulWidget {
  const SharingPage({super.key});

  @override
  State<StatefulWidget> createState() => _SharingPageState();
}

class _SharingPageState extends State<SharingPage> {
  final Future<Settings> settings = Settings.getSingleton();

  Icon tokenStatusIcon = Icon(Icons.hourglass_empty, color: Colors.orange);

  Future<Icon> checkTokenStatus() async {
    final store = await Store.fromSettings();

    if (store == null) {
      return Icon(Icons.help_outlined, color: Colors.purple);
    }

    switch (await store.checkTokenStatus()) {
      case .valid:
        return Icon(Icons.check, color: Colors.green);
      case .invalid:
        return Icon(Icons.error_outline, color: Colors.red);
      default:
        return Icon(Icons.hourglass_top, color: Colors.orange);
    }
  }

  Future<void> initWithSettings() async {
    await settings;
    final newIcon = await checkTokenStatus();
    setState(() {
      tokenStatusIcon = newIcon;
    });
  }

  @override
  void initState() {
    initWithSettings();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: settings,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return Center(child: Text('loading...'));
        return Stack(
          children: [
            Padding(
              padding: EdgeInsetsGeometry.all(10),
              child: Column(
                spacing: 10,
                children: [
                  Row(
                    spacing: 10,
                    children: [
                      Text('Name:', style: TextTheme.of(context).titleLarge),
                      Expanded(
                        child: TextFormField(
                          decoration: InputDecoration(
                            hintText: 'How to appear to others',
                          ),
                          initialValue: data.username,
                          onChanged: (newValue) {
                            data.username = newValue;
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    spacing: 10,
                    children: [
                      Text('Token:', style: TextTheme.of(context).titleLarge),
                      Expanded(
                        child: TextFormField(
                          decoration: InputDecoration(
                            suffixIcon: tokenStatusIcon,
                            hintText: 'Token for storing location',
                          ),
                          initialValue: data.token,
                          onChanged: (newValue) {
                            data.token = newValue;
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    spacing: 10,
                    children: [
                      Text(
                        'Device ID:',
                        style: TextTheme.of(context).titleLarge,
                      ),
                      Expanded(
                        child: TextFormField(
                          enabled: false,
                          initialValue: data.uuid,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: MediaQuery.of(context).viewInsets.bottom + 40,
              right: 20,
              child: FloatingActionButton(
                onPressed: () {
                  data.save();

                  checkTokenStatus().then(
                    (icon) => setState(() {
                      tokenStatusIcon = icon;
                    }),
                  );

                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: .floating,
                      margin: EdgeInsets.only(
                        left: 20,
                        right: 100,
                        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                      ),
                      content: const Text('Preferences updated!'),
                      showCloseIcon: true,
                    ),
                  );
                },
                child: Icon(Icons.save),
              ),
            ),
          ],
        );
      },
    );
  }
}
