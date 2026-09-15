import 'package:file/file.dart' show File;
import 'package:file/memory.dart';
import 'package:flutter_cache_manager/src/storage/file_system/file_system.dart';

// Web-specific implementations: export on web only, export stubs elsewhere
export 'indexed_db_file_stub.dart'
    if (dart.library.js_interop) 'indexed_db_file.dart';
export 'indexed_db_file_system_stub.dart'
    if (dart.library.js_interop) 'indexed_db_file_system.dart';

class MemoryCacheSystem implements FileSystem {
  final directory = MemoryFileSystem().systemTempDirectory.createTemp('cache');

  @override
  Future<File> createFile(String name) async {
    return (await directory).childFile(name);
  }
}
