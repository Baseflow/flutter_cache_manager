import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_cache_manager/src/storage/cache_info_repositories/indexed_db_connection_pool.dart';
import 'package:flutter_cache_manager/src/storage/cache_info_repositories/indexed_db_schema.dart';
import 'package:web/web.dart' as web;

/// Closes the pooled connection and deletes [name].
Future<void> deleteDatabase(String name) {
  IndexedDbConnectionPool.removeInstance(name);
  final completer = Completer<void>();
  final request = web.window.indexedDB.deleteDatabase(name);
  request.onsuccess = (web.Event _) {
    completer.complete();
  }.toJS;
  request.onerror = (web.Event _) {
    completer.completeError(StateError('delete failed: ${request.error}'));
  }.toJS;
  return completer.future;
}

Future<web.IDBDatabase> _db(String name) =>
    IndexedDbConnectionPool.getInstance(databaseName: name).getDatabase();

/// The number of chunk records stored for [path].
Future<int> countChunks(String db, String path) async {
  final transaction = createIndexedDbTransaction(await _db(db), [
    IndexedDbSchema.chunksStore,
  ], 'readonly');
  final count = await indexedDbRequest(
    transaction
        .objectStore(IndexedDbSchema.chunksStore)
        .count(IndexedDbSchema.chunksOf(path)),
    'count',
  );
  return (count as JSNumber).toDartInt;
}

/// The number of records in [store].
Future<int> countRecords(String db, String store) async {
  final transaction = createIndexedDbTransaction(await _db(db), [
    store,
  ], 'readonly');
  final count = await indexedDbRequest(
    transaction.objectStore(store).count(),
    'count',
  );
  return (count as JSNumber).toDartInt;
}

/// Stores [value] in [store] directly.
Future<void> putRecord(String db, String store, JSAny value) async {
  final transaction = createIndexedDbTransaction(await _db(db), [
    store,
  ], 'readwrite');
  final done = indexedDbTransactionDone(transaction, 'put');
  transaction.objectStore(store).put(value);
  await done;
}
