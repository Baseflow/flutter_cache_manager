import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:file/file.dart' as pf;
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/src/storage/cache_info_repositories/cache_info_repository.dart';
import 'package:flutter_cache_manager/src/storage/cache_info_repositories/helper_methods.dart';
import 'package:flutter_cache_manager/src/storage/cache_object.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class JsonCacheInfoRepository extends CacheInfoRepository
    with CacheInfoRepositoryHelperMethods {
  Directory? directory;
  String? path;
  String? databaseName;

  /// Either the path or the database name should be provided.
  /// If the path is provider it should end with '{databaseName}.json',
  /// for example: /data/user/0/com.example.example/databases/imageCache.json
  JsonCacheInfoRepository({this.path, this.databaseName})
    : assert(path == null || databaseName == null);

  /// The directory and the databaseName should both the provided. The database
  /// is stored as {databaseName}.json in the directory,
  JsonCacheInfoRepository.withFile(File file) : _file = file;

  File? _file;
  final Map<String, CacheObject> _cacheObjects = {};
  final Map<int, Map<String, dynamic>> _jsonCache = {};

  Future<void> _writeQueue = Future.value();

  @override
  Future<bool> open() async {
    if (!shouldOpenOnNewConnection()) {
      return openCompleter!.future;
    }
    final file = await _getFile();
    await _readFile(file);
    return opened();
  }

  @override
  Future<CacheObject?> get(String key) async {
    return _cacheObjects.values.firstWhereOrNull(
      (element) => element.key == key,
    );
  }

  @override
  Future<List<CacheObject>> getAllObjects() async {
    return _cacheObjects.values.toList();
  }

  @override
  Future<CacheObject> insert(
    CacheObject cacheObject, {
    bool setTouchedToNow = true,
  }) async {
    if (cacheObject.id != null) {
      throw ArgumentError("Inserted objects shouldn't have an existing id.");
    }
    return _enqueue(() async {
      final keys = _jsonCache.keys;
      final id = (keys.isEmpty ? 0 : keys.reduce(max)) + 1;
      return _put(cacheObject.copyWith(id: id), setTouchedToNow);
    });
  }

  @override
  Future<int> update(
    CacheObject cacheObject, {
    bool setTouchedToNow = true,
  }) async {
    if (cacheObject.id == null) {
      throw ArgumentError('Updated objects should have an existing id.');
    }
    return _enqueue(() async {
      await _put(cacheObject, setTouchedToNow);
      return 1;
    });
  }

  /// Updates the access time of the current entry without writing a stale path.
  Future<void> touch(String key) => _enqueue(() async {
    final current = _cacheObjects[key];
    if (current != null) await _put(current, true);
  });

  @override
  Future<dynamic> updateOrInsert(CacheObject cacheObject) {
    return cacheObject.id == null ? insert(cacheObject) : update(cacheObject);
  }

  @override
  Future<List<CacheObject>> getObjectsOverCapacity(int capacity) async {
    final allSorted = _cacheObjects.values.toList()
      ..sort((c1, c2) => c1.touched!.compareTo(c2.touched!));
    if (allSorted.length <= capacity) return [];
    return allSorted.getRange(0, allSorted.length - capacity).toList();
  }

  @override
  Future<List<CacheObject>> getOldObjects(Duration maxAge) async {
    final oldestTimestamp = DateTime.now().subtract(maxAge);
    return _cacheObjects.values
        .where((element) => element.touched!.isBefore(oldestTimestamp))
        .toList();
  }

  @override
  Future<int> delete(int id) => deleteAll([id]);

  @override
  Future<int> deleteAll(Iterable<int> ids) {
    final requestedIds = ids.toSet();
    return _enqueue(() async {
      final nextObjects = Map<String, CacheObject>.of(_cacheObjects);
      final nextJson = Map<int, Map<String, dynamic>>.of(_jsonCache);
      var deleted = 0;
      for (final id in requestedIds) {
        final object = nextObjects.values.firstWhereOrNull(
          (item) => item.id == id,
        );
        if (object != null) {
          nextObjects.remove(object.key);
          nextJson.remove(id);
          deleted++;
        }
      }
      if (deleted > 0) await _commit(nextObjects, nextJson);
      return deleted;
    });
  }

  @override
  Future<bool> close() async {
    final shouldCloseRepo = shouldClose();
    await _writeQueue;
    return shouldCloseRepo;
  }

  Future<void> _readFile(File file) async {
    _cacheObjects.clear();
    _jsonCache.clear();
    if (await file.exists()) {
      try {
        final jsonString = await file.readAsString();
        final json = jsonDecode(jsonString) as List<dynamic>;
        for (final element in json) {
          if (element is! Map<String, dynamic>) continue;
          final map = element;
          final cacheObject = CacheObject.fromMap(map);
          _jsonCache[cacheObject.id!] = map;
          _cacheObjects[cacheObject.key] = cacheObject;
        }
      } on Object catch (e, stacktrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: e,
            stack: stacktrace,
            library: 'flutter cache manager',
            context: ErrorDescription(
              'Thrown when reading the file containing cache info. '
              'The cached files cannot be used by the cache manager anymore.',
            ),
          ),
        );
      }
    }
  }

  Future<CacheObject> _put(
    CacheObject cacheObject,
    bool setTouchedToNow,
  ) async {
    final map = cacheObject.toMap(setTouchedToNow: setTouchedToNow);
    final updated = CacheObject.fromMap(map);
    final nextObjects = Map<String, CacheObject>.of(_cacheObjects)
      ..[updated.key] = updated;
    final nextJson = Map<int, Map<String, dynamic>>.of(_jsonCache)
      ..[updated.id!] = map;
    await _commit(nextObjects, nextJson);
    return updated;
  }

  /// Each operation derives its snapshot from the last successful operation.
  /// The recovery future keeps a failure from poisoning later queued writes;
  /// the operation's own future still reports its error to its caller.
  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _writeQueue.then((_) => operation());
    _writeQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> _commit(
    Map<String, CacheObject> nextObjects,
    Map<int, Map<String, dynamic>> nextJson,
  ) async {
    try {
      await _saveFile(nextJson);
    } on Object catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'flutter cache manager',
          context: ErrorDescription(
            'Thrown when writing the file containing cache info.',
          ),
        ),
      );
      rethrow;
    }
    _cacheObjects
      ..clear()
      ..addAll(nextObjects);
    _jsonCache
      ..clear()
      ..addAll(nextJson);
  }

  Future<void> _saveFile(Map<int, Map<String, dynamic>> snapshot) async {
    final file = await _getFile();
    final content = jsonEncode(snapshot.values.toList());
    final tempFile = _createSiblingFile('${file.path}.tmp');
    await tempFile.writeAsString(content, flush: true);
    await tempFile.rename(file.path);
  }

  /// Creates a file next to [_file] on the same file system.
  ///
  /// [_file] can be backed by an alternative [pf.FileSystem], in which case a
  /// plain [File] would resolve against the local file system instead.
  File _createSiblingFile(String siblingPath) {
    final file = _file!;
    if (file is pf.File) {
      return file.fileSystem.file(siblingPath);
    }
    return File(siblingPath);
  }

  @override
  Future<void> deleteDataFile() => _enqueue(() async {
    final file = await _getFile();
    if (await file.exists()) {
      await file.delete();
    }
    final tempFile = _createSiblingFile('${file.path}.tmp');
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
  });

  @override
  Future<bool> exists() async {
    final file = await _getFile();
    return file.exists();
  }

  Future<File> _getFile() async {
    if (_file != null) {
      return _file!;
    }

    if (path != null) {
      directory = File(path!).parent;
    } else {
      directory ??= await getApplicationSupportDirectory();
    }
    await directory!.create(recursive: true);
    if (path == null || !path!.endsWith('.json')) {
      path = join(directory!.path, '$databaseName.json');
    }
    _file = File(path!);
    return _file!;
  }
}
