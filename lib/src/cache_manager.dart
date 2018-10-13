import 'dart:io';

import 'package:flutter_cache_manager/src/cache_store.dart';
import 'package:flutter_cache_manager/src/file_info.dart';
import 'package:flutter_cache_manager/src/web_helper.dart' as wh;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DefaultCacheManager extends BaseCacheManager {
  static const key = "libCachedImageData";

  static DefaultCacheManager _instance;

  static DefaultCacheManager getInstance() {
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
  BaseCacheManager(this.cacheKey,
      [this.inBetweenCleans = const Duration(days: 7),
      this.maxAgeCacheObject = const Duration(days: 30),
      this.maxNrOfCacheObjects = 200,
      this.showDebugLogs = false]) {
    store = new CacheStore();
  }

  final String cacheKey;
  final Duration inBetweenCleans;
  final Duration maxAgeCacheObject;
  final int maxNrOfCacheObjects;
  final bool showDebugLogs;

  Future<String> getFilePath();

  CacheStore store;

  Future<File> getFile(String url, {Map<String, String> headers}) async {
    var cacheFile = await store.getFile();
    if (cacheFile.file != null) {
      //TODO Check age
      return cacheFile.file;
    }
    var remoteFile = await _downloadAndStoreFile();
    return remoteFile.file;
  }

  ///Get the file from the cache and/or online. Depending on availability and age
  Stream<FileInfo> getFileStream(String url,
      {Map<String, String> headers}) async* {
    yield await store.getFile();
    yield await _downloadAndStoreFile();
  }

  ///Download the file and add to cache
  Future<File> downloadFile(String url, {Map<String, String> headers}) async {
    var fileInfo = await _downloadAndStoreFile();
    return fileInfo.file;
  }

  ///Get the file from the cache
  Future<File> getFileFromCache(String url) async {
    var fileInfo = await store.getFile();
    return fileInfo.file;
  }

  Future<FileInfo> _downloadAndStoreFile() async {
    var fileInfo = await wh.downloadFile();
    store.putFile(fileInfo);
    return fileInfo;
  }
}
