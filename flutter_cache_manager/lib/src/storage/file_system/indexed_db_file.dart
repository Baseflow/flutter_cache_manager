import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math';
import 'dart:typed_data';

import 'package:file/file.dart';
import 'package:flutter_cache_manager/src/storage/cache_info_repositories/indexed_db_connection_pool.dart';
import 'package:flutter_cache_manager/src/storage/cache_info_repositories/indexed_db_schema.dart';
import 'package:path/path.dart' as p;
import 'package:web/web.dart' as web;

/// A file stored in IndexedDB, for web platforms.
///
/// The contents are stored in chunks of [IndexedDbSchema.chunkSize] in the
/// `cache_file_chunks` store, and a header with the length and chunk count in
/// `cache_files`. The header is written last, when the file is closed, so a
/// file whose write did not finish does not [exists]. Files written by
/// earlier versions (one `{path, data}` record) are still readable.
class IndexedDbFile implements File {
  IndexedDbFile(this._path, this._dbName);

  final String _path;
  final String _dbName;

  static const String _filesStore = IndexedDbSchema.filesStore;
  static const String _chunksStore = IndexedDbSchema.chunksStore;

  IndexedDbConnectionPool get _connectionPool =>
      IndexedDbConnectionPool.getInstance(databaseName: _dbName);

  Future<web.IDBDatabase> _getDatabase() => _connectionPool.getDatabase();

  Future<_FileHeader?> _readHeader() async {
    final db = await _getDatabase();
    final transaction = createIndexedDbTransaction(db, [
      _filesStore,
    ], 'readonly');
    final result = await indexedDbRequest(
      transaction.objectStore(_filesStore).get(_path.toJS),
      'Failed to read $_path from IndexedDB',
    );
    return _FileHeader.fromJS(result);
  }

  Future<Uint8List> _readChunk(int index) async {
    final db = await _getDatabase();
    final transaction = createIndexedDbTransaction(db, [
      _chunksStore,
    ], 'readonly');
    final result = await indexedDbRequest(
      transaction
          .objectStore(_chunksStore)
          .get(IndexedDbSchema.chunkKey(_path, index)),
      'Failed to read $_path from IndexedDB',
    );
    if (result == null || result.isUndefinedOrNull) {
      throw FileSystemException('Missing chunk $index in IndexedDB', _path);
    }
    final data = (result as JSObject).getProperty<JSAny?>('data'.toJS);
    if (data == null || !data.isA<JSUint8Array>()) return Uint8List(0);
    return (data as JSUint8Array).toDart;
  }

  /// Removes the header and every chunk of this file, written or partial.
  Future<void> _deleteContents() async {
    final db = await _getDatabase();
    final transaction = createIndexedDbTransaction(db, [
      _filesStore,
      _chunksStore,
    ], 'readwrite');
    final done = indexedDbTransactionDone(
      transaction,
      'Failed to delete $_path from IndexedDB',
    );
    transaction.objectStore(_filesStore).delete(_path.toJS);
    transaction
        .objectStore(_chunksStore)
        .delete(IndexedDbSchema.chunksOf(_path));
    await done;
  }

  @override
  Future<Uint8List> readAsBytes() async {
    final header = await _readHeader();
    if (header == null) {
      throw FileSystemException('File not found in IndexedDB', _path);
    }
    if (header.legacyData != null) return header.legacyData!;
    if (header.chunkCount == 1) return _readChunk(0);
    final builder = BytesBuilder(copy: false);
    await for (final chunk in _read(header, 0, header.length)) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) async {
    final sink = openWrite(mode: mode);
    sink.add(bytes);
    await sink.close();
    return this;
  }

  /// Opens a sink that writes the file in chunks as data arrives, instead of
  /// buffering the whole file.
  @override
  IOSink openWrite({FileMode mode = FileMode.write, Encoding encoding = utf8}) {
    return _IndexedDbIOSink(this, mode, encoding);
  }

  /// Streams the file one chunk at a time.
  @override
  Stream<List<int>> openRead([int? start, int? end]) async* {
    final header = await _readHeader();
    if (header == null) {
      throw FileSystemException('File not found in IndexedDB', _path);
    }
    final from = start ?? 0;
    final to = min(end ?? header.length, header.length);
    if (from >= to) return;
    final legacy = header.legacyData;
    if (legacy != null) {
      yield Uint8List.sublistView(legacy, from, to);
      return;
    }
    yield* _read(header, from, to);
  }

  Stream<Uint8List> _read(_FileHeader header, int from, int to) async* {
    final size = header.chunkSize;
    for (var index = from ~/ size; index * size < to; index++) {
      final chunk = await _readChunk(index);
      final chunkStart = index * size;
      final sliceStart = max(from - chunkStart, 0);
      final sliceEnd = min(to - chunkStart, chunk.length);
      yield sliceStart == 0 && sliceEnd == chunk.length
          ? chunk
          : Uint8List.sublistView(chunk, sliceStart, sliceEnd);
    }
  }

  /// Checks the key only; the contents are not read.
  @override
  Future<bool> exists() async {
    final db = await _getDatabase();
    final transaction = createIndexedDbTransaction(db, [
      _filesStore,
    ], 'readonly');
    final count = await indexedDbRequest(
      transaction.objectStore(_filesStore).count(_path.toJS),
      'Failed to look up $_path in IndexedDB',
    );
    return (count as JSNumber).toDartInt > 0;
  }

  @override
  bool existsSync() {
    throw UnsupportedError('existsSync is not supported on web');
  }

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    await _deleteContents();
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

  /// The size recorded when the file was written; the contents are not read.
  @override
  Future<int> length() async {
    final header = await _readHeader();
    if (header == null) {
      throw FileSystemException('File not found in IndexedDB', _path);
    }
    return header.length;
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

class _FileHeader {
  _FileHeader({
    required this.length,
    required this.chunkCount,
    required this.chunkSize,
    this.legacyData,
  });

  static _FileHeader? fromJS(JSAny? value) {
    if (value == null || value.isUndefinedOrNull) return null;
    final record = value as JSObject;
    final data = record.getProperty<JSAny?>('data'.toJS);
    if (data != null && data.isA<JSUint8Array>()) {
      // Written by an earlier version, as a single record.
      final bytes = (data as JSUint8Array).toDart;
      return _FileHeader(
        length: bytes.length,
        chunkCount: 1,
        chunkSize: max(bytes.length, 1),
        legacyData: bytes,
      );
    }
    int read(String name) =>
        (record.getProperty<JSAny?>(name.toJS) as JSNumber?)?.toDartInt ?? 0;
    return _FileHeader(
      length: read('length'),
      chunkCount: read('chunkCount'),
      chunkSize: max(read('chunkSize'), 1),
    );
  }

  final int length;
  final int chunkCount;
  final int chunkSize;
  final Uint8List? legacyData;
}

/// Writes an [IndexedDbFile] in chunks of [IndexedDbSchema.chunkSize] while
/// data arrives, so at most about one chunk per pending write is held in
/// memory instead of the whole file. [close] writes the header that makes the
/// file visible. If a write fails, the chunks written so far are removed and
/// [close] (and [done]) complete with the error.
class _IndexedDbIOSink implements IOSink {
  _IndexedDbIOSink(this._file, FileMode mode, this.encoding) {
    _pending = _prepare(mode).then(
      (_) => _drainEarly(),
      onError: (Object e, StackTrace s) {
        _error ??= (e, s);
        _early.clear();
      },
    );
  }

  final IndexedDbFile _file;
  final _buffer = BytesBuilder(copy: true);
  final _done = Completer<void>();
  late Future<void> _pending;
  int _nextIndex = 0;
  int _length = 0;
  (Object, StackTrace)? _error;
  bool _isClosed = false;

  /// Data added before [_prepare] finished. In append mode the existing
  /// partial last chunk has to go into the buffer first, and the next chunk
  /// index is only known once the header is read, so nothing is buffered or
  /// queued until then.
  final List<Uint8List> _early = [];
  bool _isPrepared = false;

  @override
  Encoding encoding;

  int get _chunkSize => IndexedDbSchema.chunkSize;

  Future<void> _prepare(FileMode mode) async {
    final append = mode == FileMode.append || mode == FileMode.writeOnlyAppend;
    if (!append) {
      await _file._deleteContents();
      return;
    }
    final header = await _file._readHeader();
    if (header == null) return;
    // Continue after the existing content: rewrite a legacy record or a
    // partial last chunk through the buffer, so every chunk but the last is
    // full and offsets stay chunk-aligned.
    if (header.legacyData != null) {
      await _file._deleteContents();
      _buffer.add(header.legacyData!);
      return;
    }
    final lastSize = header.length - (header.chunkCount - 1) * _chunkSize;
    if (header.chunkCount > 0 && lastSize < _chunkSize) {
      _buffer.add(await _file._readChunk(header.chunkCount - 1));
      _nextIndex = header.chunkCount - 1;
    } else {
      _nextIndex = header.chunkCount;
    }
    _length = _nextIndex * _chunkSize;
  }

  void _drainEarly() {
    _isPrepared = true;
    final early = List.of(_early);
    _early.clear();
    for (final data in early) {
      _addPrepared(data);
    }
  }

  void _checkOpen() {
    if (_isClosed) throw StateError('StreamSink is closed');
  }

  @override
  void add(List<int> data) {
    _checkOpen();
    if (_error != null) return;
    if (!_isPrepared) {
      _early.add(Uint8List.fromList(data));
      return;
    }
    _addPrepared(data);
  }

  void _addPrepared(List<int> data) {
    _buffer.add(data);
    if (_buffer.length < _chunkSize) return;
    final bytes = _buffer.takeBytes();
    var offset = 0;
    while (bytes.length - offset >= _chunkSize) {
      _enqueue(Uint8List.sublistView(bytes, offset, offset + _chunkSize));
      offset += _chunkSize;
    }
    if (offset < bytes.length) {
      _buffer.add(Uint8List.sublistView(bytes, offset));
    }
  }

  void _enqueue(Uint8List chunk) {
    final index = _nextIndex++;
    _length += chunk.length;
    _pending = _pending.then((_) {
      if (_error != null) return null;
      return _putChunk(index, chunk);
    });
  }

  Future<void> _putChunk(
    int index,
    Uint8List chunk, {
    bool retry = true,
  }) async {
    try {
      final db = await _file._getDatabase();
      final transaction = createIndexedDbTransaction(db, [
        IndexedDbSchema.chunksStore,
      ], 'readwrite');
      final done = indexedDbTransactionDone(
        transaction,
        'Failed to write ${_file.path} to IndexedDB',
      );
      transaction
          .objectStore(IndexedDbSchema.chunksStore)
          .put(
            <String, Object>{
              'path': _file.path,
              'index': index,
              'data': chunk,
            }.jsify(),
          );
      await done;
    } on Object catch (e, s) {
      if (retry && isQuotaExceeded(e)) {
        await evictLeastRecentlyUsed(await _file._getDatabase());
        return _putChunk(index, chunk, retry: false);
      }
      _error ??= (e, s);
    }
  }

  Future<void> _putHeader() async {
    final db = await _file._getDatabase();
    final transaction = createIndexedDbTransaction(db, [
      IndexedDbSchema.filesStore,
    ], 'readwrite');
    final done = indexedDbTransactionDone(
      transaction,
      'Failed to write ${_file.path} to IndexedDB',
    );
    transaction
        .objectStore(IndexedDbSchema.filesStore)
        .put(
          <String, Object>{
            'path': _file.path,
            'length': _length,
            'chunkCount': _nextIndex,
            'chunkSize': _chunkSize,
          }.jsify(),
        );
    await done;
  }

  @override
  void write(Object? object) {
    add(encoding.encode(object.toString()));
  }

  @override
  void writeAll(Iterable objects, [String separator = '']) {
    add(encoding.encode(objects.join(separator)));
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
    _checkOpen();
    _error ??= (error, stackTrace ?? StackTrace.current);
  }

  @override
  Future addStream(Stream<List<int>> stream) {
    _checkOpen();
    final completer = Completer<void>();
    stream.listen(
      add,
      onError: completer.completeError,
      onDone: completer.complete,
      cancelOnError: true,
    );
    return completer.future;
  }

  /// Waits for the chunks queued so far to be written.
  @override
  Future flush() async {
    // Writes queued while waiting (early data drained once preparation
    // finishes) replace [_pending], so wait until it stops changing.
    Future<void> current;
    do {
      current = _pending;
      await current;
    } while (!identical(current, _pending));
  }

  @override
  Future close() {
    if (_isClosed) return _done.future;
    _isClosed = true;
    // [_pending] starts with the preparation, so by the time this runs every
    // early write has been moved into the buffer or queued.
    _pending
        .then((_) {
          if (_buffer.isNotEmpty && _error == null) {
            _enqueue(_buffer.takeBytes());
          }
          return _pending;
        })
        .then((_) async {
          if (_error == null) {
            try {
              await _putHeader();
            } on Object catch (e, s) {
              _error = (e, s);
            }
          }
          final error = _error;
          if (error == null) {
            _done.complete();
            return;
          }
          try {
            await _file._deleteContents();
          } on Object {
            // Report the write error, not the cleanup's.
          }
          _done.completeError(error.$1, error.$2);
        })
        .catchError((Object e, StackTrace s) {
          if (!_done.isCompleted) _done.completeError(e, s);
        });
    return _done.future;
  }

  @override
  Future get done => _done.future;
}
