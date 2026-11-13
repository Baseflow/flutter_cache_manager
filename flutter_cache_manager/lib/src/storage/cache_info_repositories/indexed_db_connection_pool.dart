import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_cache_manager/src/logger.dart';
import 'package:flutter_cache_manager/src/storage/cache_info_repositories/indexed_db_schema.dart';
import 'package:web/web.dart' as web;

/// One shared IndexedDB connection per database name.
///
/// Opening a database costs 50-200ms, so the cache info repository and every
/// file reuse one connection. The database is always opened at
/// [IndexedDbSchema.version] and upgraded with [IndexedDbSchema.upgrade].
///
/// Long-lived users (the cache info repository) [acquire] the connection and
/// [release] it when closed; the connection is closed when the last of them
/// releases it. Files use [getDatabase] without holding the connection, and
/// reopen it on demand.
class IndexedDbConnectionPool {
  IndexedDbConnectionPool._(this.databaseName);

  static final Map<String, IndexedDbConnectionPool> _instances = {};

  /// Get or create the connection pool for [databaseName].
  static IndexedDbConnectionPool getInstance({required String databaseName}) {
    return _instances.putIfAbsent(
      databaseName,
      () => IndexedDbConnectionPool._(databaseName),
    );
  }

  final String databaseName;

  web.IDBDatabase? _db;
  Future<web.IDBDatabase>? _opening;
  int _holders = 0;

  /// Whether the connection is currently open.
  bool get isOpen => _db != null;

  /// The number of [acquire]s not yet [release]d.
  int get holders => _holders;

  /// Get the database connection, opening it if necessary.
  Future<web.IDBDatabase> getDatabase() {
    final db = _db;
    if (db != null) return Future.value(db);
    return _opening ??= _open().whenComplete(() => _opening = null);
  }

  /// Opens the connection and keeps it open until a matching [release].
  Future<web.IDBDatabase> acquire() {
    _holders++;
    return getDatabase();
  }

  /// Releases an [acquire]. Closes the connection when nobody holds it.
  void release() {
    if (_holders == 0) return;
    _holders--;
    if (_holders == 0) close();
  }

  Future<web.IDBDatabase> _open() {
    final completer = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open(
      databaseName,
      IndexedDbSchema.version,
    );

    request.onupgradeneeded = (web.IDBVersionChangeEvent event) {
      IndexedDbSchema.upgrade(request.result as web.IDBDatabase, event);
    }.toJS;

    request.onsuccess = (web.Event _) {
      final db = request.result as web.IDBDatabase;
      // The browser closed the connection (storage cleared, for example).
      db.onclose = (web.Event _) {
        if (identical(_db, db)) _db = null;
      }.toJS;
      // Another tab wants to upgrade the schema. Close so it is not blocked;
      // the next operation here reopens at the new version.
      db.onversionchange = (web.IDBVersionChangeEvent _) {
        db.close();
        if (identical(_db, db)) _db = null;
      }.toJS;
      _db = db;
      completer.complete(db);
    }.toJS;

    request.onerror = (web.Event _) {
      completer.completeError(
        IndexedDbException(
          'Failed to open IndexedDB database $databaseName',
          request.error,
        ),
      );
    }.toJS;

    // Another tab still has the database open at an older version. It closes
    // its connection on `versionchange` (see above), after which this open
    // continues; a tab running an older release of this package might not,
    // so say why the cache is waiting.
    request.onblocked = (web.Event _) {
      cacheLogger.log(
        'CacheManager: opening IndexedDB database $databaseName is blocked by '
        'a connection in another tab; waiting for it to close',
        CacheManagerLogLevel.warning,
      );
    }.toJS;

    return completer.future;
  }

  /// Closes the connection now, regardless of holders. It is reopened by the
  /// next [getDatabase].
  void close() {
    _db?.close();
    _db = null;
  }

  /// Closes and forgets the pool for [databaseName].
  static void removeInstance(String databaseName) {
    _instances.remove(databaseName)?.close();
  }

  /// Closes and forgets every pool (used for tests and app shutdown).
  static void closeAll() {
    for (final pool in _instances.values) {
      pool.close();
    }
    _instances.clear();
  }
}
