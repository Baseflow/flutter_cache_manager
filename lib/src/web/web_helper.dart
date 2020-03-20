import 'dart:async';
import 'dart:io';

import 'package:flutter_cache_manager/src/storage/cache_object.dart';
import 'package:flutter_cache_manager/src/cache_store.dart';
import 'package:flutter_cache_manager/src/web/file_fetcher.dart';
import 'package:flutter_cache_manager/src/file_info.dart';
import 'package:pedantic/pedantic.dart';
import 'package:uuid/uuid.dart';

///Flutter Cache Manager
///Copyright (c) 2019 Rene Floor
///Released under MIT License.

class WebHelper {
  WebHelper(this._store, FileService fileFetcher)
      : _memCache = {},
        _fileFetcher = fileFetcher ?? HttpFileFetcher();

  final CacheStore _store;
  final FileService _fileFetcher;
  final Map<String, Future<FileInfo>> _memCache;

  ///Download the file from the url
  Future<FileInfo> downloadFile(String url,
      {Map<String, String> authHeaders, bool ignoreMemCache = false}) async {
    if (!_memCache.containsKey(url) || ignoreMemCache) {
      var completer = Completer<FileInfo>();
      unawaited(() async {
        try {
          final cacheObject =
              await _downloadRemoteFile(url, authHeaders: authHeaders);
          completer.complete(cacheObject);
        } catch (e) {
          completer.completeError(e);
        } finally {
          unawaited(_memCache.remove(url));
        }
      }());
      _memCache[url] = completer.future;
    }
    return _memCache[url];
  }

  ///Download the file from the url
  Future<FileInfo> _downloadRemoteFile(String url,
      {Map<String, String> authHeaders}) async {
    var cacheObject = await _store.retrieveCacheData(url);
    cacheObject ??= CacheObject(url);

    final headers = <String, String>{};
    if (authHeaders != null) {
      headers.addAll(authHeaders);
    }

    if (cacheObject.eTag != null) {
      headers['If-None-Match'] = cacheObject.eTag;
    }

    final response = await _fileFetcher.get(url, headers: headers);
    final success = await _handleHttpResponse(response, cacheObject);
    if (!success) {
      throw HttpExceptionWithStatus(
        response.statusCode,
        'Invalid statusCode: ${response?.statusCode}',
        uri: Uri.parse(url),
      );
    }

    unawaited(_store.putFile(cacheObject));

    final file = (await _store.fileDir).childFile(cacheObject.relativePath);
    return FileInfo(file, FileSource.Online, cacheObject.validTill, url);
  }

  Future<bool> _handleHttpResponse(
      FileFetcherResponse response, CacheObject cacheObject) async {
    if (response.statusCode == 200 || response.statusCode == 201) {
      final basePath = await _store.fileDir;
      unawaited(_setDataFromHeaders(cacheObject, response));
      final file = basePath.childFile(cacheObject.relativePath);
      final folder = file.parent;
      if (!(await folder.exists())) {
        folder.createSync(recursive: true);
      }

      final sink = file.openWrite();
      await sink.addStream(response.content);
      await sink.close();

      return true;
    }
    if (response.statusCode == 304) {
      await _setDataFromHeaders(cacheObject, response);
      return true;
    }
    return false;
  }

  Future<void> _setDataFromHeaders(
      CacheObject cacheObject, FileFetcherResponse response) async {
    cacheObject.validTill = response.validTill;
    cacheObject.eTag = response.eTag;
    final fileExtension = response.fileExtension;

    final oldPath = cacheObject.relativePath;
    if (oldPath != null && !oldPath.endsWith(fileExtension)) {
      unawaited(_removeOldFile(oldPath));
      cacheObject.relativePath = null;
    }

    cacheObject.relativePath ??= '${Uuid().v1()}$fileExtension';
  }

  Future<void> _removeOldFile(String relativePath) async {
    final file = (await _store.fileDir).childFile(relativePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

class HttpExceptionWithStatus extends HttpException {
  const HttpExceptionWithStatus(this.statusCode, String message, {Uri uri})
      : super(message, uri: uri);
  final int statusCode;
}
