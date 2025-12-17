import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_cache_manager/src/cache_store.dart';
import 'package:flutter_cache_manager/src/web/queue_item.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

///Flutter Cache Manager
///Copyright (c) 2019 Rene Floor
///Released under MIT License.

const statusCodesNewFile = [HttpStatus.ok, HttpStatus.accepted];
const statusCodesFileNotChanged = [HttpStatus.notModified];

class WebHelper {
  WebHelper(this._store, FileService? fileFetcher)
    : _memCache = {},
      fileFetcher = fileFetcher ?? HttpFileService();

  final CacheStore _store;
  @visibleForTesting
  final FileService fileFetcher;
  final Map<String, BehaviorSubject<FileResponse>> _memCache;
  final Queue<QueueItem> _queue = Queue();

  ///Download the file from the url
  Stream<FileResponse> downloadFile(
    String url, {
    String? key,
    Map<String, String>? authHeaders,
    bool ignoreMemCache = false,
    CancellationToken? cancellationToken,
  }) {
    key ??= url;
    var subject = _memCache[key];
    if (subject == null || ignoreMemCache) {
      subject = BehaviorSubject<FileResponse>();
      _memCache[key] = subject;
      _downloadOrAddToQueue(url, key, authHeaders, cancellationToken);
    }
    return subject.stream;
  }

  var concurrentCalls = 0;

  Future<void> _downloadOrAddToQueue(
    String url,
    String key,
    Map<String, String>? authHeaders,
    CancellationToken? cancellationToken,
  ) async {
    // Check if already cancelled before starting
    if (cancellationToken?.isCancelled ?? false) {
      final subject = _memCache[key];
      if (subject != null) {
        subject.addError(CancelledException());
        await subject.close();
        _memCache.remove(key);
      }
      return;
    }

    //Add to queue if there are too many calls.
    if (concurrentCalls >= fileFetcher.concurrentFetches) {
      _queue.add(QueueItem(url, key, authHeaders, cancellationToken));
      return;
    }
    cacheLogger.log(
      'CacheManager: Downloading $url',
      CacheManagerLogLevel.verbose,
    );

    concurrentCalls++;
    final subject = _memCache[key]!;
    try {
      await for (final result in _updateFile(
        url,
        key,
        authHeaders: authHeaders,
        cancellationToken: cancellationToken,
      )) {
        subject.add(result);
      }
    } on Object catch (e, stackTrace) {
      subject.addError(e, stackTrace);
    } finally {
      concurrentCalls--;
      await subject.close();
      _memCache.remove(key);
      _checkQueue();
    }
  }

  void _checkQueue() {
    if (_queue.isEmpty) return;
    final next = _queue.removeFirst();
    // Skip cancelled items
    if (next.cancellationToken?.isCancelled ?? false) {
      // Clean up the subject for this cancelled request
      final subject = _memCache[next.key];
      if (subject != null) {
        subject.addError(CancelledException());
        subject.close();
        _memCache.remove(next.key);
      }
      // Check the next item in queue
      _checkQueue();
      return;
    }
    _downloadOrAddToQueue(
      next.url,
      next.key,
      next.headers,
      next.cancellationToken,
    );
  }

  ///Download the file from the url
  Stream<FileResponse> _updateFile(
    String url,
    String key, {
    Map<String, String>? authHeaders,
    CancellationToken? cancellationToken,
  }) async* {
    var cacheObject = await _store.retrieveCacheData(key);
    cacheObject = cacheObject == null
        ? CacheObject(
            url,
            key: key,
            validTill: clock.now(),
            relativePath: '${const Uuid().v1()}.file',
          )
        : cacheObject.copyWith(url: url);
    final response = await _download(
      cacheObject,
      authHeaders,
      cancellationToken,
    );
    yield* _manageResponse(cacheObject, response);
  }

  Future<FileServiceResponse> _download(
    CacheObject cacheObject,
    Map<String, String>? authHeaders,
    CancellationToken? cancellationToken,
  ) {
    final headers = <String, String>{};

    final etag = cacheObject.eTag;

    // Adding `if-none-match` header on web causes a CORS error.
    if (etag != null && !kIsWeb) {
      headers[HttpHeaders.ifNoneMatchHeader] = etag;
    }

    if (authHeaders != null) {
      headers.addAll(authHeaders);
    }

    return fileFetcher.get(
      cacheObject.url,
      headers: headers,
      cancellationToken: cancellationToken,
    );
  }

  Stream<FileResponse> _manageResponse(
    CacheObject cacheObject,
    FileServiceResponse response,
  ) async* {
    final hasNewFile = statusCodesNewFile.contains(response.statusCode);
    final keepOldFile = statusCodesFileNotChanged.contains(response.statusCode);
    if (!hasNewFile && !keepOldFile) {
      throw HttpExceptionWithStatus(
        response.statusCode,
        'Invalid statusCode: ${response.statusCode}',
        uri: Uri.parse(cacheObject.url),
      );
    }

    final oldCacheObject = cacheObject;
    var newCacheObject = _setDataFromHeaders(cacheObject, response);
    if (statusCodesNewFile.contains(response.statusCode)) {
      var savedBytes = 0;
      await for (final progress in _saveFile(newCacheObject, response)) {
        savedBytes = progress;
        yield DownloadProgress(
          cacheObject.url,
          response.contentLength,
          progress,
        );
      }
      newCacheObject = newCacheObject.copyWith(length: savedBytes);
    }

    _store.putFile(newCacheObject).then((_) {
      if (newCacheObject.relativePath != oldCacheObject.relativePath) {
        _removeOldFile(oldCacheObject.relativePath);
      }
    });

    final file = await _store.fileSystem.createFile(
      newCacheObject.relativePath,
    );
    yield FileInfo(
      file,
      FileSource.Online,
      newCacheObject.validTill,
      newCacheObject.url,
      statusCode: response.statusCode,
    );
  }

  CacheObject _setDataFromHeaders(
    CacheObject cacheObject,
    FileServiceResponse response,
  ) {
    final fileExtension = response.fileExtension;
    var filePath = cacheObject.relativePath;

    if (!statusCodesFileNotChanged.contains(response.statusCode)) {
      if (!filePath.endsWith(fileExtension)) {
        //Delete old file directly when file extension changed
        _removeOldFile(filePath);
      }
      // Store new file on different path
      filePath = '${const Uuid().v1()}$fileExtension';
    }
    return cacheObject.copyWith(
      relativePath: filePath,
      validTill: response.validTill,
      eTag: response.eTag,
    );
  }

  Stream<int> _saveFile(CacheObject cacheObject, FileServiceResponse response) {
    final receivedBytesResultController = StreamController<int>();
    _saveFileAndPostUpdates(
      receivedBytesResultController,
      cacheObject,
      response,
    );
    return receivedBytesResultController.stream;
  }

  Future<void> _saveFileAndPostUpdates(
    StreamController<int> receivedBytesResultController,
    CacheObject cacheObject,
    FileServiceResponse response,
  ) async {
    final file = await _store.fileSystem.createFile(cacheObject.relativePath);

    try {
      var receivedBytes = 0;
      final sink = file.openWrite();
      await response.content
          .map((s) {
            receivedBytes += s.length;
            receivedBytesResultController.add(receivedBytes);
            return s;
          })
          .pipe(sink);
    } on Object catch (e, stacktrace) {
      receivedBytesResultController.addError(e, stacktrace);
    }
    await receivedBytesResultController.close();
  }

  Future<void> _removeOldFile(String? relativePath) async {
    if (relativePath == null) return;
    final file = await _store.fileSystem.createFile(relativePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

class HttpExceptionWithStatus extends HttpException {
  const HttpExceptionWithStatus(this.statusCode, super.message, {super.uri});

  final int statusCode;
}
