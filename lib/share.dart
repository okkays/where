import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

Future<Database> openShareDatabase() async {
  return openDatabase(
    join(await getDatabasesPath(), 'share.db'),
    onCreate: (db, version) {
      return db.execute('''CREATE TABLE share(
            name TEXT PRIMARY KEY,
            image TEXT NOT NULL,
            locations TEXT NOT NULL,
            is_mine INTEGER NOT NULL
          )''');
    },
    onUpgrade: (_, _, _) async {
      await databaseFactory.deleteDatabase('share.db');
    },
    version: 1,
  );
}

class ShareLocation {
  final LatLng location;
  final DateTime timestamp;

  const ShareLocation({required this.location, required this.timestamp});

  // Formatted as 'some.lat,some.long|dddd-yy-mm hh:mm:ssZ'
  factory fromDb(String dbValue) {
    final parts = dbValue.split('|');
    final rawLocation = parts.first.split(',');
    final rawTimestamp = parts.last.trim();

    final location = LatLng(
      double.parse(rawLocation.first.trim()),
      double.parse(rawLocation.last.trim()),
    );
    final timestamp = DateTime.parse(rawTimestamp);

    return ShareLocation(location: location, timestamp: timestamp);
  }

  // Formatted as 'some.lat,some.long|dddd-yy-mm hh:mm:ssZ'
  String toDb() {
    return '${location.latitude},${location.longitude}|${timestamp.toUtc().toString()}';
  }
}

class Share {
  final String name;
  final String image;
  bool isMine;
  final List<ShareLocation> locations;
  Database? db;

  Share({
    required this.name,
    required this.image,
    required this.locations,
    required this.isMine,
    this.db,
  });

  Map<String, Object?> toDb() {
    return {
      'name': name,
      'image': image,
      'locations': jsonEncode(locations.map((l) => l.toDb())),
      'is_mine': isMine ? 1 : 0,
    };
  }

  factory fromDb(Database db, Map<String, Object?> dbValue) {
    final List<dynamic> list = jsonDecode(dbValue['locations'] as String);
    return Share(
      db: db,
      name: dbValue['name'] as String,
      image: dbValue['image'] as String,
      isMine: dbValue['is_mine'] == 1,
      locations: List<String>.from(list).map(ShareLocation.fromDb).toList(),
    );
  }

  Future<Database> waitForDb() async {
    if (db != null && !(db!.isOpen)) {
      db = null;
    }
    db ??= await openShareDatabase();
    return db!;
  }

  Future<void> save() async {
    await (await waitForDb()).insert(
      'share',
      toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Share>> getFromDb() async {
    Database db = await openShareDatabase();

    final List<Map<String, Object?>> shares = await db.query('share');
    return shares.map((s) => Share.fromDb(db, s)).toList();
  }
}
