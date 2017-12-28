// CacheManager for Flutter
// Copyright (c) 2017 Rene Floor
// Released under MIT License.
library flutter_cache_manager;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:synchronized/synchronized.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/cache_object.dart';

class CacheManager {
  static Duration inbetweenCleans = new Duration(days: 7);
  static Duration maxAgeCacheObject = new Duration(days: 30);
  static int maxNrOfCacheObjects = 200;

  static CacheManager _instance;
  static Future<CacheManager> getInstance() async {
    if (_instance == null) {
      await synchronized(_lock, () async {
        if (_instance == null) {
          _instance = new CacheManager._();
          await _instance._init();
        }
      });
    }
    return _instance;
  }

  CacheManager._();

  SharedPreferences _prefs;
  Map<String, CacheObject> _cacheData;
  DateTime lastCacheClean;

  static Object _lock = new Object();

  ///Shared preferences is used to keep track of the information about the files
  _init() async {
    _prefs = await SharedPreferences.getInstance();
    _getSavedCacheDataFromPreferences();
    _getLastCleanTimestampFromPreferences();
  }

  bool _isStoringData = false;
  bool _shouldStoreDataAgain = false;
  Object _storeLock = new Object();

  _getSavedCacheDataFromPreferences(){
    //get saved cache data from shared prefs
    var jsonCacheString = _prefs.getString("lib_cached_image_data");
    _cacheData = new Map();
    if (jsonCacheString != null) {
      Map jsonCache = JSON.decode(jsonCacheString);
      jsonCache.forEach((key, data) {
        _cacheData[key] = new CacheObject.fromMap(key, data);
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
    return await synchronized(_storeLock, () {
      if (_isStoringData) {
        _shouldStoreDataAgain = true;
        return false;
      }
      _isStoringData = true;
      return true;
    });
  }

  Future<bool> _shouldSaveAgain() async {
    return await synchronized(_storeLock, () {
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

    await synchronized(_lock, () {
      _cacheData.forEach((key, cache) {
        json[key] = cache.toMap();
      });
    });
    _prefs.setString("lib_cached_image_data", JSON.encode(json));

    if (await _shouldSaveAgain()) {
      await _saveDataInPrefs();
    }
  }

  _getLastCleanTimestampFromPreferences(){
    // Get data about when the last clean action has been performed
    var cleanMillis = _prefs.getInt("lib_cached_image_data_last_clean");
    if (cleanMillis != null) {
      lastCacheClean = new DateTime.fromMillisecondsSinceEpoch(cleanMillis);
    } else {
      lastCacheClean = new DateTime.now();
      _prefs.setInt("lib_cached_image_data_last_clean",
          lastCacheClean.millisecondsSinceEpoch);
    }
  }

  _cleanCache({force: false}) async {
    var sinceLastClean = new DateTime.now().difference(lastCacheClean);

    if (force ||
        sinceLastClean > inbetweenCleans ||
        _cacheData.length > maxNrOfCacheObjects) {
      await synchronized(_lock, () async {
        await _removeOldObjectsFromCache();
        await _shrinkLargeCache();

        lastCacheClean = new DateTime.now();
        _prefs.setInt("lib_cached_image_data_last_clean",
            lastCacheClean.millisecondsSinceEpoch);
      });
    }
  }

  _removeOldObjectsFromCache() async {
    var oldestDateAllowed = new DateTime.now().subtract(maxAgeCacheObject);

    //Remove old objects
    var oldValues = _cacheData.values
        .where((c) => c.touched.isBefore(oldestDateAllowed));
    for (var oldValue in oldValues) {
      await _removeFile(oldValue);
    }
  }

  _shrinkLargeCache() async{
    //Remove oldest objects when cache contains to many items
    if (_cacheData.length > maxNrOfCacheObjects) {
      var allValues = _cacheData.values.toList();
      allValues.sort((c1, c2) => c2.touched.compareTo(c1.touched));  // sort OLDEST first
      var oldestValues = allValues.take( _cacheData.length - maxNrOfCacheObjects);      // get them
      oldestValues.forEach( (item) async {await _removeFile(item);} );  //remove them
    }
  }

  _removeFile(CacheObject cacheObject) async {
    var file = new File(cacheObject.filePath);
    if (await file.exists()) {
      file.delete();
    }
    _cacheData.remove(cacheObject.url);
  }

  ///Get the file from the cache or online. Depending on availability and age
  Future<File> getFile(String url) async {
    if (!_cacheData.containsKey(url)) {
      await synchronized(_lock, () {
        if (!_cacheData.containsKey(url)) {
          _cacheData[url] = new CacheObject(url);
        }
      });
    }

    var cacheObject = _cacheData[url];
    await synchronized(cacheObject.lock, () async {
      // Set touched date to show that this object is being used recently
      cacheObject.touch();

      //If we have never downloaded this file, do download
      if (cacheObject.filePath == null) {
        _cacheData[url] = await downloadFile(url);
        return;
      }
      //If file is removed from the cache storage, download again
      var cachedFile = new File(cacheObject.filePath);
      var cachedFileExists = await cachedFile.exists();
      if (!cachedFileExists) {
        _cacheData[url] = await downloadFile(url, path: cacheObject.filePath);
        return;
      }
      //If file is old, download if server has newer one
      if (cacheObject.validTill == null ||
          cacheObject.validTill.isBefore(new DateTime.now())) {
        var newCacheData = await downloadFile(url,
            path: cacheObject.filePath, eTag: cacheObject.eTag);
        if (newCacheData != null) {
          _cacheData[url] = newCacheData;
        }
        return;
      }
    });

    //If non of the above is true, than we don't have to download anything.
    _save();
    return new File(_cacheData[url].filePath);
  }

  ///Download the file from the url
  Future<CacheObject> downloadFile(String url,
      {String path, String eTag}) async {
    var newCache = new CacheObject(url);
    newCache.setPath(path);
    var headers = new Map<String, String>();
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
        await new File(newCache.filePath).writeAsBytes(response.bodyBytes);

        return newCache;
      }
      if (response.statusCode == 304) {
        newCache.setDataFromHeaders(response.headers);
        return newCache;
      }
    }

    return null;
  }
}
