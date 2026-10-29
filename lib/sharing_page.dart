import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import './settings.dart';

class SharingPage extends StatefulWidget {
  const SharingPage({super.key});

  @override
  State<StatefulWidget> createState() => _SharingPageState();
}

Future<Settings> getOnlySettings() async {
  final existing = await Settings.getFromDb('onlysettings');
  if (existing != null) {
    return existing;
  }

  var uuid = Uuid();
  return Settings(
    name: 'onlysettings',
    username: '',
    image: '',
    token: '',
    uuid: uuid.v1(),
  );
}

class _SharingPageState extends State<SharingPage> {
  final Future<Settings> settings = getOnlySettings();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: settings,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return Center(child: Text('loading...'));
        return Padding(
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
                        hintText: 'Github token with repo access',
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
                  Text('Device ID:', style: TextTheme.of(context).titleLarge),
                  Expanded(
                    child: TextFormField(
                      enabled: false,
                      initialValue: data.uuid,
                    ),
                  ),
                ],
              ),
              Spacer(),
              Row(
                mainAxisAlignment: .end,
                spacing: 10,
                children: [
                  Padding(
                    padding: EdgeInsetsGeometry.fromLTRB(0, 0, 20, 40),
                    child: FloatingActionButton(
                      onPressed: () {
                        data.save();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Preferences updated!'),
                            showCloseIcon: true,
                          ),
                        );
                      },
                      child: Icon(Icons.save),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
