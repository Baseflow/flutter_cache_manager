export 'file_system.dart';
export 'file_system_io.dart';
export 'file_system_web.dart';

import 'package:file/file.dart';

/// FileSystem works in the context of a directory where filenames are stored.
abstract class FileSystem {
  Future<File> createFile(String name);

  /// Deletes the directory that contains all the cached filed in the current context.
  Future<void> deleteCacheDir();
}
