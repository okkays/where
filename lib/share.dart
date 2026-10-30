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
            storage TEXT NOT NULL,
            image TEXT NOT NULL,
            locations TEXT NOT NULL,
            is_mine INTEGER NOT NULL,
            updated TEXT NOT NULL
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
  String storage;
  bool isMine;
  final List<ShareLocation> locations;
  DateTime updated;
  static Database? _db;
  bool isNew;

  Share({
    required this.name,
    required this.image,
    required this.storage,
    required this.locations,
    required this.isMine,
    this.isNew = false,
    DateTime? updated,
  }) : updated = updated ?? DateTime.now().toUtc();

  Map<String, Object?> toDb() {
    return {
      'name': name,
      'image': image,
      'storage': storage,
      'locations': jsonEncode(locations.map((l) => l.toDb()).toList()),
      'is_mine': isMine ? 1 : 0,
      'updated': updated.toIso8601String(),
    };
  }

  factory fromDb(Map<String, Object?> dbValue) {
    final List<dynamic> list = jsonDecode(dbValue['locations'] as String);
    return Share(
      name: dbValue['name'] as String,
      image: dbValue['image'] as String,
      storage: dbValue['storage'] as String,
      isMine: dbValue['is_mine'] == 1,
      locations: List<String>.from(list).map(ShareLocation.fromDb).toList(),
      updated: DateTime.parse(dbValue['updated'] as String),
    );
  }

  static Future<Database> getSingletonDb() async {
    if (_db != null && !(_db!.isOpen)) {
      _db = null;
    }
    _db ??= await openShareDatabase();
    return _db!;
  }

  Future<void> save() async {
    updated = DateTime.now().toUtc();

    await (await getSingletonDb()).insert(
      'share',
      toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Share>> getFromDb() async {
    final db = await getSingletonDb();
    final List<Map<String, Object?>> shares = await db.query('share');
    return shares.map(Share.fromDb).toList();
  }

  static Future<Share?> getMine() async {
    final db = await getSingletonDb();
    final List<Map<String, Object?>> shares = await db.query(
      'share',
      where: 'is_mine = ?',
      whereArgs: [1],
    );
    if (shares.isEmpty) return null;
    return Share.fromDb(shares.first);
  }
}
