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
      () async {
        try {
          final cacheObject =
              await _downloadRemoteFile(url, authHeaders: authHeaders);
          completer.complete(cacheObject);
        } catch (e) {
          completer.completeError(e);
        } finally {
          _memCache.remove(url);
        }
      }();

      _memCache[url] = completer.future;
    }
    return _memCache[url];
  }

  ///Download the file from the url
  Future<FileInfo> _downloadRemoteFile(String url,
      {Map<String, String> authHeaders}) async {
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
      throw HttpExceptionWithStatus(
        response.statusCode,
        "Invalid statusCode: ${response?.statusCode}",
        uri: Uri.parse(url),
      );
    }

    _store.putFile(cacheObject);
    var filePath = p.join(await _store.filePath, cacheObject.relativePath);

    return FileInfo(
        new File(filePath), FileSource.Online, cacheObject.validTill, url);
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

  _setDataFromHeaders(
      CacheObject cacheObject, FileFetcherResponse response) async {
    //Without a cache-control header we keep the file for a week
    var ageDuration = new Duration(days: 7);

    if (response.hasHeader("cache-control")) {
      var cacheControl = response.header("cache-control");
      var controlSettings = cacheControl.split(", ");
      controlSettings.forEach((setting) {
        if (setting.startsWith("max-age=")) {
          var validSeconds = int.tryParse(setting.split("=")[1]) ?? 0;
          if (validSeconds > 0) {
            ageDuration = new Duration(seconds: validSeconds);
          }
        }
      });
    }

    cacheObject.validTill = new DateTime.now().add(ageDuration);

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

class HttpExceptionWithStatus extends HttpException {
  const HttpExceptionWithStatus(this.statusCode, String message, {Uri uri}) : super(message, uri: uri);
  final int statusCode;
}
