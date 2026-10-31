import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

Future<Database> openSettingsDatabase() async {
  return openDatabase(
    join(await getDatabasesPath(), 'settings.db'),
    onCreate: (db, version) {
      return db.execute('''CREATE TABLE settings(
            name TEXT PRIMARY KEY,
            uuid TEXT UNIQUE,
            username TEXT NOT NULL,
            image TEXT NOT NULL,
            token TEXT NOT NULL,
            storage TEXT,
            friends TEXT NOT NULL,
            background INTEGER DEFAULT 0
          )''');
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion <= 6) {
        await databaseFactory.deleteDatabase('settings.db');
        return;
      }
      final batch = db.batch();
      if (oldVersion <= 7) {
        batch.execute(
          '''ALTER TABLE settings ADD COLUMN background INTEGER DEFAULT 0''',
        );
      }
      batch.commit();
    },
    version: 7,
  );
}

class Settings {
  final String name;
  String uuid;
  String username;
  String image;
  String token;
  String? storage;
  List<String> friends;
  bool background;

  Database? db;
  static Settings? _singleton;

  Settings({
    required this.name,
    required this.uuid,
    required this.username,
    required this.image,
    required this.token,
    required this.friends,
    required this.background,
    this.storage,
    this.db,
  });

  Map<String, Object?> toDb() {
    return {
      'name': name,
      'uuid': uuid,
      'username': username,
      'image': image,
      'token': token,
      'storage': storage,
      'friends': jsonEncode(friends),
    };
  }

  factory fromDb(Database db, Map<String, Object?> dbValue) {
    return Settings(
      db: db,
      name: dbValue['name'] as String,
      uuid: dbValue['uuid'] as String,
      username: dbValue['username'] as String,
      image: dbValue['image'] as String,
      token: dbValue['token'] as String,
      storage: dbValue['storage'] as String?,
      background: (dbValue['background'] as int) == 1,
      friends: List<String>.from(jsonDecode(dbValue['friends'] as String)),
    );
  }

  Future<Database> waitForDb() async {
    if (db != null && !(db!.isOpen)) {
      db = null;
    }
    db ??= await openSettingsDatabase();
    return db!;
  }

  Future<void> save() async {
    await (await waitForDb()).insert(
      'settings',
      toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Settings?> getFromDb(String name) async {
    Database db = await openSettingsDatabase();

    final List<Map<String, Object?>> settings = await db.query(
      'settings',
      where: 'name = ?',
      whereArgs: [name],
    );
    if (settings.isEmpty) return null;
    return Settings.fromDb(db, settings.first);
  }

  static Future<Settings> getSingleton() async {
    if (_singleton != null) {
      return _singleton!;
    }

    final existing = await Settings.getFromDb('onlysettings');
    if (existing != null) {
      _singleton = existing;
      return _singleton!;
    }

    return Settings(
      name: 'onlysettings',
      uuid: Uuid().v4(),
      username: '',
      image: '',
      token: '',
      storage: '',
      friends: [],
      background: false,
    );
  }
}
