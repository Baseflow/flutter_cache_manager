// CacheManager for Flutter
// Copyright (c) 2017 Rene Floor
// Released under MIT License.
import 'package:sqflite/sqflite.dart';

final String tableCacheObject = "cacheObject";

final String columnId = "_id";
final String columnUrl = "url";
final String columnPath = "relativePath";
final String columnETag = "eTag";
final String columnValidTill = "validTill";
final String columnTouched = "touched";

///Cache information of one file
class CacheObject {
  int id;
  String url;
  String relativePath;
  DateTime validTill;
  String eTag;
  DateTime touched;

  CacheObject(this.url,
      {this.relativePath, this.validTill, this.eTag, this.touched, this.id}) {
    if (touched == null) {
      touched = DateTime.now();
    }
  }

  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{
      columnUrl: url,
      columnPath: relativePath,
      columnETag: eTag,
      columnValidTill: validTill.millisecondsSinceEpoch,
      columnTouched: touched.millisecondsSinceEpoch
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
    touched = DateTime.fromMillisecondsSinceEpoch(map[columnTouched]);
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

  Future<int> update(CacheObject cacheObject) async {
    return await db.update(tableCacheObject, cacheObject.toMap(),
        where: "$columnId = ?", whereArgs: [cacheObject.id]);
  }

  Future close() async => await db.close();
}
