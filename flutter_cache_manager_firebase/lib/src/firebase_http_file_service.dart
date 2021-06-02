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
    final contentEncodingHeader = metaData.contentEncoding;
    final contentLanguage = metaData.contentLanguage;
    final date = metaData.timeCreated?.millisecondsSinceEpoch;
    final cacheControl = metaData.cacheControl;
    final contentMD5Header = metaData.md5Hash;

    // TODO: Not sure if the metadata from Firebase should be translated into
    // http headers or if we should just pass through the metadata to the
    // headers. To be safe, we're going with the former.
    final headers = <String, String>{
      if (cacheControl != null) HttpHeaders.cacheControlHeader: cacheControl,
      if (contentEncodingHeader != null)
        HttpHeaders.contentEncodingHeader: contentEncodingHeader,
      if (contentLanguage != null)
        HttpHeaders.contentLanguageHeader: contentLanguage,
      if (contentType != null) HttpHeaders.contentTypeHeader: contentType,
      if (contentMD5Header != null)
        HttpHeaders.contentMD5Header: contentMD5Header,
      HttpHeaders.contentLocationHeader: metaData.fullPath,
      if (date != null) HttpHeaders.dateHeader: date.toString(),
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
