import 'dart:async';
import 'dart:io';

import 'package:flutter_cache_manager/src/cache_object.dart';
import 'package:flutter_cache_manager/src/file_info.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class CacheStore {
  Map<String, Future<CacheObject>> _memCache;

  int _nrOfDbConnections;
  Future<String> filePath;
  Future<CacheObjectProvider> _cacheObjectProvider;
  String storeKey;

  CacheStore(Future<String> basePath, this.storeKey) {
    _memCache = new Map();
    filePath = basePath;
    _nrOfDbConnections = 0;
    _cacheObjectProvider = _getObjectProvider();
  }

  Future<CacheObjectProvider> _getObjectProvider() async {
    var databasesPath = await getDatabasesPath();
    var path = p.join(databasesPath, "$storeKey.db");

    // Make sure the directory exists
    try {
      await Directory(databasesPath).create(recursive: true);
    } catch (_) {}
    return new CacheObjectProvider(path);
  }

  Future<FileInfo> getFile(String url) async {
    var cacheObject = await retrieveCacheData(url);
    if (cacheObject == null) {
      return null;
    }
    var path = p.join(await filePath, cacheObject.relativePath);
    return new FileInfo(
        File(path), FileSource.Cache, cacheObject.validTill, url);
  }

  putFile(CacheObject cacheObject) async {
    _memCache[cacheObject.url] = Future<CacheObject>.value(cacheObject);
    _updateCacheDataInDatabase(cacheObject);
  }

  Future<CacheObject> retrieveCacheData(String url) {
    if (!_memCache.containsKey(url)) {
      var completer = new Completer<CacheObject>();
      _getCacheDataFromDatabase(url).then((cacheObject) {
        completer.complete(cacheObject);
      });

      _memCache[url] = completer.future;
    }
    return _memCache[url];
  }

  Future<CacheObject> _getCacheDataFromDatabase(String url) async {
    var provider = await _openDatabaseConnection();
    var data = await provider.get(url);
    _closeDatabaseConnection();
    return data;
  }

  Future<dynamic> _updateCacheDataInDatabase(CacheObject cacheObject) async {
    var provider = await _openDatabaseConnection();
    var data = await provider.updateOrInsert(cacheObject);
    _closeDatabaseConnection();
    return data;
  }

  Future<CacheObjectProvider> _openDatabaseConnection() async {
    var provider = await _cacheObjectProvider;
    if (_nrOfDbConnections == 0) {
      await provider.open();
    }
    _nrOfDbConnections++;
    return provider;
  }

  _closeDatabaseConnection() async {
    var provider = await _cacheObjectProvider;
    _nrOfDbConnections--;
    if (_nrOfDbConnections == 0) {
      await provider.close();
    }
  }
}
