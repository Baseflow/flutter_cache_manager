import 'dart:convert';
import 'dart:typed_data';

import 'package:file/file.dart';

// Non-web stub to satisfy conditional export when js_interop is unavailable
class IndexedDbFile implements File {
  IndexedDbFile(String path, String dbName);

  @override
  File get absolute => this;

  @override
  Future<File> copy(String newPath) => _unsupported();

  @override
  File copySync(String newPath) => _throw();

  @override
  Future<File> create({bool recursive = false, bool exclusive = false}) =>
      _unsupported();

  @override
  void createSync({bool recursive = false, bool exclusive = false}) => _throw();

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) => _unsupported();

  @override
  void deleteSync({bool recursive = false}) => _throw();

  @override
  bool existsSync() => _throw();

  @override
  Future<bool> exists() => _unsupported();

  @override
  bool get isAbsolute => true;

  @override
  RandomAccessFile openSync({FileMode mode = FileMode.read}) => _throw();

  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) =>
      _unsupported();

  @override
  Stream<List<int>> openRead([int? start, int? end]) =>
      Stream<List<int>>.error(_unsupportedError());

  @override
  IOSink openWrite({
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
  }) => _throw();

  @override
  Directory get parent => _throw();

  @override
  String get path => _throw();

  @override
  Future<int> length() => _unsupported();

  @override
  int lengthSync() => _throw();

  @override
  Future<Uint8List> readAsBytes() => _unsupported();

  @override
  Uint8List readAsBytesSync() => _throw();

  @override
  Future<String> readAsString({Encoding encoding = utf8}) => _unsupported();

  @override
  String readAsStringSync({Encoding encoding = utf8}) => _throw();

  @override
  Future<List<String>> readAsLines({Encoding encoding = utf8}) =>
      _unsupported();

  @override
  List<String> readAsLinesSync({Encoding encoding = utf8}) => _throw();

  @override
  Future<File> rename(String newPath) => _unsupported();

  @override
  File renameSync(String newPath) => _throw();

  @override
  Future<String> resolveSymbolicLinks() => _unsupported();

  @override
  String resolveSymbolicLinksSync() => _throw();

  @override
  Future<DateTime> lastAccessed() => _unsupported();

  @override
  DateTime lastAccessedSync() => _throw();

  @override
  Future<DateTime> lastModified() => _unsupported();

  @override
  DateTime lastModifiedSync() => _throw();

  @override
  FileStat statSync() => _throw();

  @override
  Future<FileStat> stat() => _unsupported();

  @override
  Uri get uri => _throw();

  @override
  String get basename => _throw();

  @override
  String get dirname => _throw();

  @override
  Stream<FileSystemEvent> watch({
    int events = FileSystemEvent.all,
    bool recursive = false,
  }) => Stream<FileSystemEvent>.error(_unsupportedError());

  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) => _unsupported();

  @override
  void writeAsBytesSync(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) => _throw();

  @override
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) => _unsupported();

  @override
  void writeAsStringSync(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) => _throw();

  @override
  void setLastAccessedSync(DateTime time) => _throw();

  @override
  Future<File> setLastAccessed(DateTime time) => _unsupported();

  @override
  void setLastModifiedSync(DateTime time) => _throw();

  @override
  Future<File> setLastModified(DateTime time) => _unsupported();

  T _throw<T>() => throw _unsupportedError();
  Future<T> _unsupported<T>() => Future<T>.error(_unsupportedError());
  UnsupportedError _unsupportedError() =>
      UnsupportedError('IndexedDbFile is only available on web');

  @override
  FileSystem get fileSystem => _throw();
}
