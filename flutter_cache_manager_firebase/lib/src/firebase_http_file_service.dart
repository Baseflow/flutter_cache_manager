import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// [FirebaseHttpFileService] is another common file service which parses a
/// firebase reference into, to standard url which can be passed to the
/// standard [HttpFileService].
class FirebaseHttpFileService extends HttpFileService {
  @override
  Future<FileServiceResponse> get(String url,
      {Map<String, String>? headers}) async {
    var ref = FirebaseStorage.instance.ref().child(url);
    var _url = await ref.getDownloadURL();

    return super.get(_url);
  }
}
