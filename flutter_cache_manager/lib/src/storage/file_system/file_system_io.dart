import 'package:file/file.dart' hide FileSystem;
import 'package:file/local.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'file_system.dart';

class IOFileSystem implements FileSystem {
  final Future<Directory> _fileDir;

  IOFileSystem(String key) : _fileDir = createDirectory(key);

  static Future<Directory> createDirectory(String key) async {
    var baseDir = await getTemporaryDirectory();
    var path = p.join(baseDir.path, key);

    var fs = const LocalFileSystem();
    var directory = fs.directory((path));
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<File> createFile(String name) async {
    assert(name != null);
    return (await _fileDir).childFile(name);
  }
}
