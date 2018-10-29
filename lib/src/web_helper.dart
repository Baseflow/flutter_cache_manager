import 'package:flutter_cache_manager/src/cache_store.dart';
import 'package:flutter_cache_manager/src/file_info.dart';

class WebHelper {
  CacheStore _store;
  WebHelper(this._store);

  ///Download the file from the url
  Future<FileInfo> downloadFile() async {
    //TODO Stubbed
    //TODO fix locking
    return new FileInfo(null, FileSource.Online, null);
  }
}
