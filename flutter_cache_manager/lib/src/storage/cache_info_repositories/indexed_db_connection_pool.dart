import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// A singleton connection pool for IndexedDB databases.
/// This prevents the performance overhead of repeatedly opening and closing
/// database connections, which can be 50-200ms per operation.
class IndexedDbConnectionPool {
  static final Map<String, IndexedDbConnectionPool> _instances = {};

  final String databaseName;
  final int version;
  final void Function(web.IDBDatabase, web.IDBVersionChangeEvent)? onUpgrade;

  web.IDBDatabase? _db;
  Completer<web.IDBDatabase>? _openingCompleter;
  bool _isClosed = false;

  IndexedDbConnectionPool._({
    required this.databaseName,
    required this.version,
    this.onUpgrade,
  });

  /// Get or create a connection pool for the specified database.
  static IndexedDbConnectionPool getInstance({
    required String databaseName,
    int version = 1,
    void Function(web.IDBDatabase, web.IDBVersionChangeEvent)? onUpgrade,
  }) {
    if (!_instances.containsKey(databaseName)) {
      _instances[databaseName] = IndexedDbConnectionPool._(
        databaseName: databaseName,
        version: version,
        onUpgrade: onUpgrade,
      );
    }
    return _instances[databaseName]!;
  }

  /// Get the database connection, opening it if necessary.
  /// This reuses the same connection across all operations for performance.
  Future<web.IDBDatabase> getDatabase() async {
    // If already open, return immediately
    if (_db != null && !_isClosed) {
      return _db!;
    }

    // If currently opening, wait for that operation
    if (_openingCompleter != null) {
      return _openingCompleter!.future;
    }

    // Start opening the database
    _openingCompleter = Completer<web.IDBDatabase>();
    _isClosed = false;

    try {
      final request = web.window.indexedDB.open(databaseName, version);

      request.onupgradeneeded = (web.IDBVersionChangeEvent e) {
        final db = request.result as web.IDBDatabase;
        onUpgrade?.call(db, e);
      }.toJS;

      request.onsuccess = (web.Event e) {
        _db = request.result as web.IDBDatabase;

        // Handle connection being closed externally (e.g., by browser)
        _db!.onclose = (web.Event e) {
          _db = null;
          _isClosed = true;
        }.toJS;

        // Handle version change (e.g., another tab upgraded the schema)
        _db!.onversionchange = (web.IDBVersionChangeEvent e) {
          _db?.close();
          _db = null;
          _isClosed = true;
        }.toJS;

        _openingCompleter?.complete(_db!);
        _openingCompleter = null;
      }.toJS;

      request.onerror = (web.Event e) {
        _openingCompleter?.completeError(
          Exception('Failed to open IndexedDB: ${request.error}'),
        );
        _openingCompleter = null;
      }.toJS;

      request.onblocked = (web.Event e) {
        // Another connection is blocking the upgrade
        // This is usually because another tab has an older version open
      }.toJS;

      return await _openingCompleter!.future;
    } catch (e) {
      _openingCompleter = null;
      rethrow;
    }
  }

  /// Close the database connection.
  /// Note: This should typically only be called on app shutdown,
  /// not after individual operations.
  void close() {
    if (_db != null && !_isClosed) {
      _db!.close();
      _db = null;
      _isClosed = true;
    }
    _openingCompleter = null;
  }

  /// Check if the database is currently open.
  bool get isOpen => _db != null && !_isClosed;

  /// Remove this instance from the pool (used for testing).
  static void removeInstance(String databaseName) {
    _instances[databaseName]?.close();
    _instances.remove(databaseName);
  }

  /// Close all connections (used for testing or app shutdown).
  static void closeAll() {
    for (final pool in _instances.values) {
      pool.close();
    }
    _instances.clear();
  }
}
