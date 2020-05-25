import 'package:clock/clock.dart';

///Flutter Cache Manager
///Copyright (c) 2019 Rene Floor
///Released under MIT License.

///Cache information of one file
class CacheObject {
  static const columnId = '_id';
  static const columnUrl = 'url';
  static const columnKey = 'key';
  static const columnPath = 'relativePath';
  static const columnETag = 'eTag';
  static const columnValidTill = 'validTill';
  static const columnTouched = 'touched';

  CacheObject(
    this.url, {
    this.key,
    this.relativePath,
    this.validTill,
    this.eTag,
    this.id,
  }) {
    key ??= url;
  }

  CacheObject.fromMap(Map<String, dynamic> map)
      : id = map[columnId] as int,
        url = map[columnUrl] as String,
        key = map[columnKey] as String ?? map[columnUrl] as String,
        relativePath = map[columnPath] as String,
        validTill =
            DateTime.fromMillisecondsSinceEpoch(map[columnValidTill] as int),
        eTag = map[columnETag] as String;

  /// Internal ID used to represent this cache object
  int id;

  /// The URL that was used to download the file
  String url;

  /// The key used to identify the object in the cache.
  ///
  /// This key is optional and will default to [url] if not specified
  String key;

  /// Where the cached file is stored
  String relativePath;

  /// When this cached item becomes invalid
  DateTime validTill;

  /// eTag provided by the server for cache expiry
  String eTag;

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      columnUrl: url,
      columnKey: key,
      columnPath: relativePath,
      columnETag: eTag,
      columnValidTill: validTill?.millisecondsSinceEpoch ?? 0,
      columnTouched: clock.now().millisecondsSinceEpoch
    };
    if (id != null) {
      map[columnId] = id;
    }
    return map;
  }

  static List<CacheObject> fromMapList(List<Map<String, dynamic>> list) {
    return list.map((map) => CacheObject.fromMap(map)).toList();
  }
}
