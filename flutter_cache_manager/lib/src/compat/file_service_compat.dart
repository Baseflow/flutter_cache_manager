import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_cache_manager/src/web/mime_converter.dart';

class FileServiceCompat extends FileService {
  final FileFetcher fileFetcher;

  FileServiceCompat(this.fileFetcher);

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final legacyResponse = await fileFetcher(url, headers: headers);
    return CompatFileServiceGetResponse(legacyResponse, Uri.parse(url));
  }
}

class CompatFileServiceGetResponse implements FileServiceResponse {
  final FileFetcherResponse legacyResponse;
  final Uri? _uri;
  final DateTime _receivedTime = clock.now();

  CompatFileServiceGetResponse(this.legacyResponse, [this._uri]);

  String? _header(String name) {
    return legacyResponse.header(name);
  }

  @override
  Stream<List<int>> get content => Stream.value(legacyResponse.bodyBytes);

  @override
  int get contentLength => legacyResponse.bodyBytes.length;

  @override
  DateTime get validTill {
    // Without a cache-control header we keep the file for a week
    var ageDuration = const Duration(days: 7);
    final cacheControl = _header(HttpHeaders.cacheControlHeader);
    if (cacheControl != null) {
      final controlSettings = cacheControl.split(',');
      for (final setting in controlSettings) {
        final sanitizedSetting = setting.trim().toLowerCase();
        if (sanitizedSetting == 'no-cache') {
          ageDuration = Duration.zero;
        }
        if (sanitizedSetting.startsWith('max-age=')) {
          final validSeconds =
              int.tryParse(sanitizedSetting.split('=')[1]) ?? 0;
          if (validSeconds > 0) {
            ageDuration = Duration(seconds: validSeconds);
          }
        }
      }
    }

    return _receivedTime.add(ageDuration);
  }

  @override
  String? get eTag => _header(HttpHeaders.etagHeader);

  @override
  String get fileExtension => fileExtensionFromContentTypeOrUri(
    _header(HttpHeaders.contentTypeHeader),
    _uri,
  );

  @override
  int get statusCode => legacyResponse.statusCode as int;
}
