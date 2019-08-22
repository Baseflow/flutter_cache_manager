import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

///Flutter Cache Manager
///Copyright (c) 2019 Rene Floor
///Released under MIT License.

typedef Future<FileFetcherResponse> FileFetcher(String url,
    {Map<String, String> headers});

abstract class FileFetcherResponse {
  get statusCode;

  Uint8List get bodyBytes => null;

  bool hasHeader(String name);
  String header(String name);

  /// return the maxAge the response might be cached.
  /// By default returns the max-age of cache-control header.
  Duration get maxAge {
    if (hasHeader("cache-control")) {
      var cacheControl = header("cache-control");
      var controlSettings = cacheControl.split(", ");
      final setting = controlSettings.firstWhere((setting) => setting.contains('max-age'), orElse: () => null);
      if (setting != null) {
        final validSeconds = int.tryParse(setting.split("=")[1]) ?? 0;
        if (validSeconds > 0) {
          return new Duration(seconds: validSeconds);
        }
      }
    }
    return null;
  }
}

class HttpFileFetcherResponse extends FileFetcherResponse {
  http.Response _response;

  HttpFileFetcherResponse(this._response);

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

  @override
  get statusCode => _response.statusCode;
}
