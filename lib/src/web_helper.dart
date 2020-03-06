import 'dart:async';
import 'dart:io';

import 'package:file/file.dart' as f;
import 'package:flutter_cache_manager/src/storage/cache_object.dart';
import 'package:flutter_cache_manager/src/cache_store.dart';
import 'package:flutter_cache_manager/src/file_fetcher.dart';
import 'package:flutter_cache_manager/src/file_info.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:pedantic/pedantic.dart';
import 'package:uuid/uuid.dart';

///Flutter Cache Manager
///Copyright (c) 2019 Rene Floor
///Released under MIT License.

class WebHelper {
  WebHelper(this._store, FileFetcher fileFetcher)
      : _memCache = {},
        _fileFetcher = fileFetcher ?? _defaultHttpGetter;

  final CacheStore _store;
  final FileFetcher _fileFetcher;
  final Map<String, Future<FileInfo>> _memCache;

  ///Download the file from the url
  Future<FileInfo> downloadFile(String url, {Map<String, String> authHeaders, bool ignoreMemCache = false}) async {
    if (!_memCache.containsKey(url) || ignoreMemCache) {
      var completer = Completer<FileInfo>();
      unawaited(() async {
        try {
          final cacheObject = await _downloadRemoteFile(url, authHeaders: authHeaders);
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
  Future<FileInfo> _downloadRemoteFile(String url, {Map<String, String> authHeaders}) async {
    var cacheObject = await _store.retrieveCacheData(url);
    cacheObject ??= CacheObject(url);

    final headers = <String, String>{};
    if (authHeaders != null) {
      headers.addAll(authHeaders);
    }

    if (cacheObject.eTag != null) {
      headers['If-None-Match'] = cacheObject.eTag;
    }

    final response = await _fileFetcher(url, headers: headers);
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

  static Future<FileFetcherResponse> _defaultHttpGetter(String url, {Map<String, String> headers}) async {
    final httpResponse = await http.get(url, headers: headers);
    return HttpFileFetcherResponse(httpResponse);
  }

  Future<bool> _handleHttpResponse(FileFetcherResponse response, CacheObject cacheObject) async {
    if (response.statusCode == 200 || response.statusCode == 201) {
      final basePath = await _store.fileDir;
      unawaited(_setDataFromHeaders(cacheObject, response));
      final file = basePath.childFile(cacheObject.relativePath);
      final folder = file.parent;
      if (!(await folder.exists())) {
        folder.createSync(recursive: true);
      }
      await file.writeAsBytes(response.bodyBytes);
      return true;
    }
    if (response.statusCode == 304) {
      await _setDataFromHeaders(cacheObject, response);
      return true;
    }
    return false;
  }

  Future<void> _setDataFromHeaders(CacheObject cacheObject, FileFetcherResponse response) async {
    // Without a cache-control header we keep the file for a week
    var ageDuration = const Duration(days: 7);
    if (response.hasHeader('cache-control')) {
      final controlSettings = response.header('cache-control').split(', ');
      for (final setting in controlSettings) {
        if (setting.startsWith('max-age=')) {
          final validSeconds = int.tryParse(setting.split('=')[1]) ?? 0;
          if (validSeconds > 0) {
            ageDuration = Duration(seconds: validSeconds);
          }
        }
      }
    }

    cacheObject.validTill = DateTime.now().add(ageDuration);

    if (response.hasHeader('etag')) {
      cacheObject.eTag = response.header('etag');
    }

    var fileExtension = '';
    if (response.hasHeader('content-type')) {
      final type = response.header('content-type').split('/');
      if (type.length == 2) {
        fileExtension = '.${type[1]}';
      }
    }

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
  const HttpExceptionWithStatus(this.statusCode, String message, {Uri uri}) : super(message, uri: uri);
  final int statusCode;
}
