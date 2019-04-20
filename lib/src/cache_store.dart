import 'dart:async';
import 'dart:io';

import 'package:flutter_cache_manager/src/cache_object.dart';
import 'package:flutter_cache_manager/src/file_info.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:synchronized/synchronized.dart';

///Flutter Cache Manager
///Copyright (c) 2019 Rene Floor
///Released under MIT License.

class CacheStore {
  Map<String, CacheObject> _memCache = new Map();

  int _nrOfDbConnections = 0;
  Future<String> filePath;
  Future<CacheObjectProvider> _cacheObjectProvider;
  String storeKey;

  int _capacity;
  Duration _maxAge;

  CacheStore(
      Future<String> basePath, this.storeKey, this._capacity, this._maxAge) {
    filePath = basePath;
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
    if (cacheObject == null || cacheObject.relativePath == null) {
      return null;
    }
    var path = p.join(await filePath, cacheObject.relativePath);
    return new FileInfo(
        File(path), FileSource.Cache, cacheObject.validTill, url);
  }

  putFile(CacheObject cacheObject) async {
    _memCache[cacheObject.url] = cacheObject;
    _updateCacheDataInDatabase(cacheObject);
  }

  Future<CacheObject> retrieveCacheData(String url) {
    if (!_memCache.containsKey(url)) {
      var completer = new Completer<CacheObject>();
      _getCacheDataFromDatabase(url).then((cacheObject) async {
        if (cacheObject != null && !await _fileExists(cacheObject)) {
          cacheObject = new CacheObject(url, id: cacheObject.id);
        }
        _memCache[url] = cacheObject;
        completer.complete(cacheObject);
      });
      return completer.future;
    } else {
      return Future<CacheObject>.value(_memCache[url]);
    }
  }

  Future<bool> _fileExists(CacheObject cacheObject) async {
    if (cacheObject?.relativePath == null) {
      return false;
    }
    return new File(p.join(await filePath, cacheObject.relativePath)).exists();
  }

  Future<CacheObject> _getCacheDataFromDatabase(String url) async {
    var provider = await _openDatabaseConnection();
    var data = await provider.get(url);
    if (await _fileExists(data)) {
      _updateCacheDataInDatabase(data);
    }
    _closeDatabaseConnection();
    return data;
  }

  Future<dynamic> _updateCacheDataInDatabase(CacheObject cacheObject) async {
    var provider = await _openDatabaseConnection();
    var data = await provider.updateOrInsert(cacheObject);
    _closeDatabaseConnection();
    return data;
  }

  var databaseConnectionLock = Lock();
  Future<CacheObjectProvider> _openDatabaseConnection() async {
    var provider = await _cacheObjectProvider;
    if (_nrOfDbConnections == 0) {
      await databaseConnectionLock.synchronized(() async {
        if (_nrOfDbConnections == 0) {
          await provider.open();
        }
        _nrOfDbConnections++;
      });
    } else {
      _nrOfDbConnections++;
    }
    return provider;
  }

  _closeDatabaseConnection() async {
    if (_nrOfDbConnections == 1) {
      await databaseConnectionLock.synchronized(() {
        _nrOfDbConnections--;
        if (_nrOfDbConnections == 0) {
          _cleanAndClose();
        }
      });
    } else {
      _nrOfDbConnections--;
    }
  }

  _cleanAndClose() async {
    _nrOfDbConnections++;
    var provider = await _cacheObjectProvider;
    var overCapacity = await provider.getObjectsOverCapacity(_capacity);
    var oldObjects = await provider.getOldObjects(_maxAge);

    var toRemove = List<int>();
    overCapacity.forEach((cacheObject) async {
      _removeCachedFile(cacheObject, toRemove);
    });
    oldObjects.forEach((cacheObject) async {
      _removeCachedFile(cacheObject, toRemove);
    });

    await provider.deleteAll(toRemove);
    await databaseConnectionLock.synchronized(() async {
      _nrOfDbConnections--;
      if (_nrOfDbConnections == 0) {
        await provider.close();
      }
    });
  }

  emptyCache() async {
    var provider = await _openDatabaseConnection();
    var toRemove = List<int>();

    var allObjects = await provider.getAllObjects();
    allObjects.forEach((cacheObject) async {
      _removeCachedFile(cacheObject, toRemove);
    });

    await provider.deleteAll(toRemove);
    _closeDatabaseConnection();
  }

  removeCachedFile(CacheObject cacheObject) async {
    var provider = await _openDatabaseConnection();
    var toRemove = List<int>();
    _removeCachedFile(cacheObject, toRemove);
    await provider.deleteAll(toRemove);
    _closeDatabaseConnection();
  }

  _removeCachedFile(CacheObject cacheObject, List<int> toRemove) async {
    if (!toRemove.contains(cacheObject.id)) {
      toRemove.add(cacheObject.id);
      if (_memCache.containsKey(cacheObject.url))
        _memCache.remove(cacheObject.url);
    }
    var file = new File(p.join(await filePath, cacheObject.relativePath));
    if (await file.exists()) {
      file.delete();
    }
  }
}
