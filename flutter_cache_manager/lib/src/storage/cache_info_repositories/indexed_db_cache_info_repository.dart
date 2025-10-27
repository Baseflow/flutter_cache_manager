import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_cache_manager/src/storage/cache_info_repositories/cache_info_repository.dart';
import 'package:flutter_cache_manager/src/storage/cache_info_repositories/helper_methods.dart';
import 'package:flutter_cache_manager/src/storage/cache_object.dart';
import 'package:web/web.dart' as web;

/// A cache info repository implementation that stores cache metadata in IndexedDB.
class IndexedDbCacheInfoRepository extends CacheInfoRepository
    with CacheInfoRepositoryHelperMethods {
  IndexedDbCacheInfoRepository({required this.databaseName});

  final String databaseName;

  static const String _metadataStoreName = 'cache_metadata';
  static const String _keyIndexName = 'key_index';
  static const int _dbVersion = 1;

  web.IDBDatabase? _db;

  Future<web.IDBDatabase> _getDatabase() async {
    if (_db != null) {
      return _db!;
    }

    final completer = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open(databaseName, _dbVersion);

    request.onupgradeneeded = (web.IDBVersionChangeEvent e) {
      final db = request.result as web.IDBDatabase;

      // Create cache_metadata object store if it doesn't exist
      final hasMetadataStore = db.objectStoreNames.contains(_metadataStoreName);
      if (!hasMetadataStore) {
        final objectStore = db.createObjectStore(
          _metadataStoreName,
          web.IDBObjectStoreParameters(
            keyPath: CacheObject.columnId.toJS,
            autoIncrement: true,
          ),
        );
        // Create index on key field for fast lookups
        objectStore.createIndex(
          _keyIndexName,
          CacheObject.columnKey.toJS,
          web.IDBIndexParameters(unique: true),
        );
      }

      // Also create cache_files object store if it doesn't exist
      // This ensures both stores are created in the same upgrade transaction
      const fileStoreName = 'cache_files';
      final hasFileStore = db.objectStoreNames.contains(fileStoreName);
      if (!hasFileStore) {
        db.createObjectStore(
          fileStoreName,
          web.IDBObjectStoreParameters(keyPath: 'path'.toJS),
        );
      }
    }.toJS;

    request.onsuccess = (web.Event e) {
      _db = request.result as web.IDBDatabase;
      completer.complete(_db!);
    }.toJS;

    request.onerror = (web.Event e) {
      completer.completeError(
        Exception('Failed to open IndexedDB: ${request.error}'),
      );
    }.toJS;

    return completer.future;
  }

  @override
  Future<bool> open() async {
    if (!shouldOpenOnNewConnection()) {
      return openCompleter!.future;
    }
    await _getDatabase();
    return opened();
  }

  @override
  Future<CacheObject?> get(String key) async {
    final db = await _getDatabase();
    final completer = Completer<CacheObject?>();

    final transaction = db.transaction(_metadataStoreName.toJS, 'readonly');
    final store = transaction.objectStore(_metadataStoreName);
    final index = store.index(_keyIndexName);
    final request = index.get(key.toJS);

    request.onsuccess = (web.Event e) {
      final result = request.result;
      if (result != null) {
        final map = _jsToMap(result);
        completer.complete(CacheObject.fromMap(map));
      } else {
        completer.complete(null);
      }
    }.toJS;

    request.onerror = (web.Event e) {
      completer.completeError(
        Exception('Failed to get object from IndexedDB: ${request.error}'),
      );
    }.toJS;

    return completer.future;
  }

  @override
  Future<List<CacheObject>> getAllObjects() async {
    final db = await _getDatabase();
    final completer = Completer<List<CacheObject>>();

    final transaction = db.transaction(_metadataStoreName.toJS, 'readonly');
    final store = transaction.objectStore(_metadataStoreName);
    final request = store.getAll();

    request.onsuccess = (web.Event e) {
      final result = request.result;
      final list = <CacheObject>[];
      if (result != null) {
        final jsArray = result as JSArray;
        for (var i = 0; i < jsArray.length; i++) {
          final item = jsArray[i];
          final map = _jsToMap(item);
          list.add(CacheObject.fromMap(map));
        }
      }
      completer.complete(list);
    }.toJS;

    request.onerror = (web.Event e) {
      completer.completeError(
        Exception('Failed to get all objects from IndexedDB: ${request.error}'),
      );
    }.toJS;

    return completer.future;
  }

  @override
  Future<CacheObject> insert(
    CacheObject cacheObject, {
    bool setTouchedToNow = true,
  }) async {
    if (cacheObject.id != null) {
      throw ArgumentError("Inserted objects shouldn't have an existing id.");
    }

    final db = await _getDatabase();
    final completer = Completer<CacheObject>();

    final transaction = db.transaction(_metadataStoreName.toJS, 'readwrite');
    final store = transaction.objectStore(_metadataStoreName);

    final map = cacheObject.toMap(setTouchedToNow: setTouchedToNow);
    map.remove(CacheObject.columnId); // Let IndexedDB auto-generate the id

    final request = store.add(map.jsify());

    request.onsuccess = (web.Event e) {
      final id = (request.result as JSNumber).toDartInt;
      final newCacheObject = cacheObject.copyWith(id: id);
      completer.complete(newCacheObject);
    }.toJS;

    request.onerror = (web.Event e) {
      completer.completeError(
        Exception('Failed to insert object into IndexedDB: ${request.error}'),
      );
    }.toJS;

    return completer.future;
  }

  @override
  Future<int> update(
    CacheObject cacheObject, {
    bool setTouchedToNow = true,
  }) async {
    if (cacheObject.id == null) {
      throw ArgumentError('Updated objects should have an existing id.');
    }

    final db = await _getDatabase();
    final completer = Completer<int>();

    final transaction = db.transaction(_metadataStoreName.toJS, 'readwrite');
    final store = transaction.objectStore(_metadataStoreName);

    final map = cacheObject.toMap(setTouchedToNow: setTouchedToNow);
    final request = store.put(map.jsify());

    request.onsuccess = (web.Event e) {
      completer.complete(1);
    }.toJS;

    request.onerror = (web.Event e) {
      completer.completeError(
        Exception('Failed to update object in IndexedDB: ${request.error}'),
      );
    }.toJS;

    return completer.future;
  }

  @override
  Future<dynamic> updateOrInsert(CacheObject cacheObject) {
    return cacheObject.id == null ? insert(cacheObject) : update(cacheObject);
  }

  @override
  Future<List<CacheObject>> getObjectsOverCapacity(int capacity) async {
    final allObjects = await getAllObjects();
    allObjects.sort((c1, c2) => c1.touched!.compareTo(c2.touched!));
    if (allObjects.length <= capacity) return [];
    return allObjects.getRange(0, allObjects.length - capacity).toList();
  }

  @override
  Future<List<CacheObject>> getOldObjects(Duration maxAge) async {
    final oldestTimestamp = DateTime.now().subtract(maxAge);
    final allObjects = await getAllObjects();
    return allObjects
        .where((element) => element.touched!.isBefore(oldestTimestamp))
        .toList();
  }

  @override
  Future<int> delete(int id) async {
    final db = await _getDatabase();
    final completer = Completer<int>();

    final transaction = db.transaction(_metadataStoreName.toJS, 'readwrite');
    final store = transaction.objectStore(_metadataStoreName);
    final request = store.delete(id.toJS);

    request.onsuccess = (web.Event e) {
      completer.complete(1);
    }.toJS;

    request.onerror = (web.Event e) {
      completer.completeError(
        Exception('Failed to delete object from IndexedDB: ${request.error}'),
      );
    }.toJS;

    return completer.future;
  }

  @override
  Future<int> deleteAll(Iterable<int> ids) async {
    if (ids.isEmpty) return 0;

    final db = await _getDatabase();
    final completer = Completer<int>();

    final transaction = db.transaction(_metadataStoreName.toJS, 'readwrite');
    final store = transaction.objectStore(_metadataStoreName);

    var deleted = 0;
    for (final id in ids) {
      store.delete(id.toJS);
      deleted++;
    }

    transaction.oncomplete = (web.Event e) {
      completer.complete(deleted);
    }.toJS;

    transaction.onerror = (web.Event e) {
      completer.completeError(
        Exception(
            'Failed to delete objects from IndexedDB: ${transaction.error}'),
      );
    }.toJS;

    return completer.future;
  }

  @override
  Future<bool> close() async {
    if (!shouldClose()) {
      return false;
    }
    _db?.close();
    _db = null;
    return true;
  }

  @override
  Future<void> deleteDataFile() async {
    await close();
    final completer = Completer<void>();
    final request = web.window.indexedDB.deleteDatabase(databaseName);

    request.onsuccess = (web.Event e) {
      completer.complete();
    }.toJS;

    request.onerror = (web.Event e) {
      completer.completeError(
        Exception('Failed to delete IndexedDB database: ${request.error}'),
      );
    }.toJS;

    return completer.future;
  }

  @override
  Future<bool> exists() async {
    try {
      final db = await _getDatabase();
      final hasStore = db.objectStoreNames.contains(_metadataStoreName);
      return hasStore;
    } catch (e) {
      throw Exception('Failed to check if IndexedDB exists: $e');
    }
  }

  /// Converts a JavaScript value to a Dart Map.
  Map<String, dynamic> _jsToMap(JSAny? jsValue) {
    if (jsValue == null) {
      return {};
    }

    final map = <String, dynamic>{};
    final obj = jsValue as JSObject;

    // Get all property names
    final keysArray = objectKeys(obj);
    final keys = keysArray.toDart;

    for (var i = 0; i < keys.length; i++) {
      final keyJs = keys[i] as JSString;
      final key = keyJs.toDart;
      final value = obj[keyJs];

      if (value == null) {
        map[key] = null;
      } else if (value.typeofEquals('string')) {
        map[key] = (value as JSString).toDart;
      } else if (value.typeofEquals('number')) {
        final num = (value as JSNumber).toDartDouble;
        // Check if it's an integer
        if (num == num.truncateToDouble()) {
          map[key] = num.toInt();
        } else {
          map[key] = num;
        }
      } else if (value.typeofEquals('boolean')) {
        map[key] = (value as JSBoolean).toDart;
      } else {
        map[key] = value;
      }
    }

    return map;
  }
}

@JS('Object.keys')
external JSArray objectKeys(JSObject obj);

/// Extension to access JSObject properties using [] operator
extension JSObjectExtension on JSObject {
  external JSAny? operator [](JSAny key);
}

/// Extension to access JSArray elements using [] operator
extension JSArrayExtension on JSArray {
  external JSAny? operator [](JSAny index);
}
