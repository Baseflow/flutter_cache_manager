import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:file/file.dart';
import 'package:flutter_cache_manager/src/storage/cache_info_repositories/indexed_db_connection_pool.dart';
import 'package:path/path.dart' as p;
import 'package:web/web.dart' as web;

/// A file implementation that stores data in IndexedDB for web platforms.
class IndexedDbFile implements File {
  IndexedDbFile(this._path, this._dbName);

  final String _path;
  final String _dbName;

  static const String _fileStoreName = 'cache_files';
  static const int _dbVersion = 2; // Incremented to match repository version

  late final IndexedDbConnectionPool _connectionPool =
      IndexedDbConnectionPool.getInstance(
        databaseName: _dbName,
        version: _dbVersion,
        onUpgrade: _onUpgradeNeeded,
      );

  void _onUpgradeNeeded(web.IDBDatabase db, web.IDBVersionChangeEvent e) {
    final oldVersion = e.oldVersion;

    // Create cache_files object store if it doesn't exist (v1)
    if (oldVersion < 1) {
      final hasFileStore = db.objectStoreNames.contains(_fileStoreName);
      if (!hasFileStore) {
        db.createObjectStore(
          _fileStoreName,
          web.IDBObjectStoreParameters(keyPath: 'path'.toJS),
        );
      }

      // Also create cache_metadata object store if it doesn't exist
      // This ensures both stores are created in the same upgrade transaction
      const metadataStoreName = 'cache_metadata';
      const keyIndexName = 'key_index';
      const touchedIndexName = 'touched_index';
      final hasMetadataStore = db.objectStoreNames.contains(metadataStoreName);
      if (!hasMetadataStore) {
        final metadataStore = db.createObjectStore(
          metadataStoreName,
          web.IDBObjectStoreParameters(
            keyPath: '_id'.toJS,
            autoIncrement: true,
          ),
        );
        // Create index on key field for fast lookups
        metadataStore.createIndex(
          keyIndexName,
          'key'.toJS,
          web.IDBIndexParameters(unique: true),
        );
        // Create index on touched field for efficient sorting
        metadataStore.createIndex(
          touchedIndexName,
          'touched'.toJS,
          web.IDBIndexParameters(unique: false),
        );
      }
    }

    // Add touched index for existing databases (v2)
    if (oldVersion < 2 && oldVersion >= 1) {
      const metadataStoreName = 'cache_metadata';
      const touchedIndexName = 'touched_index';
      final transaction = e.target as web.IDBOpenDBRequest;
      final txn = transaction.transaction;
      if (txn != null && db.objectStoreNames.contains(metadataStoreName)) {
        final store = txn.objectStore(metadataStoreName);
        if (!store.indexNames.contains(touchedIndexName)) {
          store.createIndex(
            touchedIndexName,
            'touched'.toJS,
            web.IDBIndexParameters(unique: false),
          );
        }
      }
    }
  }

  Future<web.IDBDatabase> _getDatabase() async {
    return _connectionPool.getDatabase();
  }

  /// Creates a transaction with optimal performance settings.
  web.IDBTransaction _createTransaction(
    web.IDBDatabase db,
    String storeName,
    String mode,
  ) {
    try {
      // Try to create transaction with relaxed durability (modern browsers)
      // Note: The durability hint may not be available in all browser versions
      final options = web.IDBTransactionOptions();
      return db.transaction(storeName.toJS, mode, options);
    } catch (e) {
      // Fallback for older browsers that don't support transaction options
      return db.transaction(storeName.toJS, mode);
    }
  }

  @override
  Future<Uint8List> readAsBytes() async {
    final db = await _getDatabase();
    final completer = Completer<Uint8List>();
    final transaction = _createTransaction(db, _fileStoreName, 'readonly');
    final store = transaction.objectStore(_fileStoreName);
    final request = store.get(_path.toJS);

    request.onsuccess = (web.Event e) {
      final result = request.result;
      if (result != null) {
        final obj = result as JSObject;
        final dataField = obj['data'.toJS];

        if (dataField != null && dataField.isA<JSUint8Array>()) {
          final data = dataField as JSUint8Array;
          completer.complete(data.toDart);
        } else {
          completer.complete(Uint8List(0));
        }
      } else {
        completer.completeError(
          Exception('File not found in IndexedDB: $_path'),
        );
      }
    }.toJS;

    request.onerror = (web.Event e) {
      completer.completeError(
        Exception('Failed to read file from IndexedDB: ${request.error}'),
      );
    }.toJS;

    return completer.future;
  }

  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) async {
    final db = await _getDatabase();
    final completer = Completer<void>();
    final transaction = _createTransaction(db, _fileStoreName, 'readwrite');
    final store = transaction.objectStore(_fileStoreName);

    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

    final fileObject = <String, dynamic>{'path': _path, 'data': data}.jsify();

    final request = store.put(fileObject);

    request.onsuccess = (web.Event e) {
      completer.complete();
    }.toJS;

    request.onerror = (web.Event e) {
      completer.completeError(
        Exception('Failed to write file to IndexedDB: ${request.error}'),
      );
    }.toJS;

    await completer.future;
    return this;
  }

  @override
  IOSink openWrite({FileMode mode = FileMode.write, Encoding encoding = utf8}) {
    return _IndexedDbIOSink(this, mode, encoding);
  }

  @override
  Stream<List<int>> openRead([int? start, int? end]) async* {
    final bytes = await readAsBytes();
    final startOffset = start ?? 0;
    final endOffset = end ?? bytes.length;
    yield bytes.sublist(startOffset, endOffset);
  }

  @override
  Future<bool> exists() async {
    final db = await _getDatabase();
    final completer = Completer<bool>();
    final transaction = _createTransaction(db, _fileStoreName, 'readonly');
    final store = transaction.objectStore(_fileStoreName);
    final request = store.get(_path.toJS);

    request.onsuccess = (web.Event e) {
      final result = request.result;
      completer.complete(result != null);
    }.toJS;

    request.onerror = (web.Event e) {
      completer.complete(false);
    }.toJS;

    return completer.future;
  }

  @override
  bool existsSync() {
    throw UnsupportedError('existsSync is not supported on web');
  }

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    final db = await _getDatabase();
    final completer = Completer<void>();
    final transaction = _createTransaction(db, _fileStoreName, 'readwrite');
    final store = transaction.objectStore(_fileStoreName);
    final request = store.delete(_path.toJS);

    request.onsuccess = (web.Event e) {
      completer.complete();
    }.toJS;

    request.onerror = (web.Event e) {
      completer.completeError(
        Exception('Failed to delete file from IndexedDB: ${request.error}'),
      );
    }.toJS;

    await completer.future;
    return this;
  }

  @override
  void deleteSync({bool recursive = false}) {
    throw UnsupportedError('deleteSync is not supported on web');
  }

  @override
  String get path => _path;

  @override
  String get basename => p.basename(_path);

  @override
  String get dirname => p.dirname(_path);

  @override
  Uri get uri => Uri.file(_path);

  @override
  Directory get parent =>
      throw UnsupportedError('parent is not supported for IndexedDbFile');

  @override
  bool get isAbsolute => true;

  @override
  File get absolute => this;

  @override
  Future<File> copy(String newPath) {
    throw UnsupportedError('copy is not supported for IndexedDbFile');
  }

  @override
  File copySync(String newPath) {
    throw UnsupportedError('copySync is not supported for IndexedDbFile');
  }

  @override
  Future<File> create({bool recursive = false, bool exclusive = false}) async {
    // For IndexedDB, we don't need to create the file explicitly
    // It will be created when we write to it
    return this;
  }

  @override
  void createSync({bool recursive = false, bool exclusive = false}) {
    throw UnsupportedError('createSync is not supported on web');
  }

  @override
  Future<DateTime> lastAccessed() {
    throw UnsupportedError('lastAccessed is not supported for IndexedDbFile');
  }

  @override
  DateTime lastAccessedSync() {
    throw UnsupportedError('lastAccessedSync is not supported on web');
  }

  @override
  Future<DateTime> lastModified() {
    throw UnsupportedError('lastModified is not supported for IndexedDbFile');
  }

  @override
  DateTime lastModifiedSync() {
    throw UnsupportedError('lastModifiedSync is not supported on web');
  }

  @override
  Future<int> length() async {
    final bytes = await readAsBytes();
    return bytes.length;
  }

  @override
  int lengthSync() {
    throw UnsupportedError('lengthSync is not supported on web');
  }

  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) {
    throw UnsupportedError('open is not supported for IndexedDbFile');
  }

  @override
  RandomAccessFile openSync({FileMode mode = FileMode.read}) {
    throw UnsupportedError('openSync is not supported on web');
  }

  @override
  Stream<FileSystemEvent> watch({
    int events = FileSystemEvent.all,
    bool recursive = false,
  }) {
    throw UnsupportedError('watch is not supported for IndexedDbFile');
  }

  @override
  Future<String> readAsString({Encoding encoding = utf8}) async {
    final bytes = await readAsBytes();
    return encoding.decode(bytes);
  }

  @override
  String readAsStringSync({Encoding encoding = utf8}) {
    throw UnsupportedError('readAsStringSync is not supported on web');
  }

  @override
  Uint8List readAsBytesSync() {
    throw UnsupportedError('readAsBytesSync is not supported on web');
  }

  @override
  Future<List<String>> readAsLines({Encoding encoding = utf8}) async {
    final content = await readAsString(encoding: encoding);
    return content.split('\n');
  }

  @override
  List<String> readAsLinesSync({Encoding encoding = utf8}) {
    throw UnsupportedError('readAsLinesSync is not supported on web');
  }

  @override
  Future<File> rename(String newPath) {
    throw UnsupportedError('rename is not supported for IndexedDbFile');
  }

  @override
  File renameSync(String newPath) {
    throw UnsupportedError('renameSync is not supported on web');
  }

  @override
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) async {
    final bytes = encoding.encode(contents);
    return writeAsBytes(bytes, mode: mode, flush: flush);
  }

  @override
  void writeAsStringSync(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) {
    throw UnsupportedError('writeAsStringSync is not supported on web');
  }

  @override
  void writeAsBytesSync(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) {
    throw UnsupportedError('writeAsBytesSync is not supported on web');
  }

  @override
  Future<String> resolveSymbolicLinks() async {
    return _path;
  }

  @override
  String resolveSymbolicLinksSync() {
    return _path;
  }

  @override
  Future<FileStat> stat() {
    throw UnsupportedError('stat is not supported for IndexedDbFile');
  }

  @override
  FileStat statSync() {
    throw UnsupportedError('statSync is not supported on web');
  }

  @override
  Future<File> setLastAccessed(DateTime time) {
    throw UnsupportedError(
      'setLastAccessed is not supported for IndexedDbFile',
    );
  }

  @override
  void setLastAccessedSync(DateTime time) {
    throw UnsupportedError('setLastAccessedSync is not supported on web');
  }

  @override
  Future<File> setLastModified(DateTime time) {
    throw UnsupportedError(
      'setLastModified is not supported for IndexedDbFile',
    );
  }

  @override
  void setLastModifiedSync(DateTime time) {
    throw UnsupportedError('setLastModifiedSync is not supported on web');
  }

  @override
  FileSystem get fileSystem =>
      throw UnsupportedError('fileSystem is not supported for IndexedDbFile');
}

class _IndexedDbIOSink implements IOSink {
  _IndexedDbIOSink(this._file, this._mode, this.encoding);

  final IndexedDbFile _file;
  final FileMode _mode;
  final _buffer = <int>[];
  final _completer = Completer<void>();
  bool _isClosed = false;

  @override
  Encoding encoding;

  @override
  void add(List<int> data) {
    if (_isClosed) {
      throw StateError('StreamSink is closed');
    }
    _buffer.addAll(data);
  }

  @override
  void write(Object? object) {
    if (_isClosed) {
      throw StateError('StreamSink is closed');
    }
    final string = object.toString();
    _buffer.addAll(encoding.encode(string));
  }

  @override
  void writeAll(Iterable objects, [String separator = '']) {
    if (_isClosed) {
      throw StateError('StreamSink is closed');
    }
    final string = objects.join(separator);
    _buffer.addAll(encoding.encode(string));
  }

  @override
  void writeln([Object? object = '']) {
    write(object);
    write('\n');
  }

  @override
  void writeCharCode(int charCode) {
    write(String.fromCharCode(charCode));
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    if (_isClosed) {
      throw StateError('StreamSink is closed');
    }
    _completer.completeError(error, stackTrace);
    _isClosed = true;
  }

  @override
  Future addStream(Stream<List<int>> stream) {
    if (_isClosed) {
      throw StateError('StreamSink is closed');
    }
    final completer = Completer<void>();
    stream.listen(
      (data) => _buffer.addAll(data),
      onError: completer.completeError,
      onDone: completer.complete,
      cancelOnError: true,
    );
    return completer.future;
  }

  @override
  Future flush() async {
    if (_buffer.isNotEmpty) {
      await _file.writeAsBytes(_buffer, mode: _mode);
    }
  }

  @override
  Future close() async {
    if (_isClosed) {
      return _completer.future;
    }
    _isClosed = true;
    try {
      await flush();
      _completer.complete();
    } catch (e, s) {
      _completer.completeError(e, s);
    }
    return _completer.future;
  }

  @override
  Future get done => _completer.future;
}

/// Extension to access JSObject properties using [] operator
extension JSObjectExtension on JSObject {
  external JSAny? operator [](JSAny key);
}
