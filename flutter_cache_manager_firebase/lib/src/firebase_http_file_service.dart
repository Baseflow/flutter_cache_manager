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
    final ref = await FirebaseStorage.instance.getReferenceFromUrl(url);
    final metaData = await ref.getMetadata();
    final response = http.StreamedResponse(
      ref.getData(metaData.sizeBytes).asStream(),
      200,
      headers: {
        HttpHeaders.contentTypeHeader: metaData.contentType,
        HttpHeaders.cacheControlHeader: metaData.cacheControl,
        HttpHeaders.contentLanguageHeader: metaData.contentLanguage,
        HttpHeaders.dateHeader: metaData.creationTimeMillis.toString(),
        HttpHeaders.contentLocationHeader: metaData.path,
      },
    );

    return HttpGetResponse(response);
  }
}
