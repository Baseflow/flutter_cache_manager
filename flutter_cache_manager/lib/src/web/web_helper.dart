import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_cache_manager/src/cache_store.dart';
import 'package:flutter_cache_manager/src/web/queue_item.dart';
import 'package:flutter_cache_manager/src/web/shared_cancellation.dart';
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
  final Map<String, _Download> _memCache;
  final Queue<_QueuedDownload> _queue = Queue();

  ///Download the file from the url
  ///
  /// Callers asking for the same [key] share one download. A caller that
  /// passes a [cancellationToken] and cancels it gets a [CancelledException]
  /// on its own stream; the download itself only stops once every caller
  /// sharing it has cancelled.
  Stream<FileResponse> downloadFile(
    String url, {
    String? key,
    Map<String, String>? authHeaders,
    bool ignoreMemCache = false,
    CancellationToken? cancellationToken,
  }) {
    final cacheKey = key ?? url;
    if (cancellationToken?.isCancelled ?? false) {
      return Stream.error(CancelledException());
    }
    var download = _memCache[cacheKey];
    if (download == null || ignoreMemCache) {
      final created = _Download();
      created.cancellation.onAllCancelled = () => _abandon(cacheKey, created);
      _memCache[cacheKey] = created;
      download = created;
      _downloadOrAddToQueue(url, cacheKey, authHeaders, created);
    }
    return download.cancellation.join(
      download.subject.stream,
      cancellationToken,
    );
  }

  var concurrentCalls = 0;

  /// Every caller of [download] has cancelled: stop sharing it, and drop it
  /// from the queue if it has not started yet. A running download notices its
  /// cancelled token itself.
  void _abandon(String key, _Download download) {
    if (identical(_memCache[key], download)) _memCache.remove(key);
    final wasQueued = _queue.any((item) => identical(item.download, download));
    if (wasQueued) {
      _queue.removeWhere((item) => identical(item.download, download));
      download.fail(CancelledException());
    }
  }

  Future<void> _downloadOrAddToQueue(
    String url,
    String key,
    Map<String, String>? authHeaders,
    _Download download,
  ) async {
    if (download.cancellation.token.isCancelled) {
      _forget(key, download);
      download.fail(CancelledException());
      return;
    }

    //Add to queue if there are too many calls.
    if (concurrentCalls >= fileFetcher.concurrentFetches) {
      _queue.add(_QueuedDownload(QueueItem(url, key, authHeaders), download));
      return;
    }
    cacheLogger.log(
      'CacheManager: Downloading $url',
      CacheManagerLogLevel.verbose,
    );

    concurrentCalls++;
    final subject = download.subject;
    try {
      await for (final result in _updateFile(
        url,
        key,
        authHeaders: authHeaders,
        cancellationToken: download.cancellation.token,
      )) {
        subject.add(result);
      }
    } on Object catch (e, stackTrace) {
      subject.addError(e, stackTrace);
    } finally {
      concurrentCalls--;
      await subject.close();
      _forget(key, download);
      _checkQueue();
    }
  }

  void _forget(String key, _Download download) {
    if (identical(_memCache[key], download)) _memCache.remove(key);
  }

  void _checkQueue() {
    if (_queue.isEmpty) return;
    final next = _queue.removeFirst();
    _downloadOrAddToQueue(
      next.item.url,
      next.item.key,
      next.item.headers,
      next.download,
    );
  }

  ///Download the file from the url
  Stream<FileResponse> _updateFile(
    String url,
    String key, {
    Map<String, String>? authHeaders,
    CancellationToken? cancellationToken,
  }) async* {
    // Check cancellation before any work
    if (cancellationToken?.isCancelled ?? false) {
      throw CancelledException();
    }

    var cacheObject = await _store.retrieveCacheData(key);

    // Check cancellation after async work
    if (cancellationToken?.isCancelled ?? false) {
      throw CancelledException();
    }

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

    // Check cancellation after download
    if (cancellationToken?.isCancelled ?? false) {
      throw CancelledException();
    }

    yield* _manageResponse(cacheObject, response, cancellationToken);
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

    if (cancellationToken == null) {
      return fileFetcher.get(cacheObject.url, headers: headers);
    }
    final request = cancellationToken.runScoped(
      () => fileFetcher.get(cacheObject.url, headers: headers),
    );
    return _untilCancelled(request, cancellationToken);
  }

  /// Completes with [request], or with a [CancelledException] as soon as
  /// [token] is cancelled, for file services that do not abort on
  /// [CancellationToken.current]. A response that arrives after cancelling is
  /// discarded.
  Future<FileServiceResponse> _untilCancelled(
    Future<FileServiceResponse> request,
    CancellationToken token,
  ) {
    final result = Completer<FileServiceResponse>();
    request.then(
      (response) {
        if (result.isCompleted) {
          _discard(response);
        } else {
          result.complete(response);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!result.isCompleted) result.completeError(error, stackTrace);
      },
    );
    token.whenCancelled.then((_) {
      if (!result.isCompleted) result.completeError(CancelledException());
    });
    return result.future;
  }

  void _discard(FileServiceResponse response) {
    try {
      response.content.listen(null, onError: (Object _) {}).cancel();
    } on Object {
      // Nothing to release.
    }
  }

  Stream<FileResponse> _manageResponse(
    CacheObject cacheObject,
    FileServiceResponse response,
    CancellationToken? cancellationToken,
  ) async* {
    // Check cancellation at start
    if (cancellationToken?.isCancelled ?? false) {
      throw CancelledException();
    }

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
    try {
      if (hasNewFile) {
        var savedBytes = 0;
        await for (final progress in _saveFile(
          newCacheObject,
          response,
          cancellationToken,
        )) {
          cancellationToken?.throwIfCancelled();
          savedBytes = progress;
          yield DownloadProgress(
            cacheObject.url,
            response.contentLength,
            progress,
          );
        }
        newCacheObject = newCacheObject.copyWith(length: savedBytes);
      }

      cancellationToken?.throwIfCancelled();
      await _store.putFile(newCacheObject);
    } catch (_) {
      if (hasNewFile) {
        await _discardPartialFile(newCacheObject);
      }
      rethrow;
    }
    if (newCacheObject.relativePath != oldCacheObject.relativePath) {
      await _removeOldFile(oldCacheObject.relativePath);
    }

    final file = await _store.fileSystem.createFile(
      newCacheObject.relativePath,
    );
    if (cancellationToken?.isCancelled ?? false) {
      throw CancelledException();
    }
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

  Stream<int> _saveFile(
    CacheObject cacheObject,
    FileServiceResponse response,
    CancellationToken? cancellationToken,
  ) {
    final receivedBytesResultController = StreamController<int>();
    _saveFileAndPostUpdates(
      receivedBytesResultController,
      cacheObject,
      response,
      cancellationToken,
    );
    return receivedBytesResultController.stream;
  }

  Future<void> _saveFileAndPostUpdates(
    StreamController<int> receivedBytesResultController,
    CacheObject cacheObject,
    FileServiceResponse response,
    CancellationToken? cancellationToken,
  ) async {
    IOSink? sink;
    StreamSubscription<List<int>>? subscription;
    try {
      final file = await _store.fileSystem.createFile(cacheObject.relativePath);
      cancellationToken?.throwIfCancelled();
      final openSink = sink = file.openWrite();
      final done = Completer<void>();
      var receivedBytes = 0;
      subscription = response.content.listen(
        (chunk) {
          receivedBytes += chunk.length;
          openSink.add(chunk);
          receivedBytesResultController.add(receivedBytes);
        },
        onError: (Object e, StackTrace stackTrace) {
          if (!done.isCompleted) done.completeError(e, stackTrace);
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
        cancelOnError: true,
      );
      cancellationToken?.whenCancelled.then((_) {
        if (!done.isCompleted) done.completeError(CancelledException());
      });
      await done.future;
      subscription = null;
      await openSink.close();
    } on Object catch (e, stacktrace) {
      // Stop reading and release the sink, whatever went wrong. The partial
      // file is removed by _manageResponse.
      await subscription?.cancel();
      try {
        await sink?.close();
      } on Object {
        // The original error is the one to report.
      }
      receivedBytesResultController.addError(e, stacktrace);
    }
    await receivedBytesResultController.close();
  }

  /// Removes the file of a download that did not complete. A new download
  /// is always written to a new path, so the previously cached file (and its
  /// cache info) stays valid and is left alone.
  Future<void> _discardPartialFile(CacheObject newCacheObject) async {
    try {
      await _removeOldFile(newCacheObject.relativePath);
    } on Object catch (e) {
      cacheLogger.log(
        'CacheManager: Failed to remove incomplete download '
        '${newCacheObject.relativePath}: $e',
        CacheManagerLogLevel.warning,
      );
    }
  }

  Future<void> _removeOldFile(String? relativePath) async {
    if (relativePath == null) return;
    final file = await _store.fileSystem.createFile(relativePath);
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      // Already deleted (see #184) or not deletable. The cache info no longer
      // points at this path, so there is nothing to recover here.
    }
  }
}

class HttpExceptionWithStatus extends HttpException {
  const HttpExceptionWithStatus(this.statusCode, super.message, {super.uri});

  final int statusCode;
}

/// One download shared by every caller asking for the same key.
class _Download {
  final BehaviorSubject<FileResponse> subject = BehaviorSubject();
  final SharedCancellation cancellation = SharedCancellation();

  void fail(Object error) {
    if (subject.isClosed) return;
    subject.addError(error);
    subject.close();
  }
}

class _QueuedDownload {
  _QueuedDownload(this.item, this.download);

  final QueueItem item;
  final _Download download;
}
