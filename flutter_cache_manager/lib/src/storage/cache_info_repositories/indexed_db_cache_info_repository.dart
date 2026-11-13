import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_cache_manager/src/logger.dart';
import 'package:flutter_cache_manager/src/storage/cache_info_repositories/cache_info_repository.dart';
import 'package:flutter_cache_manager/src/storage/cache_info_repositories/helper_methods.dart';
import 'package:flutter_cache_manager/src/storage/cache_info_repositories/indexed_db_connection_pool.dart';
import 'package:flutter_cache_manager/src/storage/cache_info_repositories/indexed_db_schema.dart';
import 'package:flutter_cache_manager/src/storage/cache_object.dart';
import 'package:web/web.dart' as web;

/// A cache info repository implementation that stores cache metadata in IndexedDB.
class IndexedDbCacheInfoRepository extends CacheInfoRepository
    with CacheInfoRepositoryHelperMethods {
  IndexedDbCacheInfoRepository({required this.databaseName});

  final String databaseName;

  static const String _metadataStoreName = IndexedDbSchema.metadataStore;
  static const String _keyIndexName = IndexedDbSchema.keyIndex;
  static const String _touchedIndexName = IndexedDbSchema.touchedIndex;

  late final IndexedDbConnectionPool _connectionPool =
      IndexedDbConnectionPool.getInstance(databaseName: databaseName);

  Future<web.IDBDatabase> _getDatabase() async {
    return _connectionPool.getDatabase();
  }

  @override
  Future<bool> open() async {
    if (!shouldOpenOnNewConnection()) {
      return openCompleter!.future;
    }
    // Held until close(), so the connection stays open while in use.
    await _connectionPool.acquire();
    return opened();
  }

  web.IDBTransaction _createTransaction(
    web.IDBDatabase db,
    String storeName,
    String mode,
  ) => createIndexedDbTransaction(db, [storeName], mode);

  /// Frees space after a quota error. Removes the least recently used
  /// entries together with their file contents (stored in the same database
  /// by `IndexedDbFileSystem` when it uses this [databaseName], the default).
  Future<void> _handleQuotaExceeded() async {
    try {
      await evictLeastRecentlyUsed(await _getDatabase());
    } catch (e) {
      cacheLogger.log(
        'CacheManager: Failed to free up space: $e',
        CacheManagerLogLevel.warning,
      );
    }
  }

  @override
  Future<CacheObject?> get(String key) async {
    final db = await _getDatabase();
    final completer = Completer<CacheObject?>();

    final transaction = _createTransaction(db, _metadataStoreName, 'readonly');
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

    final transaction = _createTransaction(db, _metadataStoreName, 'readonly');
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

    try {
      return await _insertWithRetry(cacheObject, setTouchedToNow, retries: 1);
    } catch (e) {
      if (isQuotaExceeded(e)) {
        cacheLogger.log(
          'CacheManager: Insert failed due to quota exceeded',
          CacheManagerLogLevel.warning,
        );
      }
      rethrow;
    }
  }

  Future<CacheObject> _insertWithRetry(
    CacheObject cacheObject,
    bool setTouchedToNow, {
    required int retries,
  }) async {
    final db = await _getDatabase();
    final completer = Completer<CacheObject>();

    final transaction = _createTransaction(db, _metadataStoreName, 'readwrite');
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
      e.preventDefault();
      completer.completeError(
        IndexedDbException(
          'Failed to insert object into IndexedDB',
          request.error,
        ),
      );
    }.toJS;

    try {
      return await completer.future;
    } catch (e) {
      if (isQuotaExceeded(e) && retries > 0) {
        // Try to free up space and retry once
        await _handleQuotaExceeded();
        return await _insertWithRetry(
          cacheObject,
          setTouchedToNow,
          retries: retries - 1,
        );
      }
      rethrow;
    }
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

    final transaction = _createTransaction(db, _metadataStoreName, 'readwrite');
    final store = transaction.objectStore(_metadataStoreName);

    final map = cacheObject.toMap(setTouchedToNow: setTouchedToNow);
    final request = store.put(map.jsify());

    request.onsuccess = (web.Event e) {
      completer.complete(1);
    }.toJS;

    request.onerror = (web.Event e) {
      e.preventDefault();
      completer.completeError(
        IndexedDbException(
          'Failed to update object in IndexedDB',
          request.error,
        ),
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
    final db = await _getDatabase();
    final completer = Completer<List<CacheObject>>();

    try {
      final transaction = _createTransaction(
        db,
        _metadataStoreName,
        'readonly',
      );
      final store = transaction.objectStore(_metadataStoreName);

      // First, get the count to determine if we're over capacity
      final countRequest = store.count();

      countRequest.onsuccess = (web.Event e) {
        final totalCount = (countRequest.result as JSNumber).toDartInt;

        if (totalCount <= capacity) {
          completer.complete([]);
          return;
        }

        // Use the touched index to iterate in sorted order (oldest first)
        final index = store.index(_touchedIndexName);
        final result = <CacheObject>[];
        final toRemoveCount = totalCount - capacity;
        var count = 0;

        // Open cursor to iterate through oldest items
        final cursorRequest = index.openCursor();

        cursorRequest.onsuccess = (web.Event e) {
          final cursor = cursorRequest.result as web.IDBCursorWithValue?;

          if (cursor != null) {
            if (count < toRemoveCount) {
              final map = _jsToMap(cursor.value);
              result.add(CacheObject.fromMap(map));
              count++;
              cursor.continue_();
            } else {
              // We have enough items, complete
              completer.complete(result);
            }
          } else {
            // No more items
            completer.complete(result);
          }
        }.toJS;

        cursorRequest.onerror = (web.Event e) {
          completer.completeError(
            Exception('Failed to iterate objects: ${cursorRequest.error}'),
          );
        }.toJS;
      }.toJS;

      countRequest.onerror = (web.Event e) {
        completer.completeError(
          Exception('Failed to count objects: ${countRequest.error}'),
        );
      }.toJS;

      return await completer.future;
    } catch (e) {
      // Fallback to old method if cursor fails (shouldn't happen with proper index)
      final allObjects = await getAllObjects();
      allObjects.sort((c1, c2) => c1.touched!.compareTo(c2.touched!));
      if (allObjects.length <= capacity) return [];
      return allObjects.getRange(0, allObjects.length - capacity).toList();
    }
  }

  @override
  Future<List<CacheObject>> getOldObjects(Duration maxAge) async {
    final oldestTimestamp = DateTime.now().subtract(maxAge);
    final db = await _getDatabase();
    final completer = Completer<List<CacheObject>>();

    try {
      final transaction = _createTransaction(
        db,
        _metadataStoreName,
        'readonly',
      );
      final store = transaction.objectStore(_metadataStoreName);

      // Use the touched index to efficiently find old objects
      final index = store.index(_touchedIndexName);
      final result = <CacheObject>[];

      // Create a key range for items older than the threshold
      // Items with touched timestamp less than oldestTimestamp
      final keyRange = web.IDBKeyRange.upperBound(
        oldestTimestamp.millisecondsSinceEpoch.toJS,
        false, // not open (inclusive)
      );

      final cursorRequest = index.openCursor(keyRange);

      cursorRequest.onsuccess = (web.Event e) {
        final cursor = cursorRequest.result as web.IDBCursorWithValue?;
        if (cursor != null) {
          final map = _jsToMap(cursor.value);
          final obj = CacheObject.fromMap(map);
          // Double-check the timestamp (defensive programming)
          if (obj.touched != null && obj.touched!.isBefore(oldestTimestamp)) {
            result.add(obj);
          }
          cursor.continue_();
        } else {
          // No more items
          completer.complete(result);
        }
      }.toJS;

      cursorRequest.onerror = (web.Event e) {
        completer.completeError(
          Exception('Failed to iterate old objects: ${cursorRequest.error}'),
        );
      }.toJS;

      return await completer.future;
    } catch (e) {
      // Fallback to old method if cursor fails
      final allObjects = await getAllObjects();
      return allObjects
          .where((element) => element.touched!.isBefore(oldestTimestamp))
          .toList();
    }
  }

  @override
  Future<int> delete(int id) async {
    final db = await _getDatabase();
    final completer = Completer<int>();

    final transaction = _createTransaction(db, _metadataStoreName, 'readwrite');
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

    try {
      final transaction = _createTransaction(
        db,
        _metadataStoreName,
        'readwrite',
      );
      final store = transaction.objectStore(_metadataStoreName);

      // Queue all delete operations in the transaction
      final deleteRequests = <web.IDBRequest>[];
      for (final id in ids) {
        deleteRequests.add(store.delete(id.toJS));
      }

      // Wait for the entire transaction to complete
      // This ensures all deletes are atomic
      transaction.oncomplete = (web.Event e) {
        completer.complete(ids.length);
      }.toJS;

      transaction.onerror = (web.Event e) {
        completer.completeError(
          Exception(
            'Failed to delete objects from IndexedDB: ${transaction.error}',
          ),
        );
      }.toJS;

      transaction.onabort = (web.Event e) {
        completer.completeError(
          Exception('Delete transaction aborted: ${transaction.error}'),
        );
      }.toJS;

      return await completer.future;
    } catch (e) {
      throw Exception('Failed to delete all objects: $e');
    }
  }

  @override
  Future<bool> close() async {
    if (!shouldClose()) {
      return false;
    }
    // Releases the connection taken in open(); it closes once no other
    // repository for this database holds it.
    _connectionPool.release();
    return true;
  }

  @override
  Future<void> deleteDataFile() async {
    await close();

    // Close the shared connection, or it would block the deletion.
    IndexedDbConnectionPool.removeInstance(databaseName);

    final completer = Completer<void>();
    final request = web.window.indexedDB.deleteDatabase(databaseName);

    request.onsuccess = (web.Event e) {
      completer.complete();
    }.toJS;

    request.onerror = (web.Event e) {
      completer.completeError(
        IndexedDbException(
          'Failed to delete IndexedDB database',
          request.error,
        ),
      );
    }.toJS;

    // A connection in another tab is still open. Those close on
    // `versionchange`, after which the deletion goes ahead and onsuccess
    // fires; until then, report why it is waiting.
    request.onblocked = (web.Event e) {
      cacheLogger.log(
        'CacheManager: deleting IndexedDB database $databaseName is blocked by '
        'a connection in another tab; waiting for it to close',
        CacheManagerLogLevel.warning,
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
