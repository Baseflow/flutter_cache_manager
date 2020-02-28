import 'dart:async';
import 'dart:io';

import 'package:flutter_cache_manager/src/storage/cache_info_repository.dart';
import 'package:flutter_cache_manager/src/storage/cache_object.dart';
import 'package:flutter_cache_manager/src/file_info.dart';
import 'package:flutter_cache_manager/src/storage/cache_object_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pedantic/pedantic.dart';
import 'package:sqflite/sqflite.dart';

///Flutter Cache Manager
///Copyright (c) 2019 Rene Floor
///Released under MIT License.

class CacheStore {
  static const Duration cleanupRunMinInterval = Duration(seconds: 10);

  final _futureCache = <String, Future<CacheObject>>{};
  final _memCache = <String, CacheObject>{};

  Future<String> filePath;
  String _filePath;

  final String storeKey;
  Future<CacheInfoRepository> _cacheInfoRepository;
  final int _capacity;
  final Duration _maxAge;

  DateTime lastCleanupRun = DateTime.now();
  Timer _scheduledCleanup;

  CacheStore(Future<String> basePath, this.storeKey, this._capacity, this._maxAge,
    {Future<CacheInfoRepository> cacheRepoProvider}) {
    filePath = basePath.then((path) => _filePath = path);
    _cacheInfoRepository = cacheRepoProvider ?? _getObjectProvider();
  }

  Future<CacheInfoRepository> _getObjectProvider() async {
    final databasesPath = await getDatabasesPath();
    try {
      await Directory(databasesPath).create(recursive: true);
    } catch (_) {}
    final provider = CacheObjectProvider(p.join(databasesPath, '$storeKey.db'));
    await provider.open();
    return provider;
  }

  Future<FileInfo> getFile(String url) async {
    final cacheObject = await retrieveCacheData(url);
    if (cacheObject == null || cacheObject.relativePath == null) {
      return null;
    }
    final path = p.join(await filePath, cacheObject.relativePath);
    return FileInfo(File(path), FileSource.Cache, cacheObject.validTill, url);
  }

  Future<void> putFile(CacheObject cacheObject) async {
    _memCache[cacheObject.url] = cacheObject;
    await _updateCacheDataInDatabase(cacheObject);
  }

  Future<CacheObject> retrieveCacheData(String url) {
    if (_memCache.containsKey(url)) {
      return Future.value(_memCache[url]);
    }
    if (!_futureCache.containsKey(url)) {
      final completer = Completer<CacheObject>();
      _getCacheDataFromDatabase(url).then((cacheObject) async {
        if (cacheObject != null && !await _fileExists(cacheObject)) {
          final provider = await _cacheInfoRepository;
          unawaited(provider.delete(cacheObject.id));
          cacheObject = null;
        }
        completer.complete(cacheObject);

        _memCache[url] = cacheObject;
        _futureCache[url] = null;
      });
      _futureCache[url] = completer.future;
    }
    return _futureCache[url];
  }

  FileInfo getFileFromMemory(String url) {
    if (_memCache[url] == null || _filePath == null) {
      return null;
    }
    final cacheObject = _memCache[url];
    final file = File(p.join(_filePath, cacheObject.relativePath));
    return FileInfo(file, FileSource.Cache, cacheObject.validTill, url);
  }

  Future<bool> _fileExists(CacheObject cacheObject) async {
    if (cacheObject?.relativePath == null) {
      return false;
    }

    var dirPath = await filePath;
    var completePath = p.join(dirPath, cacheObject.relativePath);
    var file = File(completePath);
    return file.exists();
  }

  Future<CacheObject> _getCacheDataFromDatabase(String url) async {
    final provider = await _cacheInfoRepository;
    final data = await provider.get(url);
    if (await _fileExists(data)) {
      unawaited(_updateCacheDataInDatabase(data));
    }
    _scheduleCleanup();
    return data;
  }

  void _scheduleCleanup() {
    if (_scheduledCleanup != null) {
      return;
    }
    _scheduledCleanup = Timer(cleanupRunMinInterval, () {
      _scheduledCleanup = null;
      _cleanupCache();
    });
  }

  Future<dynamic> _updateCacheDataInDatabase(CacheObject cacheObject) async {
    final provider = await _cacheInfoRepository;
    return provider.updateOrInsert(cacheObject);
  }

  Future<void> _cleanupCache() async {
    final toRemove = <int>[];
    final provider = await _cacheInfoRepository;

    final overCapacity = await provider.getObjectsOverCapacity(_capacity);
    for (final cacheObject in overCapacity) {
      unawaited(_removeCachedFile(cacheObject, toRemove));
    }

    final oldObjects = await provider.getOldObjects(_maxAge);
    for (final cacheObject in oldObjects) {
      unawaited(_removeCachedFile(cacheObject, toRemove));
    }

    await provider.deleteAll(toRemove);
  }

  Future<void> emptyCache() async {
    final provider = await _cacheInfoRepository;
    final toRemove = <int>[];
    final allObjects = await provider.getAllObjects();
    for (final cacheObject in allObjects) {
      unawaited(_removeCachedFile(cacheObject, toRemove));
    }
    await provider.deleteAll(toRemove);
  }

  Future<void> removeCachedFile(CacheObject cacheObject) async {
    final provider = await _cacheInfoRepository;
    final toRemove = <int>[];
    unawaited(_removeCachedFile(cacheObject, toRemove));
    await provider.deleteAll(toRemove);
  }

  Future<void> _removeCachedFile(CacheObject cacheObject, List<int> toRemove) async {
    if (!toRemove.contains(cacheObject.id)) {
      toRemove.add(cacheObject.id);
      if (_memCache.containsKey(cacheObject.url)) {
        _memCache.remove(cacheObject.url);
      }
      if (_futureCache.containsKey(cacheObject.url)) {
        unawaited(_futureCache.remove(cacheObject.url));
      }
    }
    final file = File(p.join(await filePath, cacheObject.relativePath));
    if (await file.exists()) {
      unawaited(file.delete());
    }
  }

  Future<void> dispose() async {
    final provider = await _cacheInfoRepository;
    await provider.close();
  }
}
