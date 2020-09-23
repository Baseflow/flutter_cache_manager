import 'package:file/memory.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_cache_manager/src/config/config.dart';
import 'package:flutter_cache_manager/src/storage/file_system/cache_file.dart';
import 'package:flutter_cache_manager/src/storage/file_system/cache_file_io'
    '.dart' as io_file;
import 'package:flutter_cache_manager/src/storage/file_system/file_system.dart';

import 'mock_cache_info_repository.dart';
import 'mock_file_service.dart';

Config createTestConfig() {
  return Config(
    'test',
    fileSystem: TestFileSystem(),
    repo: MockCacheInfoRepository(),
    fileService: MockFileService(),
  );
}

class TestFileSystem extends FileSystem {
  final directoryFuture =
      MemoryFileSystem().systemTempDirectory.createTemp('test');
  @override
  Future<CacheFile> createFile(String name) async {
    var dir = await directoryFuture;
    return io_file.CacheFile(dir.childFile(name));
  }
}
