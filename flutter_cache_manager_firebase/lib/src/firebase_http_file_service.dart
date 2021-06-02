import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;

/// [FirebaseHttpFileService] is another common file service which parses a
/// firebase reference into, to standard url which can be passed to the
/// standard [HttpFileService].
class FirebaseHttpFileService extends HttpFileService {
  @override
  Future<FileServiceResponse> get(String url,
      {Map<String, String>? headers}) async {
    final ref = FirebaseStorage.instance.refFromURL(url);
    final metaData = await ref.getMetadata();
    final contentType = metaData.contentType;
    final contentLanguage = metaData.contentLanguage;
    final date = metaData.timeCreated?.millisecondsSinceEpoch;
    final cacheControl = metaData.cacheControl;
    final headers = <String, String>{
      if (contentType != null) HttpHeaders.contentTypeHeader: contentType,
      if (contentLanguage != null)
        HttpHeaders.contentLanguageHeader: contentLanguage,
      if (date != null) HttpHeaders.dateHeader: date.toString(),
      if (cacheControl != null) HttpHeaders.cacheControlHeader: cacheControl,
      HttpHeaders.contentLocationHeader: metaData.fullPath,
    };
    final stream =
        ref.getData(metaData.size ?? 10485760).asStream().where((event) {
      if (event == null) print('null data for url $url');
      return event != null;
    }).cast<Uint8List>();
    final response = http.StreamedResponse(
      stream,
      200,
      headers: headers,
    );

    return HttpGetResponse(response);
  }
}
