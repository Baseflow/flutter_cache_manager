import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_cache_manager/src/logger.dart';
import 'package:flutter_cache_manager/src/storage/cache_object.dart';
import 'package:web/web.dart' as web;

/// The single definition of the IndexedDB schema shared by
/// `IndexedDbCacheInfoRepository` (cache info) and `IndexedDbFile` (file
/// contents). Both use the same database by default, and the connection pool
/// always upgrades it with [upgrade], so it no longer matters which of them
/// opens the database first.
abstract final class IndexedDbSchema {
  /// Version history:
  /// 1. `cache_metadata` (+ `key_index`) and `cache_files` (`{path, data}`).
  /// 2. `touched_index` on `cache_metadata`.
  /// 3. `cache_file_chunks`: file contents are stored in chunks, and a
  ///    `cache_files` record becomes a header (`{path, length, chunkCount,
  ///    chunkSize}`). Version 1/2 records (`{path, data}`) remain readable.
  static const int version = 3;

  static const String metadataStore = 'cache_metadata';
  static const String keyIndex = 'key_index';
  static const String touchedIndex = 'touched_index';

  static const String filesStore = 'cache_files';
  static const String chunksStore = 'cache_file_chunks';

  /// Size of the chunks file contents are written in.
  static const int chunkSize = 512 * 1024;

  /// Brings [db] up to [version]. Runs inside the version change transaction.
  static void upgrade(web.IDBDatabase db, web.IDBVersionChangeEvent event) {
    final names = db.objectStoreNames;
    final transaction = (event.target as web.IDBOpenDBRequest).transaction;

    if (!names.contains(metadataStore)) {
      final metadata = db.createObjectStore(
        metadataStore,
        web.IDBObjectStoreParameters(
          keyPath: CacheObject.columnId.toJS,
          autoIncrement: true,
        ),
      );
      metadata.createIndex(
        keyIndex,
        CacheObject.columnKey.toJS,
        web.IDBIndexParameters(unique: true),
      );
    }
    final metadata = transaction?.objectStore(metadataStore);
    if (metadata != null && !metadata.indexNames.contains(touchedIndex)) {
      metadata.createIndex(
        touchedIndex,
        CacheObject.columnTouched.toJS,
        web.IDBIndexParameters(unique: false),
      );
    }

    if (!names.contains(filesStore)) {
      db.createObjectStore(
        filesStore,
        web.IDBObjectStoreParameters(keyPath: 'path'.toJS),
      );
    }
    if (!names.contains(chunksStore)) {
      db.createObjectStore(
        chunksStore,
        web.IDBObjectStoreParameters(
          keyPath: <JSString>['path'.toJS, 'index'.toJS].toJS,
        ),
      );
    }
  }

  /// The key of chunk [index] of the file at [path].
  static JSAny chunkKey(String path, int index) =>
      <JSAny>[path.toJS, index.toJS].toJS;

  /// A key range covering every chunk of the file at [path].
  static web.IDBKeyRange chunksOf(String path) =>
      web.IDBKeyRange.bound(chunkKey(path, 0), chunkKey(path, 0x7fffffff));
}

/// Creates a transaction over [stores]. Cache data can always be downloaded
/// again, so writes request `relaxed` durability: the browser may acknowledge
/// them before they are flushed to disk, which is much faster for many small
/// writes. Browsers without durability hints ignore the option.
web.IDBTransaction createIndexedDbTransaction(
  web.IDBDatabase db,
  List<String> stores,
  String mode,
) {
  final names = stores.length == 1
      ? stores.single.toJS
      : stores.map((s) => s.toJS).toList().toJS;
  return db.transaction(
    names,
    mode,
    web.IDBTransactionOptions(durability: 'relaxed'),
  );
}

/// Completes with the result of [request].
Future<JSAny?> indexedDbRequest(web.IDBRequest request, String description) {
  final completer = Completer<JSAny?>();
  request.onsuccess = (web.Event _) {
    completer.complete(request.result);
  }.toJS;
  request.onerror = (web.Event event) {
    // Handled here; don't let the error abort the whole transaction.
    event.preventDefault();
    completer.completeError(IndexedDbException(description, request.error));
  }.toJS;
  return completer.future;
}

/// Completes when [transaction] has committed.
Future<void> indexedDbTransactionDone(
  web.IDBTransaction transaction,
  String description,
) {
  final completer = Completer<void>();
  transaction.oncomplete = (web.Event _) {
    if (!completer.isCompleted) completer.complete();
  }.toJS;
  transaction.onerror = (web.Event _) {
    if (!completer.isCompleted) {
      completer.completeError(
        IndexedDbException(description, transaction.error),
      );
    }
  }.toJS;
  transaction.onabort = (web.Event _) {
    if (!completer.isCompleted) {
      completer.completeError(
        IndexedDbException('$description (aborted)', transaction.error),
      );
    }
  }.toJS;
  return completer.future;
}

/// An IndexedDB request or transaction failed.
class IndexedDbException implements Exception {
  IndexedDbException(this.message, web.DOMException? error)
    : name = error?.name,
      detail = error?.message;

  final String message;

  /// The DOMException name, such as `QuotaExceededError`.
  final String? name;
  final String? detail;

  /// Whether the browser refused the write because storage is full.
  bool get isQuotaExceeded => name == 'QuotaExceededError';

  @override
  String toString() => 'IndexedDbException: $message ($name: $detail)';
}

/// Whether [error] means the browser's storage quota is exhausted.
bool isQuotaExceeded(Object error) {
  if (error is IndexedDbException) return error.isQuotaExceeded;
  final text = error.toString().toLowerCase();
  return text.contains('quotaexceedederror');
}

/// Frees space after a quota error by removing the least recently used
/// tenth (at most [maxEntries]) of the cache: their cache info rows and the
/// file contents they point to, in one transaction. Removing only the rows
/// would leave the contents, which take up the space, behind.
///
/// Returns the number of entries removed.
Future<int> evictLeastRecentlyUsed(
  web.IDBDatabase db, {
  int maxEntries = 50,
}) async {
  if (!db.objectStoreNames.contains(IndexedDbSchema.metadataStore)) return 0;
  final hasFiles =
      db.objectStoreNames.contains(IndexedDbSchema.filesStore) &&
      db.objectStoreNames.contains(IndexedDbSchema.chunksStore);

  // Count in its own transaction: a transaction must not wait on Dart code
  // between requests, or it may commit early.
  final counting = createIndexedDbTransaction(db, [
    IndexedDbSchema.metadataStore,
  ], 'readonly');
  final total =
      ((await indexedDbRequest(
                counting.objectStore(IndexedDbSchema.metadataStore).count(),
                'Failed to count cache entries',
              ))
              as JSNumber)
          .toDartInt;
  final toRemove = (total * 0.1).ceil().clamp(0, maxEntries);
  if (toRemove == 0) return 0;

  final transaction = createIndexedDbTransaction(db, [
    IndexedDbSchema.metadataStore,
    if (hasFiles) IndexedDbSchema.filesStore,
    if (hasFiles) IndexedDbSchema.chunksStore,
  ], 'readwrite');
  final done = indexedDbTransactionDone(transaction, 'Failed to free space');
  final cursorRequest = transaction
      .objectStore(IndexedDbSchema.metadataStore)
      .index(IndexedDbSchema.touchedIndex)
      .openCursor();
  var removed = 0;
  // Every request is issued from a request callback, so the transaction
  // stays active until the last one.
  cursorRequest.onsuccess = (web.Event _) {
    final cursor = cursorRequest.result as web.IDBCursorWithValue?;
    if (cursor == null || removed >= toRemove) return;
    final row = cursor.value as JSObject;
    final path = row.getProperty<JSAny?>(CacheObject.columnPath.toJS);
    if (hasFiles && path != null && path.isA<JSString>()) {
      final relativePath = (path as JSString).toDart;
      transaction
          .objectStore(IndexedDbSchema.filesStore)
          .delete(relativePath.toJS);
      transaction
          .objectStore(IndexedDbSchema.chunksStore)
          .delete(IndexedDbSchema.chunksOf(relativePath));
    }
    cursor.delete();
    removed++;
    cursor.continue_();
  }.toJS;
  await done;
  cacheLogger.log(
    'CacheManager: storage quota exceeded, removed $removed least recently '
    'used cache entries',
    CacheManagerLogLevel.warning,
  );
  return removed;
}
