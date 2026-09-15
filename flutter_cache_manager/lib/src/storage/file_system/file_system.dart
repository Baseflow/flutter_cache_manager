import 'package:file/file.dart';

export 'file_system_io.dart'
    if (dart.library.js_interop) 'file_system_web.dart';

abstract class FileSystem {
  Future<File> createFile(String name);
}
