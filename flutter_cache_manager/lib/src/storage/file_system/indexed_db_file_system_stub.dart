import 'package:file/file.dart' as file_pkg;
import 'package:flutter_cache_manager/src/storage/file_system/file_system.dart'
    as cache_fs;

/// Non-web stand-in for the IndexedDB file system, so the class can be
/// named in platform-independent code. Creating files throws.
class IndexedDbFileSystem implements cache_fs.FileSystem {
  IndexedDbFileSystem(this.databaseName);

  final String databaseName;

  @override
  Future<file_pkg.File> createFile(String name) async {
    throw UnsupportedError('IndexedDbFileSystem is only available on web');
  }
}
