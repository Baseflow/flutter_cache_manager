import 'package:file/file.dart' show File, Directory;
import 'package:file/memory.dart';
import 'package:flutter_cache_manager/src/storage/file_system/file_system.dart';

class MemoryCacheSystem implements FileSystem {
  Future<Directory> _fileDir;

  MemoryCacheSystem() : _fileDir = _createTempDirectory();

  @override
  Future<File> createFile(String name) async {
    Directory directory = await _fileDir;
    if (!(await directory.exists())) {
      // Because _createTempDirectory assigns a new name we need to reassing the future
      _fileDir = _createTempDirectory();
      directory = await _fileDir;
    }

    return directory.childFile(name);
  }

  static Future<Directory> _createTempDirectory() async {
    return MemoryFileSystem().systemTempDirectory.createTemp('cache');
  }

  @override
  Future<void> deleteCacheDir() async {
    final dir = await _fileDir;
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
