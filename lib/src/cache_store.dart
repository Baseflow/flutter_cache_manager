import 'package:flutter_cache_manager/src/file_info.dart';

class CacheStore {
  Future<FileInfo> getFile() async {
    //TODO Stubbed
    //TODO fix locking
    return new FileInfo(null, FileSource.Cache, null);
  }

  putFile(FileInfo fileInfo) {
    //TODO stubbed
  }
}
