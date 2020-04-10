import 'dart:async';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_cache_manager/src/result/file_response.dart';
import 'package:flutter_cache_manager/src/storage/cache_object.dart';
import 'package:flutter_cache_manager/src/cache_store.dart';
import 'package:flutter_cache_manager/src/web/file_service.dart';
import 'package:flutter_cache_manager/src/result/file_info.dart';
import 'package:pedantic/pedantic.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

///Flutter Cache Manager
///Copyright (c) 2019 Rene Floor
///Released under MIT License.

const statusCodesNewFile = [HttpStatus.ok, HttpStatus.accepted];
const statusCodesFileNotChanged = [HttpStatus.notModified];

class WebHelper {
  WebHelper(this._store, FileService fileFetcher)
      : _memCache = {},
        _fileFetcher = fileFetcher ?? HttpFileService();

  final CacheStore _store;
  final FileService _fileFetcher;
  final Map<String, BehaviorSubject<FileResponse>> _memCache;

  ///Download the file from the url
  Stream<FileResponse> downloadFile(String url,
      {Map<String, String> authHeaders, bool ignoreMemCache = false}) {
    if (!_memCache.containsKey(url) || ignoreMemCache) {
      var subject = BehaviorSubject<FileResponse>();
      _memCache[url] = subject;

      unawaited(() async {
        try {
          await for (var result in _updateFile(url, authHeaders: authHeaders)) {
            subject.add(result);
          }
        } catch (e, stackTrace) {
          subject.addError(e, stackTrace);
        } finally {
          await subject.close();
          _memCache.remove(url);
        }
      }());
    }
    return _memCache[url].stream;
  }

  ///Download the file from the url
  Stream<FileResponse> _updateFile(String url,
      {Map<String, String> authHeaders}) async* {
    var cacheObject = await _store.retrieveCacheData(url);
    cacheObject ??= CacheObject(url);
    final response = await _download(cacheObject, authHeaders);
    yield* _manageResponse(cacheObject, response);

    final file = (await _store.fileDir).childFile(cacheObject.relativePath);
    yield FileInfo(file, FileSource.Online, cacheObject.validTill, url);
  }

  Future<FileServiceGetResponse> _download(
      CacheObject cacheObject, Map<String, String> authHeaders) {
    final headers = <String, String>{};
    if (authHeaders != null) {
      headers.addAll(authHeaders);
    }

    if (cacheObject.eTag != null) {
      headers[HttpHeaders.ifNoneMatchHeader] = cacheObject.eTag;
    }

    return _fileFetcher.get(cacheObject.url, headers: headers);
  }

  Stream<DownloadProgress> _manageResponse(
      CacheObject cacheObject, FileServiceGetResponse response) async* {
    final hasNewFile = statusCodesNewFile.contains(response.statusCode);
    final keepOldFile = statusCodesFileNotChanged.contains(response.statusCode);
    if (!hasNewFile && !keepOldFile) {
      throw HttpExceptionWithStatus(
        response.statusCode,
        'Invalid statusCode: ${response?.statusCode}',
        uri: Uri.parse(cacheObject.url),
      );
    }

    final oldCacheFile = cacheObject.relativePath;
    var newCacheFile = cacheObject.relativePath;
    _setDataFromHeaders(cacheObject, response);
    if (statusCodesNewFile.contains(response.statusCode)) {
      await for (var progress in _saveFile(cacheObject, response)) {
        yield DownloadProgress(
            cacheObject.url, response.contentLength, progress);
      }
      newCacheFile = cacheObject.relativePath;
    }

    unawaited(_store.putFile(cacheObject).then((_) {
      if (newCacheFile != oldCacheFile) {
        _removeOldFile(oldCacheFile);
      }
    }));
  }

  void _setDataFromHeaders(
      CacheObject cacheObject, FileServiceGetResponse response) {
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

  Stream<int> _saveFile(
      CacheObject cacheObject, FileServiceGetResponse response) {
    var receivedBytesResultController = StreamController<int>();
    unawaited(_saveFileAndPostUpdates(
      receivedBytesResultController,
      cacheObject,
      response,
    ));
    return receivedBytesResultController.stream;
  }

  Future _saveFileAndPostUpdates(
      StreamController<int> receivedBytesResultController,
      CacheObject cacheObject,
      FileServiceGetResponse response) async {
    final basePath = await _store.fileDir;

    final file = basePath.childFile(cacheObject.relativePath);
    final folder = file.parent;
    if (!(await folder.exists())) {
      folder.createSync(recursive: true);
    }
    try {
      var receivedBytes = 0;
      final sink = file.openWrite();
      await response.content.map((s) {
        receivedBytes += s.length;
        receivedBytesResultController.add(receivedBytes);
        return s;
      }).pipe(sink);
    } catch (e, stacktrace) {
      receivedBytesResultController.addError(e, stacktrace);
    }
    await receivedBytesResultController.close();
  }

  Future<void> _removeOldFile(String relativePath) async {
    if (relativePath == null) return;
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
