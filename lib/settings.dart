import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

Future<Database> openSettingsDatabase() async {
  return openDatabase(
    join(await getDatabasesPath(), 'settings.db'),
    onCreate: (db, version) {
      return db.execute('''CREATE TABLE settings(
            name TEXT PRIMARY KEY,
            username TEXT NOT NULL,
            image TEXT NOT NULL,
            token TEXT NOT NULL,
            uuid TEXT NOT NULL
          )''');
    },
    onUpgrade: (_, _, _) async {
      await databaseFactory.deleteDatabase('settings.db');
    },
    version: 4,
  );
}

class Settings {
  final String name;
  String username;
  String image;
  String token;
  Database? db;
  final String uuid;

  Settings({
    required this.name,
    required this.username,
    required this.image,
    required this.token,
    required this.uuid,
    this.db,
  });

  Map<String, Object?> toDb() {
    return {
      'name': name,
      'username': username,
      'image': image,
      'token': token,
      'uuid': uuid,
    };
  }

  factory fromDb(Database db, Map<String, Object?> dbValue) {
    return Settings(
      db: db,
      name: dbValue['name'] as String,
      username: dbValue['username'] as String,
      image: dbValue['image'] as String,
      token: dbValue['token'] as String,
      uuid: dbValue['uuid'] as String,
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
}
