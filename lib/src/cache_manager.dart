import 'dart:io';

import 'package:flutter_cache_manager/src/cache_store.dart';
import 'package:flutter_cache_manager/src/file_info.dart';
import 'package:flutter_cache_manager/src/web_helper.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DefaultCacheManager extends BaseCacheManager {
  static const key = "libCachedImageData";

  static DefaultCacheManager _instance;

  factory DefaultCacheManager() {
    if (_instance == null) {
      _instance = new DefaultCacheManager._();
    }
    return _instance;
  }

  DefaultCacheManager._() : super(key);

  Future<String> getFilePath() async {
    var directory = await getTemporaryDirectory();
    return p.join(directory.path, key);
  }
}

abstract class BaseCacheManager {
  Future<String> _fileBasePath;

  BaseCacheManager(this._cacheKey,
      [this._inBetweenCleans = const Duration(days: 7),
      this._maxAgeCacheObject = const Duration(days: 30),
      this._maxNrOfCacheObjects = 200,
      this._showDebugLogs = false]) {
    _fileBasePath = getFilePath();
    store = new CacheStore(_fileBasePath, _cacheKey);
    webHelper = new WebHelper(store);
  }

  final String _cacheKey;
  final Duration _inBetweenCleans;
  final Duration _maxAgeCacheObject;
  final int _maxNrOfCacheObjects;
  final bool _showDebugLogs;

  Future<String> getFilePath();

  CacheStore store;
  WebHelper webHelper;

  Future<File> getFile(String url, {Map<String, String> headers}) async {
    var cacheFile = await store.getFile(url);
    if (cacheFile.file != null) {
      //TODO Check age
      return cacheFile.file;
    }
    var remoteFile = await webHelper.downloadFile();
    return remoteFile.file;
  }

  ///Get the file from the cache and/or online. Depending on availability and age
  Stream<FileInfo> getFileStream(String url,
      {Map<String, String> headers}) async* {
    yield await getFileFromCache(url);
    yield await webHelper.downloadFile();
  }

  ///Download the file and add to cache
  Future<File> downloadFile(String url, {Map<String, String> headers}) async {
    var fileInfo = await webHelper.downloadFile();
    return fileInfo.file;
  }

  ///Get the file from the cache
  Future<FileInfo> getFileFromCache(String url) async {
    var fileInfo = await store.getFile(url);
    return fileInfo;
  }
}
