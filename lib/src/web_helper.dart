import 'dart:async';
import 'dart:io';

import 'package:flutter_cache_manager/src/cache_object.dart';
import 'package:flutter_cache_manager/src/cache_store.dart';
import 'package:flutter_cache_manager/src/file_fetcher.dart';
import 'package:flutter_cache_manager/src/file_info.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

///Flutter Cache Manager
///Copyright (c) 2019 Rene Floor
///Released under MIT License.

class WebHelper {
  CacheStore _store;
  FileFetcher _fileFetcher;
  Map<String, Future<FileInfo>> _memCache;

  WebHelper(this._store, this._fileFetcher) {
    _memCache = new Map();
    if (_fileFetcher == null) {
      _fileFetcher = _defaultHttpGetter;
    }
  }

  ///Download the file from the url
  Future<FileInfo> downloadFile(String url,
      {Map<String, String> authHeaders, bool ignoreMemCache = false}) async {
    if (!_memCache.containsKey(url) || ignoreMemCache) {
      var completer = new Completer<FileInfo>();
      _downloadRemoteFile(url, authHeaders: authHeaders).then((cacheObject) {
        completer.complete(cacheObject);
      }).catchError((e) {
        completer.completeError(e);
      }).whenComplete(() {
        _memCache.remove(url);
      });

      _memCache[url] = completer.future;
    }
    return _memCache[url];
  }

  ///Download the file from the url
  Future<FileInfo> _downloadRemoteFile(String url,
      {Map<String, String> authHeaders}) async {
    return Future.sync(() async {
      var cacheObject = await _store.retrieveCacheData(url);
      if (cacheObject == null) {
        cacheObject = new CacheObject(url);
      }

      var headers = new Map<String, String>();
      if (authHeaders != null) {
        headers.addAll(authHeaders);
      }

      if (cacheObject.eTag != null) {
        headers["If-None-Match"] = cacheObject.eTag;
      }

      var success = false;

      var response = await _fileFetcher(url, headers: headers);
      success = await _handleHttpResponse(response, cacheObject);

      if (!success) {
        throw HttpException(
            "No valid statuscode. Statuscode was ${response?.statusCode}");
      }

      _store.putFile(cacheObject);
      var filePath = p.join(await _store.filePath, cacheObject.relativePath);

      return FileInfo(
          new File(filePath), FileSource.Online, cacheObject.validTill, url);
    });
  }

  Future<FileFetcherResponse> _defaultHttpGetter(String url,
      {Map<String, String> headers}) async {
    var httpResponse = await http.get(url, headers: headers);
    return new HttpFileFetcherResponse(httpResponse);
  }

  Future<bool> _handleHttpResponse(
      FileFetcherResponse response, CacheObject cacheObject) async {
    if (response.statusCode == 200 || response.statusCode == 201) {
      var basePath = await _store.filePath;
      _setDataFromHeaders(cacheObject, response);
      var path = p.join(basePath, cacheObject.relativePath);

      var folder = new File(path).parent;
      if (!(await folder.exists())) {
        folder.createSync(recursive: true);
      }
      await new File(path).writeAsBytes(response.bodyBytes);
      return true;
    }
    if (response.statusCode == 304) {
      await _setDataFromHeaders(cacheObject, response);
      return true;
    }
    return false;
  }

  _setDataFromHeaders(CacheObject cacheObject, FileFetcherResponse response) async {
    // Without a valid cache-control header we keep the file for a week
    cacheObject.validTill = DateTime.now().add(response.maxAge ?? const Duration(days: 7));

    if (response.hasHeader("etag")) {
      cacheObject.eTag = response.header("etag");
    }

    var fileExtension = "";
    if (response.hasHeader("content-type")) {
      var type = response.header("content-type").split("/");
      if (type.length == 2) {
        fileExtension = ".${type[1]}";
      }
    }

    var oldPath = cacheObject.relativePath;
    if (oldPath != null && !oldPath.endsWith(fileExtension)) {
      _removeOldFile(oldPath);
      cacheObject.relativePath = null;
    }

    if (cacheObject.relativePath == null) {
      cacheObject.relativePath = "${new Uuid().v1()}$fileExtension";
    }
  }

  _removeOldFile(String relativePath) async {
    var path = p.join(await _store.filePath, relativePath);
    var file = new File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
