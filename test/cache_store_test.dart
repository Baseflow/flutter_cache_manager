import 'dart:async';
import 'dart:io';

import 'package:flutter_cache_manager/src/cache_object.dart';
import 'package:flutter_cache_manager/src/cache_store.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'mock_cache_object_provider.dart';
void main() {
  group('Test cache store', () {
    var basePath = Directory.systemTemp.createTempSync("test");
    var store = CacheStore(
      Future.value(basePath.path),
      getMockProvider(),
      10,
      const Duration(seconds: 30),
    );
    tearDown(() async {
      await store.emptyCache();
    });
    test("get and put", () async {
      var testFile = File(p.join(basePath.path, '1.png'));
      testFile.createSync();
      await store.putFile(
        CacheObject("http://test/1.png", relativePath: "1.png"),
      );
      expect(await store.getFile("http://test/1.png"),
          (object) => object.file != null,
          reason: "should found");
    });
    test("get invalid cache", () async {
      expect(
        await store.getFile("http://test/2.png"),
        null,
        reason: "should not found",
      );
      await store.putFile(
        CacheObject("http://test/2.png"),
      );
      expect(await store.getFile("http://test/2.png"), null,
          reason: "should not found");
    });
    test("remove", () async {
      var testFile = File(p.join(basePath.path, '3.png'));
      testFile.createSync();
      await store.putFile(
        CacheObject("http://test/3.png", relativePath: "3.png"),
      );
      var object = await store.retrieveCacheData("http://test/3.png");
      expect(object, (object) => object.id != null);
      await store.removeCachedFile(object);
      expect(await store.retrieveCacheData("http://test/3.png"), null);
      await Future.delayed(Duration(milliseconds: 200));
      expect(testFile.existsSync(), false);
    });
  });
}

Future<CacheObjectProvider> getMockProvider() async {
  return MockCacheObjectProvider();
}