import 'dart:async';

import 'package:http/http.dart' as http;

///Flutter Cache Manager
///Copyright (c) 2019 Rene Floor
///Released under MIT License.

typedef Future<FileFetcherResponse> FileFetcher(String url, {Map<String, String> headers});

abstract class FileFetcherResponse {
  int get statusCode;

  bool hasHeader(String name);

  String header(String name);

  Stream<List<int>> get bodyStream;

  List<int> get bodyBytes;
}

abstract class BaseHttpFileFetcherResponse implements FileFetcherResponse {
  final http.BaseResponse _baseResponse;

  const BaseHttpFileFetcherResponse(this._baseResponse);

  @override
  int get statusCode => _baseResponse.statusCode;

  @override
  bool hasHeader(String name) {
    return _baseResponse.headers.containsKey(name);
  }

  @override
  String header(String name) {
    return _baseResponse.headers[name];
  }

  @override
  Stream<List<int>> get bodyStream => null;

  @override
  List<int> get bodyBytes => null;
}

class HttpStreamFileFetcherResponse extends BaseHttpFileFetcherResponse {
  final http.StreamedResponse _response;

  const HttpStreamFileFetcherResponse(this._response): super(_response);

  @override
  Stream<List<int>> get bodyStream => _response.stream;
}

class HttpFileFetcherResponse extends BaseHttpFileFetcherResponse {
  final http.Response _response;

  const HttpFileFetcherResponse(this._response): super(_response);

  @override
  List<int> get bodyBytes => _response.bodyBytes;
}