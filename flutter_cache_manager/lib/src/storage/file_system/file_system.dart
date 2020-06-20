import 'package:flutter_cache_manager/src/storage/file_system/cache_file.dart';

abstract class FileSystem {
    Future<CacheFile> createFile(String name);
}