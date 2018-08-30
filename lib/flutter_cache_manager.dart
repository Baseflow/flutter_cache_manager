// CacheManager for Flutter
// Copyright (c) 2017 Rene Floor
// Released under MIT License.
library flutter_cache_manager;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';

import 'src/cache_object.dart';

class CacheManager {
  static const _keyCacheData = "lib_cached_image_data";
  static const _keyCacheCleanDate = "lib_cached_image_data_last_clean";

  static Duration inBetweenCleans = new Duration(days: 7);
  static Duration maxAgeCacheObject = new Duration(days: 30);
  static int maxNrOfCacheObjects = 200;
  static bool showDebugLogs = false;

  static CacheManager _instance;

  static Future<CacheManager> getInstance() async {
    if (_instance == null) {
      await _lock.synchronized(() async {
        if (_instance == null) {
          // keep local instance till it is fully initialized
          var newInstance = new CacheManager._();
          await newInstance._init();
          _instance = newInstance;
        }
      });
    }
    return _instance;
  }

  CacheManager._();

  SharedPreferences _prefs;
  Map<String, CacheObject> _cacheData;
  DateTime lastCacheClean;

  static Lock _lock = new Lock();

  ///Shared preferences is used to keep track of the information about the files
  Future _init() async {
    _prefs = await SharedPreferences.getInstance();
    _getSavedCacheDataFromPreferences();
    _getLastCleanTimestampFromPreferences();
  }

  bool _isStoringData = false;
  bool _shouldStoreDataAgain = false;
  Lock _storeLock = new Lock();

  _getSavedCacheDataFromPreferences() {
    //get saved cache data from shared prefs
    var jsonCacheString = _prefs.getString(_keyCacheData);
    _cacheData = new Map();
    if (jsonCacheString != null) {
      Map jsonCache = const JsonDecoder().convert(jsonCacheString);
      jsonCache.forEach((key, data) {
        if (data != null) {
          _cacheData[key] = new CacheObject.fromMap(key, data);
        }
      });
    }
  }

  ///Store all data to shared preferences
  _save() async {
    if (!(await _canSave())) {
      return;
    }

    await _cleanCache();
    await _saveDataInPrefs();
  }

  Future<bool> _canSave() async {
    return await _storeLock.synchronized(() {
      if (_isStoringData) {
        _shouldStoreDataAgain = true;
        return false;
      }
      _isStoringData = true;
      return true;
    });
  }

  Future<bool> _shouldSaveAgain() async {
    return await _storeLock.synchronized(() {
      if (_shouldStoreDataAgain) {
        _shouldStoreDataAgain = false;
        return true;
      }
      _isStoringData = false;
      return false;
    });
  }

  _saveDataInPrefs() async {
    Map json = new Map();

    await _lock.synchronized(() {
      _cacheData.forEach((key, cache) {
        json[key] = cache?.toMap();
      });
    });

    _prefs.setString(_keyCacheData, const JsonEncoder().convert(json));

    if (await _shouldSaveAgain()) {
      await _saveDataInPrefs();
    }
  }

  _getLastCleanTimestampFromPreferences() {
    // Get data about when the last clean action has been performed
    var cleanMillis = _prefs.getInt(_keyCacheCleanDate);
    if (cleanMillis != null) {
      lastCacheClean = new DateTime.fromMillisecondsSinceEpoch(cleanMillis);
    } else {
      lastCacheClean = new DateTime.now();
      _prefs.setInt(_keyCacheCleanDate, lastCacheClean.millisecondsSinceEpoch);
    }
  }

  _cleanCache({force: false}) async {
    var sinceLastClean = new DateTime.now().difference(lastCacheClean);

    if (force ||
        sinceLastClean > inBetweenCleans ||
        _cacheData.length > maxNrOfCacheObjects) {
      await _lock.synchronized(() async {
        await _removeOldObjectsFromCache();
        await _shrinkLargeCache();

        lastCacheClean = new DateTime.now();
        _prefs.setInt(
            _keyCacheCleanDate, lastCacheClean.millisecondsSinceEpoch);
      });
    }
  }

  _removeOldObjectsFromCache() async {
    var oldestDateAllowed = new DateTime.now().subtract(maxAgeCacheObject);

    //Remove old objects
    var oldValues = List.from(
        _cacheData.values.where((c) => c.touched.isBefore(oldestDateAllowed)));
    for (var oldValue in oldValues) {
      await _removeFile(oldValue);
    }
  }

  _shrinkLargeCache() async {
    //Remove oldest objects when cache contains to many items
    if (_cacheData.length > maxNrOfCacheObjects) {
      var allValues = _cacheData.values.toList();
      allValues.sort(
          (c1, c2) => c1.touched.compareTo(c2.touched)); // sort OLDEST first
      var oldestValues = List.from(
          allValues.take(_cacheData.length - maxNrOfCacheObjects)); // get them
      oldestValues.forEach((item) async {
        await _removeFile(item);
      }); //remove them
    }
  }

  _removeFile(CacheObject cacheObject) async {
    //Ensure the file has been downloaded
    if (cacheObject.relativePath == null) {
      return;
    }

    _cacheData.remove(cacheObject.url);

    var file = new File(await cacheObject.getFilePath());
    if (await file.exists()) {
      file.delete();
    }
  }

  ///Get the file from the cache or online. Depending on availability and age
  Future<File> getFile(String url, {Map<String, String> headers}) async {
    String log = "[Flutter Cache Manager] Loading $url";

    if (!_cacheData.containsKey(url)) {
      await _lock.synchronized(() {
        if (!_cacheData.containsKey(url)) {
          _cacheData[url] = new CacheObject(url);
        }
      });
    }

    var cacheObject = _cacheData[url];
    await cacheObject.lock.synchronized(() async {
      // Set touched date to show that this object is being used recently
      cacheObject.touch();

      if (headers == null) {
        headers = new Map();
      }

      var filePath = await cacheObject.getFilePath();
      //If we have never downloaded this file, do download
      if (filePath == null) {
        log = "$log\nDownloading for first time.";
        var newCacheData = await _downloadFile(url, headers, cacheObject.lock);
        if (newCacheData != null) {
          _cacheData[url] = newCacheData;
        }
        return;
      }
      //If file is removed from the cache storage, download again
      var cachedFile = new File(filePath);
      var cachedFileExists = await cachedFile.exists();
      if (!cachedFileExists) {
        log = "$log\nDownloading because file does not exist.";
        var newCacheData = await _downloadFile(url, headers, cacheObject.lock,
            relativePath: cacheObject.relativePath);
        if (newCacheData != null) {
          _cacheData[url] = newCacheData;
        }

        log =
            "$log\Cache file valid till ${_cacheData[url].validTill?.toIso8601String() ?? "only once.. :("}";
        return;
      }
      //If file is old, download if server has newer one
      if (cacheObject.validTill == null ||
          cacheObject.validTill.isBefore(new DateTime.now())) {
        log = "$log\nUpdating file in cache.";
        var newCacheData = await _downloadFile(url, headers, cacheObject.lock,
            relativePath: cacheObject.relativePath, eTag: cacheObject.eTag);
        if (newCacheData != null) {
          _cacheData[url] = newCacheData;
        }
        log =
            "$log\nNew cache file valid till ${_cacheData[url].validTill?.toIso8601String() ?? "only once.. :("}";
        return;
      }
      log =
          "$log\nUsing file from cache.\nCache valid till ${_cacheData[url].validTill?.toIso8601String() ?? "only once.. :("}";
    });

    //If non of the above is true, than we don't have to download anything.
    _save();
    if (showDebugLogs) print(log);

    var path = await _cacheData[url].getFilePath();
    if (path == null) {
      return null;
    }
    return new File(path);
  }

  ///Download the file from the url
  Future<CacheObject> _downloadFile(
      String url, Map<String, String> headers, Object lock,
      {String relativePath, String eTag}) async {
    var newCache = new CacheObject(url, lock: lock);
    newCache.setRelativePath(relativePath);

    if (eTag != null) {
      headers["If-None-Match"] = eTag;
    }

    var response;
    try {
      response = await http.get(url, headers: headers);
    } catch (e) {}
    if (response != null) {
      if (response.statusCode == 200) {
        await newCache.setDataFromHeaders(response.headers);

        var filePath = await newCache.getFilePath();
        var folder = new File(filePath).parent;
        if (!(await folder.exists())) {
          folder.createSync(recursive: true);
        }
        await new File(filePath).writeAsBytes(response.bodyBytes);

        return newCache;
      }
      if (response.statusCode == 304) {
        await newCache.setDataFromHeaders(response.headers);
        return newCache;
      }
    }

    return null;
  }
}
