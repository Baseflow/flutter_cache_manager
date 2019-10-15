import 'dart:async';

import 'package:sqflite/sqflite.dart';

import 'cache_object.dart';
/// Sqlite [CacheObjectProvider] implemtation
class CacheObjectDbProvider extends CacheObjectProvider {
  Database db;
  final String path;

  CacheObjectDbProvider(this.path);

  @override
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

  @override
  Future<CacheObject> insert(CacheObject cacheObject) async {
    cacheObject.id = await db.insert(tableCacheObject, cacheObject.toMap());
    return cacheObject;
  }

  @override
  Future<CacheObject> get(String url) async {
    List<Map> maps = await db.query(tableCacheObject,
        columns: null, where: "$columnUrl = ?", whereArgs: [url]);
    if (maps.length > 0) {
      return new CacheObject.fromMap(maps.first);
    }
    return null;
  }

  @override
  Future<dynamic> delete(int id) async {
    return await db
        .delete(tableCacheObject, where: "$columnId = ?", whereArgs: [id]);
  }

  @override
  Future deleteAll(Iterable<int> ids) async {
    return await db.delete(tableCacheObject,
        where: "$columnId IN (" + ids.join(",") + ")");
  }

  @override
  Future<int> update(CacheObject cacheObject) async {
    return await db.update(tableCacheObject, cacheObject.toMap(),
        where: "$columnId = ?", whereArgs: [cacheObject.id]);
  }

  @override
  Future<List<CacheObject>> getAllObjects() async {
    List<Map> maps = await db.query(tableCacheObject, columns: null);
    return CacheObject.fromMapList(maps);
  }

  @override
  Future<List<CacheObject>> getObjectsOverCapacity(int capacity) async {
    List<Map> maps = await db.query(tableCacheObject,
        columns: null,
        orderBy: "$columnTouched DESC",
        where: "$columnTouched < ?",
        whereArgs: [
          DateTime.now().subtract(new Duration(days: 1)).millisecondsSinceEpoch
        ],
        limit: 100,
        offset: capacity);

    return CacheObject.fromMapList(maps);
  }

  @override
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

  @override
  Future close() async => await db.close();
}
