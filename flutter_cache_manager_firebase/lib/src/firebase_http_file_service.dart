import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;

/// [FirebaseHttpFileService] is another common file service which parses a
/// firebase reference into, to standard url which can be passed to the
/// standard [HttpFileService].
class FirebaseHttpFileService extends HttpFileService {
  @override
  Future<FileServiceResponse> get(String url,
      {Map<String, String> headers = const {}}) async {
    final ref = await FirebaseStorage.instance.getReferenceFromUrl(url);
    final streamedResponse = http.StreamedResponse(
        ref.getData(0x12FFFFFF).asStream(), 200,
        headers: headers);

    return HttpGetResponse(streamedResponse);
  }
}
