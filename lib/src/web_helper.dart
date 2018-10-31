import 'dart:async';
import 'dart:io';

import 'package:flutter_cache_manager/src/cache_object.dart';
import 'package:flutter_cache_manager/src/cache_store.dart';
import 'package:flutter_cache_manager/src/file_info.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class WebHelper {
  CacheStore _store;
  Map<String, Future<FileInfo>> _memCache;

  WebHelper(this._store) {
    _memCache = new Map();
  }

  ///Download the file from the url
  Future<FileInfo> downloadFile(String url,
      {Map<String, String> authHeaders}) async {
    if (!_memCache.containsKey(url)) {
      var completer = new Completer<FileInfo>();
      _downloadRemoteFile(url).then((cacheObject) {
        completer.complete(cacheObject);
      });

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

    var headers = new Map();
    if (authHeaders != null) {
      headers.addAll(authHeaders);
    }

    if (cacheObject.eTag != null) {
      headers["If-None-Match"] = cacheObject.eTag;
    }

    var success = false;
    try {
      var response = await http.get(url, headers: headers);
      success = await _handleHttpResponse(response, cacheObject);
    } catch (e) {}

    if (!success) {
      return null;
    }

    _store.putFile(cacheObject);
    var filePath = p.join(await _store.filePath, cacheObject.relativePath);

    return FileInfo(
        new File(filePath), FileSource.Online, cacheObject.validTill, url);
  }

  Future<bool> _handleHttpResponse(
      http.Response response, CacheObject cacheObject) async {
    if (response.statusCode == 200) {
      var basePath = await _store.filePath;
      _setDataFromHeaders(cacheObject, response.headers);
      var path = p.join(basePath, cacheObject.relativePath);

      var folder = new File(path).parent;
      if (!(await folder.exists())) {
        folder.createSync(recursive: true);
      }
      await new File(path).writeAsBytes(response.bodyBytes);
      return true;
    }
    if (response.statusCode == 304) {
      await _setDataFromHeaders(cacheObject, response.headers);
      return true;
    }
    return false;
  }

  _setDataFromHeaders(
      CacheObject cacheObject, Map<String, String> headers) async {
    //Without a cache-control header we keep the file for a week
    var ageDuration = new Duration(days: 7);

    if (headers.containsKey("cache-control")) {
      var cacheControl = headers["cache-control"];
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

    if (headers.containsKey("etag")) {
      cacheObject.eTag = headers["etag"];
    }

    var fileExtension = "";
    if (headers.containsKey("content-type")) {
      var type = headers["content-type"].split("/");
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
      cacheObject.relativePath = "${new Uuid().v1()}${fileExtension}";
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
