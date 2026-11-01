import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher_string.dart';

import './share.dart';
import './store.dart';

import './settings.dart';

class SharingPage extends StatefulWidget {
  const SharingPage({super.key});

  @override
  State<StatefulWidget> createState() => _SharingPageState();
}

enum _SaveStatus { saved, saving, unsaved }

class _SharingPageState extends State<SharingPage> {
  final Future<Settings> futureSettings = Settings.getSingleton();

  List<Share> friends = [];
  bool isFriendsLoading = true;

  Icon tokenStatusIcon = Icon(Icons.hourglass_empty, color: Colors.orange);
  final storageController = TextEditingController();
  final tokenController = TextEditingController();
  final Map<Share, TextEditingController> newFriendControllers = {};

  _SaveStatus isSaved = .saved;

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

  Future<List<Share>> inflateFriends(List<String> friendIds) async {
    final store = await Store.fromSettings();
    if (store == null) return [];
    final inflatedFriends = await Future.wait(
      friendIds.map((id) async {
        final inflated = await store.shareFromId(id);
        if (inflated != null) return inflated;
        final errorShare = Share(
          name: '',
          image: '',
          storage: id,
          locations: [],
          isMine: false,
          isNew: true,
        );
        newFriendControllers[errorShare] = TextEditingController.fromValue(
          .new(text: id),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade800,
              behavior: .floating,
              margin: EdgeInsets.only(
                left: 20,
                right: 100,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              duration: Duration(days: 365),
              content: const Text('A friend ID was invalid!'),
              showCloseIcon: true,
            ),
          );
        }
        return errorShare;
      }),
    );
    return inflatedFriends.whereType<Share>().toList();
  }

  Future<void> handleSave(BuildContext context, Settings settings) async {
    setState(() {
      isSaved = .saving;
    });
    final newIcon = await checkTokenStatus();
    final store = await Store.fromSettings();
    final share = await store?.getOrCreateMyShare();
    settings.storage = settings.token.isEmpty ? null : share?.storage;
    storageController.value = .new(text: settings.storage ?? '');
    if (settings.token.isEmpty) {
      settings.friends = [];
      setState(() {
        friends = [];
      });
    } else {
      settings.friends = friends.map((f) => f.storage).toList();
    }
    await settings.save();

    final inflatedFriends = await inflateFriends(settings.friends);

    setState(() {
      tokenStatusIcon = newIcon;
      friends = inflatedFriends;
      isSaved = .saved;
    });

    await store?.refreshSharesFromStore();

    if (!context.mounted) return;
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
  }

  Future<void> initWithSettings() async {
    final settings = await futureSettings;
    setState(() {
      storageController.value = .new(text: settings.storage ?? '');
      tokenController.value = .new(text: settings.token);
    });
    final newIcon = await checkTokenStatus();
    final inflatedFriends = await inflateFriends(settings.friends);
    setState(() {
      tokenStatusIcon = newIcon;
      friends = inflatedFriends;
      isFriendsLoading = false;
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
      future: futureSettings,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return Center(child: Text('loading...'));
        final hasId = data.storage?.isNotEmpty ?? false;
        return Stack(
          children: [
            Padding(
              padding: EdgeInsetsGeometry.all(10),
              child: SingleChildScrollView(
                child: Column(
                  spacing: 10,
                  children: [
                    Text('About you', style: TextTheme.of(context).titleMedium),
                    ...(hasId
                        ? []
                        : [
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    style: TextTheme.of(context).bodyMedium,
                                    text: 'ℹ️ First, fill in your name and token. Then save to get an ID. You can send that ID to friends to show them your location.\n\nGenerate a token at: ',
                                  ),
                                  TextSpan(
                                    style: TextTheme.of(context).bodyMedium!
                                        .copyWith(
                                          color: ColorScheme.of(context)
                                              .primary,
                                        ),
                                    text: 'https://github.com/settings/personal-access-tokens/new',
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () async {
                                        final url =
                                            'https://github.com/settings/personal-access-tokens/new?name=Where%20location%20sharing%20token&description=A%20personal%20access%20token%20for%20the%20where%20app,%20which%20grants%20only%20gist%20permissions&expires_in=none&gists=write';
                                        await launchUrlString(url);
                                      },
                                  ),
                                  TextSpan(
                                    style: TextTheme.of(context).bodyMedium,
                                    text: '.\n\nThe link above will pre-fill the correct settings and permissions - all you need to do is click Generate, then copy the token before leaving the page and paste it below.',
                                  ),
                                ],
                              ),
                            ),
                          ]),
                    Row(
                      spacing: 10,
                      children: [
                        Text('Name:', style: TextTheme.of(context).titleMedium),
                        Expanded(
                          child: TextFormField(
                            textAlignVertical: .center,
                            decoration: InputDecoration(
                              hintText: 'How to appear to others',
                            ),
                            initialValue: data.username,
                            onChanged: (newValue) {
                              setState(() {
                                isSaved = .unsaved;
                              });
                              data.username = newValue;
                            },
                          ),
                        ),
                      ],
                    ),
                    Row(
                      spacing: 10,
                      children: [
                        Text(
                          'Token:',
                          style: TextTheme.of(context).titleMedium,
                        ),
                        Expanded(
                          child: TextFormField(
                            controller: tokenController,
                            textAlignVertical: .center,
                            decoration: InputDecoration(
                              hintText: 'Token for storing location',
                              suffixIcon: Wrap(
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        isSaved = .unsaved;
                                      });
                                      Clipboard.getData('text/plain').then((d) {
                                        final newValue = d?.text ?? '';
                                        data.token = newValue;
                                        tokenController.value = .new(
                                          text: newValue,
                                        );
                                      });
                                    },
                                    icon: Icon(Icons.paste),
                                  ),
                                  Padding(
                                    padding: .all(12),
                                    child: tokenStatusIcon,
                                  ),
                                ],
                              ),
                            ),
                            onChanged: (newValue) {
                              data.token = newValue;
                              setState(() {
                                isSaved = .unsaved;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    Row(
                      spacing: 10,
                      children: [
                        Text(
                          'Your ID:',
                          style: TextTheme.of(context).titleMedium,
                        ),
                        Expanded(
                          child: TextFormField(
                            controller: storageController,
                            readOnly: true,
                            textAlignVertical: .center,
                            decoration: InputDecoration(
                              suffixIcon: IconButton(
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: data.storage ?? ''),
                                  );
                                },
                                icon: Icon(Icons.copy),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'To share your location, copy the ID above and send it to people you know. To add others to your map, click "Add friend" below and paste in their ID, then click save.',
                    ),
                    Divider(),
                    Text(
                      'Your friends',
                      style: TextTheme.of(context).titleMedium,
                    ),
                    ...(isFriendsLoading
                        ? [Text('loading...')]
                        : friends.map((friend) {
                            if (friend.isNew) {
                              // This is a new friend to be edited
                              final controller = newFriendControllers[friend];
                              return Row(
                                spacing: 10,
                                children: [
                                  Text(
                                    "Friend's ID:",
                                    style: TextTheme.of(context).titleMedium,
                                  ),
                                  Expanded(
                                    child: TextFormField(
                                      controller: controller,
                                      textAlignVertical: .center,
                                      decoration: InputDecoration(
                                        hintText: 'Get this from a friend',
                                        suffixIcon: Wrap(
                                          children: [
                                            IconButton(
                                              onPressed: () {
                                                setState(() {
                                                  isSaved = .unsaved;
                                                });
                                                Clipboard.getData('text/plain')
                                                    .then((d) {
                                                      final newValue =
                                                          d?.text ?? '';
                                                      controller!.value = .new(
                                                        text: newValue,
                                                      );
                                                      friend.storage = newValue;
                                                    });
                                              },
                                              icon: Icon(Icons.paste),
                                            ),
                                            IconButton(
                                              onPressed: () {
                                                setState(() {
                                                  isSaved = .unsaved;
                                                  friends.remove(friend);
                                                });
                                              },
                                              icon: Icon(Icons.delete),
                                              color: Colors.redAccent,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }
                            return Row(
                              spacing: 10,
                              children: [
                                Text(
                                  '◦ ${friend.name}:',
                                  style: TextTheme.of(context).titleMedium,
                                ),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: friend.storage,
                                    readOnly: true,
                                    textAlignVertical: .center,
                                    decoration: InputDecoration(
                                      suffixIcon: Wrap(
                                        children: [
                                          IconButton(
                                            onPressed: () {
                                              Clipboard.setData(
                                                ClipboardData(
                                                  text: friend.storage,
                                                ),
                                              );
                                            },
                                            icon: Icon(Icons.copy),
                                          ),
                                          IconButton(
                                            onPressed: () {
                                              setState(() {
                                                isSaved = .unsaved;
                                                friends.remove(friend);
                                              });
                                            },
                                            icon: Icon(Icons.delete),
                                            color: Colors.redAccent,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          })),
                    Row(
                      spacing: 10,
                      children: [
                        ElevatedButton.icon(
                          icon: Icon(Icons.person_add, color: Colors.green),
                          label: Text(
                            'Add friend',
                            style: TextTheme.of(context).titleMedium,
                          ),
                          onPressed: !hasId
                              ? null
                              : () {
                                  final newFriend = Share(
                                    name: '',
                                    image: '',
                                    storage: '',
                                    locations: [],
                                    isMine: false,
                                    isNew: true,
                                  );
                                  newFriendControllers[newFriend] =
                                      TextEditingController();
                                  setState(() {
                                    friends.add(newFriend);
                                  });
                                },
                        ),
                        ...(!hasId
                            ? [
                                Flexible(
                                  child: Text(
                                    'Enter a name and token to add friends.',
                                    style: TextStyle(
                                      fontStyle: .italic,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ]
                            : []),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: MediaQuery.of(context).viewInsets.bottom + 40,
              right: 20,
              child: FloatingActionButton(
                onPressed: isSaved == .unsaved
                    ? () {
                        handleSave(context, data);
                      }
                    : null,
                backgroundColor: (switch (isSaved) {
                  .saved => Colors.grey.shade300,
                  .unsaved => null,
                  .saving => Colors.orange.shade100,
                }),
                child: (switch (isSaved) {
                  .saved => Icon(Icons.save, color: Colors.grey.shade600),
                  .unsaved => Badge(smallSize: 10, child: Icon(Icons.save)),
                  .saving => Icon(
                    Icons.hourglass_top,
                    color: Colors.orange.shade800,
                  ),
                }),
              ),
            ),
          ],
        );
      },
    );
  }
}
