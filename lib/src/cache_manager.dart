import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file/file.dart' as f;
import 'package:file/local.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_cache_manager/src/compat/file_service_compat.dart';
import 'package:flutter_cache_manager/src/result/download_progress.dart';
import 'package:flutter_cache_manager/src/result/file_response.dart';
import 'package:flutter_cache_manager/src/storage/cache_object.dart';
import 'package:flutter_cache_manager/src/cache_store.dart';
import 'package:flutter_cache_manager/src/web/file_service.dart';
import 'package:flutter_cache_manager/src/result/file_info.dart';
import 'package:flutter_cache_manager/src/web/web_helper.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pedantic/pedantic.dart';
import 'package:uuid/uuid.dart';

///Flutter Cache Manager
///Copyright (c) 2019 Rene Floor
///Released under MIT License.

/// The DefaultCacheManager that can be easily used directly. The code of
/// this implementation can be used as inspiration for more complex cache
/// managers.
class DefaultCacheManager extends BaseCacheManager {
  static const key = 'libCachedImageData';

  static DefaultCacheManager _instance;

  factory DefaultCacheManager() {
    _instance ??= DefaultCacheManager._();
    return _instance;
  }

  DefaultCacheManager._() : super(key);

  @override
  Future<String> getFilePath() async {
    var directory = await getTemporaryDirectory();
    return p.join(directory.path, key);
  }
}

abstract class BaseCacheManager {
  /// Creates a new instance of a cache manager. This can be used to retrieve
  /// files from the cache or download them online. The http headers are used
  /// for the maximum age of the files. The BaseCacheManager should only be
  /// used in singleton patterns.
  ///
  /// The [_cacheKey] is used for the sqlite database file and should be unique.
  /// Files are removed when they haven't been used for longer than [maxAgeCacheObject]
  /// or when this cache has grown too big. When the cache is larger than [maxNrOfCacheObjects]
  /// files the files that haven't been used longest will be removed.
  /// The [fileService] can be used to customize how files are downloaded. For example
  /// to edit the urls, add headers or use a proxy. You can also choose to supply
  /// a CacheStore or WebHelper directly if you want more customization.
  BaseCacheManager(
    this._cacheKey, {
    Duration maxAgeCacheObject,
    int maxNrOfCacheObjects,
    FileService fileService,
    CacheStore cacheStore,
    WebHelper webHelper,
    @Deprecated('Use FileService instead') FileFetcher fileFetcher,
  }) {
    assert(
        (maxAgeCacheObject == null && maxNrOfCacheObjects == null) ||
            cacheStore == null,
        'When supplying a cacheStore maxAgeCacheObject and maxNrOfCacheObjects will be ignored. Supply these to the store instead.');
    assert(fileService == null || fileFetcher == null,
        "FileService is the replacement of the deprecated FileFetcher. Don't supply both");
    assert(fileService == null || webHelper == null,
        'When you supply a WebHelper the FileService  will be ignored, you have to supply that to the WebHelper');
    assert(fileFetcher == null || webHelper == null,
        'When you supply a WebHelper the FileFetcher will be ignored, you have to supply that to the WebHelper');

    var duration = maxAgeCacheObject ?? const Duration(days: 30);
    var maxSize = maxNrOfCacheObjects ?? 200;
    _store = cacheStore ??
        CacheStore(_createFileDir(), _cacheKey, maxSize, duration);
    _fileDir = _store.fileDir;

    if (fileService == null && fileFetcher != null) {
      fileService = FileServiceCompat(fileFetcher);
    }

    _webHelper = webHelper ?? WebHelper(_store, fileService);
  }

  final String _cacheKey;

  /// This path is used as base folder for all cached files.
  Future<String> getFilePath();

  /// Store helper for cached files
  CacheStore _store;

  /// WebHelper to download and store files
  WebHelper _webHelper;

  /// Get the file from the cache and/or online, depending on availability and age.
  /// Downloaded form [url], [headers] can be used for example for authentication.
  /// When a file is cached it is return directly, when it is too old the file is
  /// downloaded in the background. When a cached file is not available the
  /// newly downloaded file is returned.
  Future<File> getSingleFile(
    String url, {
    String key,
    Map<String, String> headers,
  }) async {
    key ??= url;
    final cacheFile = await getFileFromCache(key);
    if (cacheFile != null) {
      if (cacheFile.validTill.isBefore(DateTime.now())) {
        unawaited(downloadFile(url, key: key, authHeaders: headers));
      }
      return cacheFile.file;
    }
    return (await downloadFile(url, key: key, authHeaders: headers)).file;
  }

  /// Get the file from the cache and/or online, depending on availability and age.
  /// Downloaded form [url], [headers] can be used for example for authentication.
  /// The files are returned as stream. First the cached file if available, when the
  /// cached file is too old the newly downloaded file is returned afterwards.
  @Deprecated('Prefer to use the new getFileStream method')
  Stream<FileInfo> getFile(String url, {Map<String, String> headers}) {
    return getFileStream(url, withProgress: false).map((r) => r as FileInfo);
  }

  /// Get the file from the cache and/or online, depending on availability and age.
  /// Downloaded form [url], [headers] can be used for example for authentication.
  /// The files are returned as stream. First the cached file if available, when the
  /// cached file is too old the newly downloaded file is returned afterwards.
  ///
  /// The [FileResponse] is either a [FileInfo] object for fully downloaded files
  /// or a [DownloadProgress] object for when a file is being downloaded.
  /// The [DownloadProgress] objects are only dispatched when [withProgress] is
  /// set on true and the file is not available in the cache. When the file is
  /// returned from the cache there will be no progress given, although the file
  /// might be outdated and a new file is being downloaded in the background.
  Stream<FileResponse> getFileStream(String url,
      {String key, Map<String, String> headers, bool withProgress}) {
    key ??= url;
    final streamController = StreamController<FileResponse>();
    _pushFileToStream(
        streamController, url, key, headers, withProgress ?? false);
    return streamController.stream;
  }

  Future<void> _pushFileToStream(StreamController streamController, String url,
      String key, Map<String, String> headers, bool withProgress) async {
    FileInfo cacheFile;
    try {
      cacheFile = await getFileFromCache(key);
      if (cacheFile != null) {
        streamController.add(cacheFile);
        withProgress = false;
      }
    } catch (e) {
      print(
          'CacheManager: Failed to load cached file for $url with error:\n$e');
    }
    if (cacheFile == null || cacheFile.validTill.isBefore(DateTime.now())) {
      try {
        await for (var response
            in _webHelper.downloadFile(url, key: key, authHeaders: headers)) {
          if (response is DownloadProgress && withProgress) {
            streamController.add(response);
          }
          if (response is FileInfo) {
            streamController.add(response);
          }
        }
      } catch (e) {
        assert(() {
          print(
              'CacheManager: Failed to download file from $url with error:\n$e');
          return true;
        }());
        if (cacheFile == null && streamController.hasListener) {
          streamController.addError(e);
        }
      }
    }
    unawaited(streamController.close());
  }

  ///Download the file and add to cache
  Future<FileInfo> downloadFile(String url,
      {String key, Map<String, String> authHeaders, bool force = false}) async {
    key ??= url;
    var fileResponse = await _webHelper
        .downloadFile(url,
            key: key, authHeaders: authHeaders, ignoreMemCache: force)
        .firstWhere((r) => r is FileInfo);
    return fileResponse as FileInfo;
  }

  ///Get the file from the cache
  Future<FileInfo> getFileFromCache(String key) => _store.getFile(key);

  ///Returns the file from memory if it has already been fetched
  FileInfo getFileFromMemory(String key) => _store.getFileFromMemory(key);

  /// Put a file in the cache. It is recommended to specify the [eTag] and the
  /// [maxAge]. When [maxAge] is passed and the eTag is not set the file will
  /// always be downloaded again. The [fileExtension] should be without a dot,
  /// for example "jpg". When cache info is available for the url that path
  /// is re-used.
  /// The returned [File] is saved on disk.
  Future<File> putFile(
    String url,
    Uint8List fileBytes, {
    String key,
    String eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) async {
    key ??= url;
    var cacheObject = await _store.retrieveCacheData(key);
    cacheObject ??= CacheObject(url,
        key: key, relativePath: '${Uuid().v1()}.$fileExtension');
    cacheObject.validTill = DateTime.now().add(maxAge);
    cacheObject.eTag = eTag;

    final file = (await _fileDir).childFile(cacheObject.relativePath);
    final folder = file.parent;
    if (!(await folder.exists())) {
      folder.createSync(recursive: true);
    }
    await file.writeAsBytes(fileBytes);
    unawaited(_store.putFile(cacheObject));
    return file;
  }

  /// Remove a file from the cache
  Future<void> removeFile(String key) async {
    final cacheObject = await _store.retrieveCacheData(key);
    if (cacheObject != null) {
      await _store.removeCachedFile(cacheObject);
    }
  }

  /// Removes all files from the cache
  Future<void> emptyCache() => _store.emptyCache();

  Future<f.Directory> _fileDir;

  Future<f.Directory> _createFileDir() async {
    var fs = const LocalFileSystem();
    var directory = fs.directory((await getFilePath()));
    await directory.create(recursive: true);
    return directory;
  }
}
