import 'dart:io';

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
    final ref = FirebaseStorage.instance.refFromURL(url);
    final metaData = await ref.getMetadata();
    final headers = {
      HttpHeaders.contentTypeHeader: metaData.contentType,
      HttpHeaders.contentLanguageHeader: metaData.contentLanguage,
      HttpHeaders.dateHeader:
          metaData.timeCreated.millisecondsSinceEpoch.toString(),
      HttpHeaders.contentLocationHeader: metaData.fullPath,
    };
    if (metaData.cacheControl != null) {
      headers[HttpHeaders.cacheControlHeader] = metaData.cacheControl;
    }
    final response = http.StreamedResponse(
      ref.getData(metaData.size).asStream(),
      200,
      headers: headers,
    );

    return HttpGetResponse(response);
  }
}
