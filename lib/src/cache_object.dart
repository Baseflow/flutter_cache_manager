// CacheManager for Flutter
// Copyright (c) 2017 Rene Floor
// Released under MIT License.

// HINT: Unnecessary import. Future and Stream are available via dart:core.
import 'dart:async';

import 'package:sqflite/sqflite.dart';

final String tableCacheObject = "cacheObject";

final String columnId = "_id";
final String columnUrl = "url";
final String columnPath = "relativePath";
final String columnETag = "eTag";
final String columnValidTill = "validTill";
final String columnTouched = "touched";
/**
 *  Flutter Cache Manager
 *
 *  Copyright (c) 2018 Rene Floor
 *
 *  Released under MIT License.
 */

///Cache information of one file
class CacheObject {
  int id;
  String url;
  String relativePath;
  DateTime validTill;
  String eTag;

  CacheObject(this.url,
      {this.relativePath, this.validTill, this.eTag, this.id});

  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{
      columnUrl: url,
      columnPath: relativePath,
      columnETag: eTag,
      columnValidTill: validTill?.millisecondsSinceEpoch ?? 0,
      columnTouched: DateTime.now().millisecondsSinceEpoch
    };
    if (id != null) {
      map[columnId] = id;
    }
    return map;
  }

  CacheObject.fromMap(Map<String, dynamic> map) {
    id = map[columnId];
    url = map[columnUrl];
    relativePath = map[columnPath];
    validTill = DateTime.fromMillisecondsSinceEpoch(map[columnValidTill]);
    eTag = map[columnETag];
  }

  static List<CacheObject> fromMapList(List<Map<String, dynamic>> list) {
    var objects = new List<CacheObject>();
    for (var map in list) {
      objects.add(CacheObject.fromMap(map));
    }
    return objects;
  }
}

class CacheObjectProvider {
  Database db;
  String path;

  CacheObjectProvider(this.path);

  Future open() async {
    db = await openDatabase(path, version: 1,
        onCreate: (Database db, int version) async {
      await db.execute('''
      create table $tableCacheObject ( 
        $columnId integer primary key, 
        $columnUrl text, 
        $columnPath text,
        $columnETag text,
        $columnValidTill integer,
        $columnTouched integer
        )
      ''');
    });
  }

  Future<dynamic> updateOrInsert(CacheObject cacheObject) async {
    if (cacheObject.id == null) {
      return await insert(cacheObject);
    } else {
      return await update(cacheObject);
    }
  }

  Future<CacheObject> insert(CacheObject cacheObject) async {
    cacheObject.id = await db.insert(tableCacheObject, cacheObject.toMap());
    return cacheObject;
  }

  Future<CacheObject> get(String url) async {
    List<Map> maps = await db.query(tableCacheObject,
        columns: null, where: "$columnUrl = ?", whereArgs: [url]);
    if (maps.length > 0) {
      return new CacheObject.fromMap(maps.first);
    }
    return null;
  }

  Future<int> delete(int id) async {
    return await db
        .delete(tableCacheObject, where: "$columnId = ?", whereArgs: [id]);
  }

  Future deleteAll(Iterable<int> ids) async {
    return await db.delete(tableCacheObject,
        where: "$columnId IN (" + ids.join(",") + ")");
  }

  Future<int> update(CacheObject cacheObject) async {
    return await db.update(tableCacheObject, cacheObject.toMap(),
        where: "$columnId = ?", whereArgs: [cacheObject.id]);
  }

  Future<List<CacheObject>> getAllObjects() async {
    List<Map> maps = await db.query(tableCacheObject, columns: null);
    return CacheObject.fromMapList(maps);
  }

  Future<List<CacheObject>> getObjectsOverCapacity(int capacity) async {
    List<Map> maps = await db.query(tableCacheObject,
        columns: null,
        orderBy: "$columnTouched ASC",
        where: "$columnTouched < ?",
        whereArgs: [
          DateTime.now().subtract(new Duration(days: 1)).millisecondsSinceEpoch
        ],
        limit: 100,
        offset: capacity);

    return CacheObject.fromMapList(maps);
  }

  Future<List<CacheObject>> getOldObjects(Duration maxAge) async {
    List<Map<String, dynamic>> maps = await db.query(
      tableCacheObject,
      where: "$columnTouched < ?",
      columns: null,
      whereArgs: [DateTime.now().subtract(maxAge).millisecondsSinceEpoch],
      limit: 100,
    );

    return CacheObject.fromMapList(maps);
  }

  Future close() async => await db.close();
}
