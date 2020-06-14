import 'package:clock/clock.dart';
import 'package:flutter_cache_manager/src/storage/cache_object.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const columnId = '_id';
  const columnUrl = 'url';
  const columnKey = 'key';
  const columnPath = 'relativePath';
  const columnETag = 'eTag';
  const columnValidTill = 'validTill';
  const columnTouched = 'touched';

  const validMillis = 1585301160000;
  final validDate = DateTime.utc(2020, 03, 27, 09, 26).toLocal();
  final now = DateTime(2020, 03, 28, 09, 26);

  test('constructor, no explicit key', () {
    final object = CacheObject(
      'baseflow.com/test.png',
      relativePath: 'test.png',
      validTill: validDate,
      eTag: 'test1',
      id: 3,
    );
    expect(object.url, 'baseflow.com/test.png');
    expect(object.key, object.url);
  });

  test('constructor, explicit key', () {
    final object = CacheObject(
      'baseflow.com/test.png',
      key: 'test key 1234',
      relativePath: 'test.png',
      validTill: validDate,
      eTag: 'test1',
      id: 3,
    );
    expect(object.url, 'baseflow.com/test.png');
    expect(object.key, 'test key 1234');
  });

  group('Test CacheObject mapping', () {
    test('Test making CacheObject from map, no explicit key', () {
      var map = {
        columnId: 3,
        columnUrl: 'baseflow.com/test.png',
        columnPath: 'test.png',
        columnETag: 'test1',
        columnValidTill: validMillis,
        columnTouched: now.millisecondsSinceEpoch
      };
      var object = CacheObject.fromMap(map);
      expect(object.id, 3);
      expect(object.url, 'baseflow.com/test.png');
      expect(object.key, object.url);
      expect(object.relativePath, 'test.png');
      expect(object.eTag, 'test1');
      expect(object.validTill, validDate);
    });

    test('Test making CacheObject from map, with explicit key', () {
      var map = {
        columnId: 3,
        columnUrl: 'baseflow.com/test.png',
        columnKey: 'testId1234',
        columnPath: 'test.png',
        columnETag: 'test1',
        columnValidTill: validMillis,
        columnTouched: now.millisecondsSinceEpoch
      };
      var object = CacheObject.fromMap(map);
      expect(object.id, 3);
      expect(object.url, 'baseflow.com/test.png');
      expect(object.key, 'testId1234');
      expect(object.relativePath, 'test.png');
      expect(object.eTag, 'test1');
      expect(object.validTill, validDate);
    });

    test('Test encoding CacheObject to map', () async {
      await withClock(Clock.fixed(now), () async {
        var object = CacheObject(
          'baseflow.com/test.png',
          key: 'testKey1234',
          relativePath: 'test.png',
          validTill: validDate,
          eTag: 'test1',
          id: 3,
        );

        var map = object.toMap();
        expect(map[columnId], 3);
        expect(map[columnUrl], 'baseflow.com/test.png');
        expect(map[columnKey], 'testKey1234');
        expect(map[columnPath], 'test.png');
        expect(map[columnETag], 'test1');
        expect(map[columnValidTill], validMillis);
        expect(map[columnTouched], now.millisecondsSinceEpoch);
      });
    });
  });
}
