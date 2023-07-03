import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

///Flutter Cache Manager
///Copyright (c) 2019 Rene Floor
///Released under MIT License.

/// Deprecated FileFetcher function
typedef FileFetcher = Future<FileFetcherResponse> Function(String url,
    {Map<String, String>? headers});

abstract class FileFetcherResponse {
  Object get statusCode;

  Uint8List get bodyBytes;

  bool hasHeader(String name);

  String? header(String name);
}

/// Deprecated
class HttpFileFetcherResponse implements FileFetcherResponse {
  final http.Response _response;

  HttpFileFetcherResponse(this._response);

  @override
  bool hasHeader(String name) {
    return _response.headers.containsKey(name);
  }

  @override
  String? header(String name) {
    return _response.headers[name];
  }

  @override
  Uint8List get bodyBytes => _response.bodyBytes;

  @override
  Object get statusCode => _response.statusCode;
}
