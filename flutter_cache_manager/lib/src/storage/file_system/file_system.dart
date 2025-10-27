import 'package:file/file.dart';

export 'file_system.dart';
export 'file_system_io.dart';
export 'file_system_web.dart';
export 'indexed_db_file.dart';
export 'indexed_db_file_system.dart';

abstract class FileSystem {
  Future<File> createFile(String name);
}
