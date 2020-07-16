import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'cache_file.dart' as def;

class CacheFile implements def.CacheFile {
  File _file;

  CacheFile(File file){
    _file = file;
  }

  @override
  Future<bool> exists() {
    return _file.exists();
  }

  @override
  Future<void> delete() {
    return _file.delete();
  }

  @override
  Future<void> createParent() async {
    final folder = _file.parent;
    if (!(await folder.exists())) {
      folder.createSync(recursive: true);
    }
  }

  @override
  StreamSink<List<int>> openWrite() {
    return _file.openWrite();
  }

  @override
  Future writeAsBytes(Uint8List bytes) {
    return _file.writeAsBytes(bytes);
  }

  @override
  Future<Uint8List> readAsBytes() {
    return _file.readAsBytes();
  }

  @override
  String get path => _file.path;
}