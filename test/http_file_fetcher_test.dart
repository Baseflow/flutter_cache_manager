import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';

void main() {
  group('Check header values', () {
    test('Valid headers should be parsed normally', () async {
      var eTag = 'test';
      var fileExtension = 'jpeg';
      var contentType = 'image/$fileExtension';
      var maxAge = const Duration(hours: 2);

      var client = MockClient((request) async {
        return Response.bytes(Uint8List(16), 200,
            headers: {
              'etag': 'test',
              'content-type': contentType,
              'cache-control': 'max-age=${maxAge.inSeconds}'
        });
      });

      await withClock(Clock.fixed(DateTime.now()),() async {
        var httpFileFetcher = HttpFileFetcher(httpClient: client);
        final now = clock.now();
        final response = await httpFileFetcher.get('test.com/image');

        expect(response.eTag, eTag);
        expect(response.fileExtension, '.$fileExtension');
        expect(response.validTill, now.add(maxAge));
      });
    });
  });
}
