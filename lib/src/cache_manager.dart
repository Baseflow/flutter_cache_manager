import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_cache_manager/src/cache_object.dart';
import 'package:flutter_cache_manager/src/cache_store.dart';
import 'package:flutter_cache_manager/src/file_info.dart';
import 'package:flutter_cache_manager/src/web_helper.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

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
      [this._maxAgeCacheObject = const Duration(days: 30),
      this._maxNrOfCacheObjects = 200,
      HttpGetter httpGetter]) {
    _fileBasePath = getFilePath();
    store = new CacheStore(
        _fileBasePath, _cacheKey, _maxNrOfCacheObjects, _maxAgeCacheObject);
    webHelper = new WebHelper(store, httpGetter);
  }

  final String _cacheKey;
  final Duration _maxAgeCacheObject;
  final int _maxNrOfCacheObjects;

  Future<String> getFilePath();

  CacheStore store;
  WebHelper webHelper;

  ///Get the file from the cache and/or online. Depending on availability and age
  Future<File> getSingleFile(String url, {Map<String, String> headers}) async {
    var cacheFile = await getFileFromCache(url);
    if (cacheFile != null && cacheFile.validTill.isAfter(DateTime.now())) {
      return cacheFile.file;
    }
    return (await webHelper.downloadFile(url, authHeaders: headers))?.file;
  }

  ///Get the file from the cache and/or online. Depending on availability and age
  Stream<FileInfo> getFile(String url, {Map<String, String> headers}) async* {
    var cacheFile = await getFileFromCache(url);
    if (cacheFile != null) {
      yield cacheFile;
    }
    if (cacheFile == null || cacheFile.validTill.isBefore(DateTime.now())) {
      var webFile = await webHelper.downloadFile(url, authHeaders: headers);
      if (webFile != null) {
        yield webFile;
      }
      if (webFile == null && cacheFile == null) {
        yield new FileInfo(null, FileSource.NA, null, url);
      }
    }
  }

  ///Download the file and add to cache
  Future<FileInfo> downloadFile(String url,
      {Map<String, String> authHeaders, bool force = false}) async {
    return await webHelper.downloadFile(url,
        authHeaders: authHeaders, ignoreMemCache: force);
  }

  ///Get the file from the cache
  Future<FileInfo> getFileFromCache(String url) async {
    return await store.getFile(url);
  }

  putFile(String url, Uint8List fileBytes,
      {String eTag,
      Duration maxAge = const Duration(days: 30),
      String fileExtension = "file"}) async {
    var cacheObject = await store.retrieveCacheData(url);
    if (cacheObject == null) {
      var relativePath = "${new Uuid().v1()}.$fileExtension";
      cacheObject = new CacheObject(url, relativePath: relativePath);
    }
    cacheObject.validTill = DateTime.now().add(maxAge);
    cacheObject.eTag = eTag;

    var path = p.join(await getFilePath(), cacheObject.relativePath);
    var folder = new File(path).parent;
    if (!(await folder.exists())) {
      folder.createSync(recursive: true);
    }
    var file = await new File(path).writeAsBytes(fileBytes);

    store.putFile(cacheObject);

    return file;
  }

  removeFile(String url) async {
    var cacheObject = await store.retrieveCacheData(url);
    if (cacheObject != null) {
      await store.removeCachedFile(cacheObject);
    }
  }
}
