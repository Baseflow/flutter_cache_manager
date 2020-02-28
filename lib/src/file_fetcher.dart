import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

///Flutter Cache Manager
///Copyright (c) 2019 Rene Floor
///Released under MIT License.

typedef Future<FileFetcherResponse> FileFetcher(String url, {Map<String, String> headers});

abstract class FileFetcherResponse {
  int get statusCode;

  bool hasHeader(String name);

  String header(String name);

  Uint8List get bodyBytes => null;
}

class HttpFileFetcherResponse implements FileFetcherResponse {
  const HttpFileFetcherResponse(this._response);

  final http.Response _response;

  @override
  int get statusCode => _response.statusCode;

  @override
  bool hasHeader(String name) {
    return _response.headers.containsKey(name);
  }

  @override
  String header(String name) {
    return _response.headers[name];
  }

  @override
  Uint8List get bodyBytes => _response.bodyBytes;
}
