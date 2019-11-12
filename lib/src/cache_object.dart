// CacheManager for Flutter
// Copyright (c) 2017 Rene Floor
// Released under MIT License.

// HINT: Unnecessary import. Future and Stream are available via dart:core.
import 'dart:async';

import 'package:sqflite/sqflite.dart';

const _tableCacheObject = 'cacheObject';
const _columnId = '_id';
const _columnUrl = 'url';
const _columnPath = 'relativePath';
const _columnETag = 'eTag';
const _columnValidTill = 'validTill';
const _columnTouched = 'touched';

///Flutter Cache Manager
///Copyright (c) 2019 Rene Floor
///Released under MIT License.

///Cache information of one file
class CacheObject {
  CacheObject(this.url, {this.relativePath, this.validTill, this.eTag, this.id});

  CacheObject.fromMap(Map<String, dynamic> map)
      : id = map[_columnId] as int,
        url = map[_columnUrl] as String,
        relativePath = map[_columnPath] as String,
        validTill = DateTime.fromMillisecondsSinceEpoch(map[_columnValidTill] as int),
        eTag = map[_columnETag] as String;

  int id;
  String url;
  String relativePath;
  DateTime validTill;
  String eTag;

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      _columnUrl: url,
      _columnPath: relativePath,
      _columnETag: eTag,
      _columnValidTill: validTill?.millisecondsSinceEpoch ?? 0,
      _columnTouched: DateTime.now().millisecondsSinceEpoch
    };
    if (id != null) {
      map[_columnId] = id;
    }
    return map;
  }

  static List<CacheObject> fromMapList(List<Map<String, dynamic>> list) {
    return list.map((map) => CacheObject.fromMap(map)).toList();
  }
}

class CacheObjectProvider {
  Database db;
  String path;

  CacheObjectProvider(this.path);

  Future open() async {
    db = await openDatabase(path, version: 1, onCreate: (Database db, int version) async {
      await db.execute('''
      create table $_tableCacheObject ( 
        $_columnId integer primary key, 
        $_columnUrl text, 
        $_columnPath text,
        $_columnETag text,
        $_columnValidTill integer,
        $_columnTouched integer
        )
      ''');
    });
  }

  Future<dynamic> updateOrInsert(CacheObject cacheObject) {
    if (cacheObject.id == null) {
      return insert(cacheObject);
    } else {
      return update(cacheObject);
    }
  }

  Future<CacheObject> insert(CacheObject cacheObject) async {
    cacheObject.id = await db.insert(_tableCacheObject, cacheObject.toMap());
    return cacheObject;
  }

  Future<CacheObject> get(String url) async {
    List<Map> maps = await db.query(_tableCacheObject, columns: null, where: '$_columnUrl = ?', whereArgs: [url]);
    if (maps.isNotEmpty) {
      return CacheObject.fromMap(maps.first.cast<String, dynamic>());
    }
    return null;
  }

  Future<int> delete(int id) {
    return db.delete(_tableCacheObject, where: '$_columnId = ?', whereArgs: [id]);
  }

  Future deleteAll(Iterable<int> ids) {
    return db.delete(_tableCacheObject, where: '$_columnId IN (' + ids.join(',') + ')');
  }

  Future<int> update(CacheObject cacheObject) {
    return db.update(_tableCacheObject, cacheObject.toMap(), where: '$_columnId = ?', whereArgs: [cacheObject.id]);
  }

  Future<List<CacheObject>> getAllObjects() async {
    return CacheObject.fromMapList(
      await db.query(_tableCacheObject, columns: null),
    );
  }

  Future<List<CacheObject>> getObjectsOverCapacity(int capacity) async {
    return CacheObject.fromMapList(await db.query(
      _tableCacheObject,
      columns: null,
      orderBy: '$_columnTouched DESC',
      where: '$_columnTouched < ?',
      whereArgs: [DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch],
      limit: 100,
      offset: capacity,
    ));
  }

  Future<List<CacheObject>> getOldObjects(Duration maxAge) async {
    return CacheObject.fromMapList(await db.query(
      _tableCacheObject,
      where: '$_columnTouched < ?',
      columns: null,
      whereArgs: [DateTime.now().subtract(maxAge).millisecondsSinceEpoch],
      limit: 100,
    ));
  }

  Future close() => db.close();
}
