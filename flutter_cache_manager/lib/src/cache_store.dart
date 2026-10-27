import 'dart:async';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

///Flutter Cache Manager
///Copyright (c) 2019 Rene Floor
///Released under MIT License.

class CacheStore {
  Duration cleanupRunMinInterval = const Duration(seconds: 10);

  final _futureCache = <String, Future<CacheObject?>>{};
  final _memCache = <String, CacheObject>{};

  FileSystem fileSystem;

  final Config _config;

  String get storeKey => _config.cacheKey;
  final Future<CacheInfoRepository> _cacheInfoRepository;

  int get _capacity => _config.maxNrOfCacheObjects;

  Duration get _maxAge => _config.stalePeriod;

  DateTime lastCleanupRun = DateTime.now();
  Timer? _scheduledCleanup;

  CacheStore(Config config)
    : _config = config,
      fileSystem = config.fileSystem,
      _cacheInfoRepository = config.repo.open().then((value) => config.repo);

  Future<FileInfo?> getFile(String key, {bool ignoreMemCache = false}) async {
    final cacheObject = await retrieveCacheData(
      key,
      ignoreMemCache: ignoreMemCache,
    );
    if (cacheObject == null) {
      return null;
    }
    final file = await fileSystem.createFile(cacheObject.relativePath);
    cacheLogger.log(
      'CacheManager: Loaded $key from cache',
      CacheManagerLogLevel.verbose,
    );

    return FileInfo(
      file,
      FileSource.Cache,
      cacheObject.validTill,
      cacheObject.url,
    );
  }

  Future<void> putFile(CacheObject cacheObject) async {
    final previousCacheObject = _memCache[cacheObject.key];
    _memCache[cacheObject.key] = cacheObject;
    final dynamic out;
    try {
      out = await _updateCacheDataInDatabase(cacheObject);
    } catch (e) {
      if (previousCacheObject != null) {
        _memCache[cacheObject.key] = previousCacheObject;
      } else {
        _memCache.remove(cacheObject.key);
      }
      rethrow;
    }

    // We update the cache object with the id if returned by the repository
    if (out is CacheObject && out.id != null) {
      _memCache[cacheObject.key] = cacheObject.copyWith(id: out.id);
    }
  }

  Future<CacheObject?> retrieveCacheData(
    String key, {
    bool ignoreMemCache = false,
  }) async {
    if (!ignoreMemCache && _memCache.containsKey(key)) {
      if (await _fileExists(_memCache[key])) {
        return _memCache[key];
      }
    }
    if (!_futureCache.containsKey(key)) {
      late final Future<CacheObject?> future;
      future = _loadCacheData(key, () => future);
      _futureCache[key] = future;
    }
    return _futureCache[key];
  }

  Future<CacheObject?> _loadCacheData(
    String key,
    Future<CacheObject?> Function() currentFuture,
  ) async {
    try {
      var cacheObject = await _getCacheDataFromDatabase(key);
      if (cacheObject?.id != null && !await _fileExists(cacheObject)) {
        try {
          final provider = await _cacheInfoRepository;
          await provider.delete(cacheObject!.id!);
        } catch (e, s) {
          cacheLogger.log(
            'CacheStore: Failed to delete non-existing file metadata for $key with error:\n$e\n$s',
            CacheManagerLogLevel.warning,
          );
        }
        cacheObject = null;
      }

      if (cacheObject == null) {
        _memCache.remove(key);
      } else {
        _memCache[key] = cacheObject;
      }
      return cacheObject;
    } finally {
      if (identical(_futureCache[key], currentFuture())) {
        _futureCache.remove(key);
      }
    }
  }

  Future<FileInfo?> getFileFromMemory(String key) async {
    final cacheObject = _memCache[key];
    if (cacheObject == null) {
      return null;
    }
    final file = await fileSystem.createFile(cacheObject.relativePath);
    return FileInfo(
      file,
      FileSource.Cache,
      cacheObject.validTill,
      cacheObject.url,
    );
  }

  Future<bool> _fileExists(CacheObject? cacheObject) async {
    if (cacheObject == null) {
      return false;
    }
    final file = await fileSystem.createFile(cacheObject.relativePath);
    return file.exists();
  }

  Future<CacheObject?> _getCacheDataFromDatabase(String key) async {
    try {
      final provider = await _cacheInfoRepository;
      final data = await provider.get(key);
      if (await _fileExists(data)) {
        unawaited(
          _updateCacheDataInDatabase(data!).catchError((
            Object e,
            StackTrace s,
          ) {
            cacheLogger.log(
              'CacheStore: Failed to update cache metadata for $key with error:\n$e\n$s',
              CacheManagerLogLevel.warning,
            );
            return null;
          }),
        );
      }
      _scheduleCleanup();
      return data;
    } catch (e, s) {
      cacheLogger.log(
        'CacheStore: Failed to read cache metadata for $key with error:\n$e\n$s',
        CacheManagerLogLevel.warning,
      );
      return null;
    }
  }

  void _scheduleCleanup() {
    if (_scheduledCleanup != null) {
      return;
    }
    _scheduledCleanup = Timer(cleanupRunMinInterval, () {
      _scheduledCleanup = null;
      unawaited(
        _cleanupCache().catchError((Object e, StackTrace s) {
          cacheLogger.log(
            'CacheStore: Failed to cleanup cache with error:\n$e\n$s',
            CacheManagerLogLevel.warning,
          );
        }),
      );
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
    final futures = <Future>[];
    for (final cacheObject in overCapacity) {
      futures.add(_removeCachedFile(cacheObject, toRemove));
    }

    final oldObjects = await provider.getOldObjects(_maxAge);
    for (final cacheObject in oldObjects) {
      futures.add(_removeCachedFile(cacheObject, toRemove));
    }

    await Future.wait(futures);
    await provider.deleteAll(toRemove);
  }

  Future<void> emptyCache() async {
    final provider = await _cacheInfoRepository;
    final toRemove = <int>[];
    final allObjects = await provider.getAllObjects();
    var futures = <Future>[];
    for (final cacheObject in allObjects) {
      futures.add(_removeCachedFile(cacheObject, toRemove));
    }
    await Future.wait(futures);
    await provider.deleteAll(toRemove);
  }

  void emptyMemoryCache() {
    _memCache.clear();
  }

  Future<void> removeCachedFile(CacheObject cacheObject) async {
    final provider = await _cacheInfoRepository;
    final toRemove = <int>[];
    await _removeCachedFile(cacheObject, toRemove);
    await provider.deleteAll(toRemove);
  }

  Future<void> _removeCachedFile(
    CacheObject cacheObject,
    List<int> toRemove,
  ) async {
    if (toRemove.contains(cacheObject.id)) return;

    toRemove.add(cacheObject.id!);
    if (_memCache.containsKey(cacheObject.key)) {
      _memCache.remove(cacheObject.key);
    }
    _futureCache.remove(cacheObject.key);
    final file = await fileSystem.createFile(cacheObject.relativePath);

    if (file.existsSync()) {
      try {
        await file.delete();
        // ignore: unused_catch_clause
      } on PathNotFoundException catch (e) {
        // File has already been deleted. Do nothing #184
      }
    }
  }

  bool memoryCacheContainsKey(String key) {
    return _memCache.containsKey(key);
  }

  Future<void> dispose() async {
    final provider = await _cacheInfoRepository;
    await provider.close();
  }

  Future<int> getCacheSize() async {
    final provider = await _cacheInfoRepository;
    final allObjects = await provider.getAllObjects();
    int total = 0;
    for (var cacheObject in allObjects) {
      total += cacheObject.length ?? 0;
    }
    return total;
  }
}
