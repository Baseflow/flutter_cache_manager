import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/src/storage/cache_object.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'cache_info_repository.dart';

class JsonCacheInfoRepository implements CacheInfoRepository {
  Directory directory;
  String path;
  String databaseName;

  /// Either the path or the database name should be provided.
  /// If the path is provider it should end with '{databaseName}.json',
  /// for example: /data/user/0/com.example.example/databases/imageCache.json
  JsonCacheInfoRepository({this.path, this.databaseName})
      : assert(path == null || databaseName == null);

  /// The directory and the databaseName should both the provided. The database
  /// is stored as {databaseName}.json in the directory,
  JsonCacheInfoRepository.inDirectory(
      {@required this.directory, @required this.databaseName})
      : assert(directory != null),
        assert(databaseName != null);

  File _file;
  Map<String, CacheObject> _cacheObjects;
  Map<int, Map<String, dynamic>> _jsonCache;

  @visibleForTesting
  Future openWithFile(File file) async {
    _file = file;
    await _readFile();
  }

  @override
  Future open() async {
    if (path != null) {
      directory = File(path).parent;
    } else {
      directory ??= await getApplicationSupportDirectory();
    }
    await directory.create(recursive: true);
    if (path == null || !path.endsWith('.json')) {
      path = join(directory.path, '$databaseName.json');
    }
    _file = File(path);
    await _readFile();
  }

  @override
  Future<CacheObject> get(String key) async {
    return _cacheObjects.values.firstWhere(
      (element) => element.key == key,
      orElse: () => null,
    );
  }

  @override
  Future<List<CacheObject>> getAllObjects() async {
    return _cacheObjects.values.toList();
  }

  @override
  Future<CacheObject> insert(CacheObject cacheObject) async {
    if (cacheObject.id != null) {
      throw ArgumentError("Inserted objects shouldn't have an existing id.");
    }
    var keys = _jsonCache.keys;
    var lastId = keys.isEmpty ? 0 : keys.reduce(max);
    var id = lastId + 1;

    cacheObject = cacheObject.copyWith(id: id);
    _put(cacheObject);
    return cacheObject;
  }

  @override
  Future<int> update(CacheObject cacheObject) async {
    _put(cacheObject);
    return 1;
  }

  @override
  Future updateOrInsert(CacheObject cacheObject) {
    return cacheObject.id == null ? insert(cacheObject) : update(cacheObject);
  }

  @override
  Future<List<CacheObject>> getObjectsOverCapacity(int capacity) async {
    var allSorted = _cacheObjects.values.toList()
      ..sort((c1, c2) => c1.touched.compareTo(c2.touched));
    if (allSorted.length <= capacity) return [];
    return allSorted.getRange(0, allSorted.length - capacity).toList();
  }

  @override
  Future<List<CacheObject>> getOldObjects(Duration maxAge) async {
    var oldestTimestamp = DateTime.now().subtract(maxAge);
    return _cacheObjects.values
        .where(
          (element) => element.touched.isBefore(oldestTimestamp),
        )
        .toList();
  }

  @override
  Future<int> delete(int id) async {
    var cacheObject = _cacheObjects.values.firstWhere(
      (element) => element.id == id,
      orElse: () => null,
    );
    if (cacheObject == null) {
      return 0;
    }
    _remove(cacheObject);
    return 1;
  }

  @override
  Future deleteAll(Iterable<int> ids) async {
    for (var id in ids) {
      await delete(id);
    }
  }

  @override
  Future close() {
    return _saveFile();
  }

  Future _readFile() async {
    _cacheObjects = {};
    _jsonCache = {};
    if (await _file.exists()) {
      var jsonString = await _file.readAsString();
      var json = jsonDecode(jsonString) as List<dynamic>;
      for (var element in json) {
        if (element is! Map<String, dynamic>) continue;
        var map = element as Map<String, dynamic>;
        var cacheObject = CacheObject.fromMap(map);
        _jsonCache[cacheObject.id] = map;
        _cacheObjects[cacheObject.key] = cacheObject;
      }
    }
  }

  void _put(CacheObject cacheObject) {
    _jsonCache[cacheObject.id] = cacheObject.toMap();
    _cacheObjects[cacheObject.key] = CacheObject.fromMap(
      _jsonCache[cacheObject.id],
    );
    _cacheUpdated();
  }

  void _remove(CacheObject cacheObject) {
    _cacheObjects.remove(cacheObject.key);
    _jsonCache.remove(cacheObject.id);
    _cacheUpdated();
  }

  void _cacheUpdated() {
    timer?.cancel();
    timer = Timer(timerDuration, _saveFile);
  }

  Timer timer;
  Duration timerDuration = const Duration(seconds: 3);

  Future _saveFile() async {
    timer?.cancel();
    timer = null;
    await _file.writeAsString(jsonEncode(_jsonCache.values.toList()));
  }
}
