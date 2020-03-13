import 'dart:async';
import 'package:http/http.dart' as http;

///Flutter Cache Manager
///Copyright (c) 2019 Rene Floor
///Released under MIT License.

abstract class FileService {
  Future<FileFetcherResponse> get(String url, {Map<String, String> headers});
}

class HttpFileFetcher implements FileService {
  final http.Client _httpClient = http.Client();

  @override
  Future<FileFetcherResponse> get(String url,
      {Map<String, String> headers}) async {
    final req = http.Request('GET', Uri.parse(url));
    req.headers.addAll(headers);
    final httpResponse = await _httpClient.send(req);

    return HttpFileFetcherResponse(httpResponse);
  }
}

abstract class FileFetcherResponse {
  Stream<List<int>> get content => null;
  int get statusCode;
  DateTime get validTill;
  String get eTag;
  String get fileExtension;
}

class HttpFileFetcherResponse implements FileFetcherResponse {
  HttpFileFetcherResponse(this._response);

  final DateTime _receivedTime = DateTime.now();

  final http.StreamedResponse _response;

  @override
  int get statusCode => _response.statusCode;

  bool _hasHeader(String name) {
    return _response.headers.containsKey(name);
  }

  String _header(String name) {
    return _response.headers[name];
  }

  @override
  Stream<List<int>> get content => _response.stream;

  @override
  DateTime get validTill {
    // Without a cache-control header we keep the file for a week
    var ageDuration = const Duration(days: 7);
    if (_hasHeader('cache-control')) {
      final controlSettings = _header('cache-control').split(',');
      for (final setting in controlSettings) {
        final sanitizedSetting = setting.trim().toLowerCase();
        if (sanitizedSetting == 'no-cache') {
          ageDuration = const Duration();
        }
        if (sanitizedSetting.startsWith('max-age=')) {
          var validSeconds = int.tryParse(sanitizedSetting.split('=')[1]) ?? 0;
          if (validSeconds > 0) {
            ageDuration = Duration(seconds: validSeconds);
          }
        }
      }
    }

    return _receivedTime.add(ageDuration);
  }

  @override
  String get eTag => _hasHeader('etag') ? _header('etag') : null;

  @override
  String get fileExtension {
    var fileExtension = '';
    if (_hasHeader('content-type')) {
      final type = _header('content-type').split('/');
      if (type.length == 2) {
        fileExtension = '.${type[1]}';
      }
    }
    return fileExtension;
  }
}
