import 'package:file/memory.dart';
import 'package:flutter_cache_manager/src/storage/file_system/cache_file_web.dart';
import 'package:flutter_cache_manager/src/storage/file_system/file_system.dart';

class MemoryCacheSystem implements FileSystem {
  final directory = MemoryFileSystem().systemTempDirectory.createTemp('cache');

  @override
  Future<CacheFile> createFile(String name) async {
    var file = (await directory).childFile(name);
    return CacheFile(file);
  }
}