import 'package:file/file.dart' as file_pkg;
import 'package:flutter_cache_manager/src/storage/file_system/file_system.dart'
    as cache_fs;
import 'package:flutter_cache_manager/src/storage/file_system/indexed_db_file.dart';

/// A file system implementation that stores files in IndexedDB for web platforms.
class IndexedDbFileSystem implements cache_fs.FileSystem {
  IndexedDbFileSystem(this.databaseName);

  final String databaseName;

  @override
  Future<file_pkg.File> createFile(String name) async {
    return IndexedDbFile(name, databaseName);
  }
}
