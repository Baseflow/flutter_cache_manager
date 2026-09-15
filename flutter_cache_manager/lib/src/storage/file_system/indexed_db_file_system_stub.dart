import 'package:file/file.dart' as file_pkg;
import 'package:flutter_cache_manager/src/storage/file_system/file_system.dart'
    as cache_fs;

// Non-web stub to satisfy conditional export when js_interop is unavailable
class IndexedDbFileSystem implements cache_fs.FileSystem {
  IndexedDbFileSystem(String databaseName);

  @override
  Future<file_pkg.File> createFile(String name) async {
    throw UnsupportedError('IndexedDbFileSystem is only available on web');
  }
}
