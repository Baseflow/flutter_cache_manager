import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_cache_manager/src/compat/file_service_compat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';

import 'helpers/mock_cache_info_repository.dart';
import 'helpers/test_configuration.dart' show TestFileSystem;

void main() {
  group('Check header values', () {
    test('Valid headers should be parsed normally', () async {
      var eTag = 'test';
      var fileExtension = 'jpg';
      var contentType = 'image/jpeg';
      var contentLength = 16;
      var maxAge = const Duration(hours: 2);

      var client = MockClient((request) async {
        return Response.bytes(
          Uint8List(contentLength),
          200,
          headers: {
            'etag': 'test',
            'content-type': contentType,
            'cache-control': 'max-age=${maxAge.inSeconds}',
          },
        );
      });

      await withClock(Clock.fixed(DateTime.now()), () async {
        var httpFileFetcher = HttpFileService(httpClient: client);
        final now = clock.now();
        final response = await httpFileFetcher.get('test.com/image');

        expect(response.contentLength, contentLength);
        expect(response.eTag, eTag);
        expect(response.fileExtension, '.$fileExtension');
        expect(response.validTill, now.add(maxAge));
        expect(response.statusCode, 200);
      });
    });

    test('Weird contenttype should still parse', () async {
      var fileExtension = 'cov';
      var contentType = 'unknown/$fileExtension';

      var client = MockClient((request) async {
        return Response.bytes(
          Uint8List(16),
          200,
          headers: {'content-type': contentType},
        );
      });

      var httpFileFetcher = HttpFileService(httpClient: client);
      final response = await httpFileFetcher.get('test.com/image');

      expect(response.fileExtension, '.$fileExtension');
    });

    test('Content-Type parameters should be ignored', () async {
      var fileExtension = 'mp3';
      var contentType = 'audio/mpeg;chartset=UTF-8';

      var client = MockClient((request) async {
        return Response.bytes(
          Uint8List(16),
          200,
          headers: {'content-type': contentType},
        );
      });

      var httpFileFetcher = HttpFileService(httpClient: client);
      final response = await httpFileFetcher.get('test.com/document');

      expect(response.fileExtension, '.$fileExtension');
    });

    test('HttpGetResponse keeps its original one-argument constructor', () {
      final response = HttpGetResponse(
        StreamedResponse(
          const Stream<List<int>>.empty(),
          200,
          headers: {'content-type': 'application/octet-stream'},
          request: Request('GET', Uri.parse('https://example.com/video.mp4')),
        ),
      );

      expect(response.fileExtension, '.mp4');
    });

    test('Download uses the URL extension for generic content type', () async {
      const url = 'https://example.com/video.mp4?token=secret';
      final client = MockClient((_) async {
        return Response.bytes(
          Uint8List(16),
          200,
          headers: {'content-type': 'application/octet-stream'},
        );
      });
      final cacheManager = CacheManager(
        Config(
          'test',
          fileSystem: TestFileSystem(),
          repo: MockCacheInfoRepository(),
          fileService: HttpFileService(httpClient: client),
        ),
      );

      final result = await cacheManager.downloadFile(url);

      expect(result.file.path, endsWith('.mp4'));
    });

    test('URL extension is used when content type is missing', () async {
      final client = MockClient((_) async {
        return Response.bytes(Uint8List(16), 200);
      });

      final response = await HttpFileService(
        httpClient: client,
      ).get('https://example.com/document.pdf?download=1');

      expect(response.fileExtension, '.pdf');
    });

    test('Specific content type takes precedence over URL extension', () async {
      final client = MockClient((_) async {
        return Response.bytes(
          Uint8List(16),
          200,
          headers: {'content-type': 'image/jpeg'},
        );
      });

      final response = await HttpFileService(
        httpClient: client,
      ).get('https://example.com/video.mp4');

      expect(response.fileExtension, '.jpg');
    });

    test(
      'Legacy file service uses URL extension for generic content type',
      () async {
        final client = MockClient((_) async {
          return Response.bytes(
            Uint8List(16),
            200,
            headers: {'content-type': 'application/octet-stream'},
          );
        });

        Future<FileFetcherResponse> defaultHttpGetter(
          String url, {
          Map<String, String>? headers,
        }) async {
          final httpResponse = await client.get(
            Uri.parse(url),
            headers: headers,
          );
          return HttpFileFetcherResponse(httpResponse);
        }

        final response = await FileServiceCompat(
          defaultHttpGetter,
        ).get('https://example.com/video.mp4');

        expect(response.fileExtension, '.mp4');
      },
    );

    test('Generic content type without URL extension remains .bin', () async {
      final client = MockClient((_) async {
        return Response.bytes(
          Uint8List(16),
          200,
          headers: {'content-type': 'application/octet-stream'},
        );
      });

      final response = await HttpFileService(
        httpClient: client,
      ).get('https://example.com/download');

      expect(response.fileExtension, '.bin');
    });

    test(
      'Encoded path separators are not used in cached file extensions',
      () async {
        const url = 'https://example.com/video.mp4%2Fpart';
        final client = MockClient((_) async {
          return Response.bytes(
            Uint8List(16),
            200,
            headers: {'content-type': 'application/octet-stream'},
          );
        });
        final cacheManager = CacheManager(
          Config(
            'test',
            fileSystem: TestFileSystem(),
            repo: MockCacheInfoRepository(),
            fileService: HttpFileService(httpClient: client),
          ),
        );

        final result = await cacheManager.downloadFile(url);

        expect(result.file.path, endsWith('.bin'));
      },
    );

    test('Test CompatFileService', () async {
      var eTag = 'test';
      var fileExtension = 'jpg';
      var contentType = 'image/jpeg';
      var contentLength = 16;
      var maxAge = const Duration(hours: 2);

      var client = MockClient((request) async {
        return Response.bytes(
          Uint8List(contentLength),
          200,
          headers: {
            'etag': 'test',
            'content-type': contentType,
            'cache-control': 'max-age=${maxAge.inSeconds}',
          },
        );
      });

      Future<FileFetcherResponse> defaultHttpGetter(
        String url, {
        Map<String, String>? headers,
      }) async {
        var httpResponse = await client.get(Uri.parse(url), headers: headers);
        return HttpFileFetcherResponse(httpResponse);
      }

      await withClock(Clock.fixed(DateTime.now()), () async {
        var httpFileFetcher = FileServiceCompat(defaultHttpGetter);
        final now = clock.now();
        final response = await httpFileFetcher.get('http://test.com/image');

        expect(response.contentLength, contentLength);
        expect(response.eTag, eTag);
        expect(response.fileExtension, '.$fileExtension');
        expect(response.validTill, now.add(maxAge));
        expect(response.statusCode, 200);
      });
    });
  });
}
