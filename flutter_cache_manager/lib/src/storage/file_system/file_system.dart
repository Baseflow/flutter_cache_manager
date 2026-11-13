export 'file_system.dart';
export 'file_system_io.dart';
export 'file_system_web.dart';
export 'indexed_db_file_system_stub.dart'
    if (dart.library.js_interop) 'indexed_db_file_system.dart';

import 'package:file/file.dart';

abstract class FileSystem {
  Future<File> createFile(String name);
}
