// CacheManager for Flutter
// Copyright (c) 2017 Rene Floor
// Released under MIT License.

// HINT: Unnecessary import. Future and Stream are available via dart:core.
import 'dart:async';

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

/// Interface for caching [CacheObject].
abstract class CacheObjectProvider {
  /// Open this provider.
  Future open();
  /// Insert a new object.
  Future<CacheObject> insert(CacheObject cacheObject);
  /// Gets an object belongs to [url].
  Future<CacheObject> get(String url);
  Future<dynamic> delete(int id);
  Future<dynamic> deleteAll(Iterable<int> ids);
  Future<int> update(CacheObject cacheObject);
  Future<dynamic> updateOrInsert(CacheObject cacheObject) async {
    if (cacheObject.id == null) {
      return await insert(cacheObject);
    } else {
      return await update(cacheObject);
    }
  }

  /// Get all objects in this provider.
  Future<List<CacheObject>> getAllObjects();

  /// Get all objects whose index exceeds [capacity].
  Future<List<CacheObject>> getObjectsOverCapacity(int capacity);

  /// Get all objects whose age exceeds [maxAge].
  Future<List<CacheObject>> getOldObjects(Duration maxAge);

  /// Close this provider.
  Future close();
}
