import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file/file.dart' as f;
import 'package:file/local.dart';
import 'package:flutter_cache_manager/src/storage/cache_object.dart';
import 'package:flutter_cache_manager/src/cache_store.dart';
import 'package:flutter_cache_manager/src/web/file_fetcher.dart';
import 'package:flutter_cache_manager/src/file_info.dart';
import 'package:flutter_cache_manager/src/web/web_helper.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pedantic/pedantic.dart';
import 'package:uuid/uuid.dart';

///Flutter Cache Manager
///Copyright (c) 2019 Rene Floor
///Released under MIT License.

class DefaultCacheManager extends BaseCacheManager {
  static const key = 'libCachedImageData';

  static DefaultCacheManager _instance;

  /// The DefaultCacheManager that can be easily used directly. The code of
  /// this implementation can be used as inspiration for more complex cache
  /// managers.
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
  /// Files are removed when they haven't been used for longer than [_maxAgeCacheObject]
  /// or when this cache has grown to big. When the cache is larger than [_maxNrOfCacheObjects]
  /// files the files that haven't been used longest will be removed.
  /// The [httpGetter] can be used to customize how files are downloaded. For example
  /// to edit the urls, add headers or use a proxy.
  BaseCacheManager(
    this._cacheKey, {
    Duration maxAgeCacheObject = const Duration(days: 30),
    int maxNrOfCacheObjects = 200,
    FileService fileService,
  }) {
    _store =
        CacheStore(_fileDir, _cacheKey, maxNrOfCacheObjects, maxAgeCacheObject);
    _webHelper = WebHelper(_store, fileService);
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
  Future<File> getSingleFile(String url, {Map<String, String> headers}) async {
    final cacheFile = await getFileFromCache(url);
    if (cacheFile != null) {
      if (cacheFile.validTill.isBefore(DateTime.now())) {
        unawaited(_webHelper.downloadFile(url, authHeaders: headers));
      }
      return cacheFile.file;
    }
    return (await _webHelper.downloadFile(url, authHeaders: headers)).file;
  }

  /// Get the file from the cache and/or online, depending on availability and age.
  /// Downloaded form [url], [headers] can be used for example for authentication.
  /// The files are returned as stream. First the cached file if available, when the
  /// cached file is too old the newly downloaded file is returned afterwards.
  Stream<FileInfo> getFile(String url, {Map<String, String> headers}) {
    final streamController = StreamController<FileInfo>();
    _pushFileToStream(streamController, url, headers);
    return streamController.stream;
  }

  Future<void> _pushFileToStream(StreamController streamController, String url,
      Map<String, String> headers) async {
    FileInfo cacheFile;
    try {
      cacheFile = await getFileFromCache(url);
      if (cacheFile != null) {
        streamController.add(cacheFile);
      }
    } catch (e) {
      print(
          'CacheManager: Failed to load cached file for $url with error:\n$e');
    }
    if (cacheFile == null || cacheFile.validTill.isBefore(DateTime.now())) {
      try {
        final webFile =
            await _webHelper.downloadFile(url, authHeaders: headers);
        if (webFile != null) {
          streamController.add(webFile);
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
      {Map<String, String> authHeaders, bool force = false}) {
    return _webHelper.downloadFile(url,
        authHeaders: authHeaders, ignoreMemCache: force);
  }

  ///Get the file from the cache
  Future<FileInfo> getFileFromCache(String url) => _store.getFile(url);

  ///Returns the file from memory if it has already been fetched
  FileInfo getFileFromMemory(String url) => _store.getFileFromMemory(url);

  /// Put a file in the cache. It is recommended to specify the [eTag] and the
  /// [maxAge]. When [maxAge] is passed and the eTag is not set the file will
  /// always be downloaded again. The [fileExtension] should be without a dot,
  /// for example "jpg". When cache info is available for the url that path
  /// is re-used.
  /// The returned [File] is saved on disk.
  Future<File> putFile(
    String url,
    Uint8List fileBytes, {
    String eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) async {
    var cacheObject = await _store.retrieveCacheData(url);
    cacheObject ??=
        CacheObject(url, relativePath: '${Uuid().v1()}.$fileExtension');
    cacheObject.validTill = DateTime.now().add(maxAge);
    cacheObject.eTag = eTag;

    final path = p.join(await getFilePath(), cacheObject.relativePath);
    final folder = File(path).parent;
    if (!(await folder.exists())) {
      folder.createSync(recursive: true);
    }
    final file = await File(path).writeAsBytes(fileBytes);
    unawaited(_store.putFile(cacheObject));
    return file;
  }

  /// Remove a file from the cache
  Future<void> removeFile(String url) async {
    final cacheObject = await _store.retrieveCacheData(url);
    if (cacheObject != null) {
      await _store.removeCachedFile(cacheObject);
    }
  }

  /// Removes all files from the cache
  Future<void> emptyCache() => _store.emptyCache();

  Future<f.Directory> _cachedFileDir;
  Future<f.Directory> get _fileDir {
    return _cachedFileDir ??= _createFileDir();
  }

  Future<f.Directory> _createFileDir() async {
    var fs = const LocalFileSystem();
    var directory = fs.directory((await getFilePath()));
    await directory.create(recursive: true);
    return directory;
  }
}
