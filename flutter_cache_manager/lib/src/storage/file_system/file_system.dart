export 'file_system.dart';
export 'file_system_io.dart';
export 'file_system_web.dart';

import 'package:file/file.dart';

abstract class FileSystem {
  Future<File> createFile(String name);
}
