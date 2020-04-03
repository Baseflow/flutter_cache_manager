import 'dart:typed_data';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_cache_manager/src/cache_store.dart';
import 'package:flutter_cache_manager/src/storage/cache_object.dart';
import 'package:flutter_cache_manager/src/web/web_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  group('Tests for getSingleFile', () {
    test('Valid cacheFile should not call to web', () async {
      var fileName = 'test.jpg';
      var fileUrl = 'baseflow.com/test';
      var validTill = DateTime.now().add(const Duration(days: 1));

      var store = MockStore();
      when(store.fileDir).thenAnswer((_) => Future.value(
          MemoryFileSystem().systemTempDirectory.createTemp('test')));
      var file = (await store.fileDir).childFile(fileName);
      var fileInfo = FileInfo(file, FileSource.Cache, validTill, fileUrl);
      when(store.getFile(fileUrl)).thenAnswer((_) => Future.value(fileInfo));

      var webHelper = MockWebHelper();
      var cacheManager = TestCacheManager(store, webHelper);

      var result = await cacheManager.getSingleFile(fileUrl);
      expect(result, isNotNull);
      verifyNever(webHelper.downloadFile(any));
    });

    test('Outdated cacheFile should call to web', () async {
      var fileName = 'test.jpg';
      var fileUrl = 'baseflow.com/test';
      var validTill = DateTime.now().subtract(const Duration(days: 1));

      var store = MockStore();
      when(store.fileDir).thenAnswer((_) => Future.value(
          MemoryFileSystem().systemTempDirectory.createTemp('test')));
      var file = (await store.fileDir).childFile(fileName);
      var fileInfo = FileInfo(file, FileSource.Cache, validTill, fileUrl);
      when(store.getFile(fileUrl)).thenAnswer((_) => Future.value(fileInfo));

      var webHelper = MockWebHelper();
      when(webHelper.downloadFile(argThat(anything)))
          .thenAnswer((i) => Stream.value(FileInfo(
                null,
                FileSource.Online,
                DateTime.now().add(const Duration(days: 7)),
                i.positionalArguments.first as String,
              )));
      var cacheManager = TestCacheManager(store, webHelper);

      var result = await cacheManager.getSingleFile(fileUrl);
      expect(result, isNotNull);
      verify(webHelper.downloadFile(any)).called(1);
    });

    test('Non-existing cacheFile should call to web', () async {
      var fileName = 'test.jpg';
      var fileUrl = 'baseflow.com/test';
      var validTill = DateTime.now().subtract(const Duration(days: 1));

      var store = MockStore();
      when(store.fileDir).thenAnswer((_) => Future.value(
          MemoryFileSystem().systemTempDirectory.createTemp('test')));
      var file = (await store.fileDir).childFile(fileName);
      var fileInfo = FileInfo(file, FileSource.Cache, validTill, fileUrl);

      when(store.getFile(fileUrl)).thenAnswer((_) => Future.value(null));

      var webHelper = MockWebHelper();
      when(webHelper.downloadFile(fileUrl))
          .thenAnswer((_) => Stream.value(fileInfo));

      var cacheManager = TestCacheManager(store, webHelper);

      var result = await cacheManager.getSingleFile(fileUrl);
      expect(result, isNotNull);
      verify(webHelper.downloadFile(any)).called(1);
    });
  });

  group('Tests for getFile', () {
    test('Valid cacheFile should not call to web', () async {
      var fileName = 'test.jpg';
      var fileUrl = 'baseflow.com/test';
      var validTill = DateTime.now().add(const Duration(days: 1));

      var store = MockStore();
      when(store.fileDir).thenAnswer((_) => Future.value(
          MemoryFileSystem().systemTempDirectory.createTemp('test')));
      var file = (await store.fileDir).childFile(fileName);
      var fileInfo = FileInfo(file, FileSource.Cache, validTill, fileUrl);
      when(store.getFile(fileUrl)).thenAnswer((_) => Future.value(fileInfo));

      var webHelper = MockWebHelper();
      var cacheManager = TestCacheManager(store, webHelper);

      var fileStream = cacheManager.getFile(fileUrl);
      expect(fileStream, emits(fileInfo));
      verifyNever(webHelper.downloadFile(any));
    });

    test('Outdated cacheFile should call to web', () async {
      var fileName = 'test.jpg';
      var fileUrl = 'baseflow.com/test';
      var validTill = DateTime.now().subtract(const Duration(days: 1));

      var store = MockStore();
      when(store.fileDir).thenAnswer((_) => Future.value(
          MemoryFileSystem().systemTempDirectory.createTemp('test')));

      var file = (await store.fileDir).childFile(fileName);
      var cachedInfo = FileInfo(file, FileSource.Cache, validTill, fileUrl);
      when(store.getFile(fileUrl)).thenAnswer((_) => Future.value(cachedInfo));

      var webHelper = MockWebHelper();
      var downloadedInfo = FileInfo(file, FileSource.Online,
          DateTime.now().add(const Duration(days: 1)), fileUrl);
      when(webHelper.downloadFile(fileUrl))
          .thenAnswer((_) => Stream.value(downloadedInfo));

      var cacheManager = TestCacheManager(store, webHelper);
      var fileStream = cacheManager.getFile(fileUrl);
      await expectLater(fileStream, emitsInOrder([cachedInfo, downloadedInfo]));

      verify(webHelper.downloadFile(any)).called(1);
    });

    test('Non-existing cacheFile should call to web', () async {
      var fileName = 'test.jpg';
      var fileUrl = 'baseflow.com/test';
      var validTill = DateTime.now().subtract(const Duration(days: 1));

      var store = MockStore();
      when(store.fileDir).thenAnswer((_) => Future.value(
          MemoryFileSystem().systemTempDirectory.createTemp('test')));
      var file = (await store.fileDir).childFile(fileName);
      var fileInfo = FileInfo(file, FileSource.Cache, validTill, fileUrl);

      when(store.getFile(fileUrl)).thenAnswer((_) => Future.value(null));

      var webHelper = MockWebHelper();
      when(webHelper.downloadFile(fileUrl))
          .thenAnswer((_) => Stream.value(fileInfo));

      var cacheManager = TestCacheManager(store, webHelper);

      var fileStream = cacheManager.getFile(fileUrl);
      await expectLater(fileStream, emitsInOrder([fileInfo]));
      verify(webHelper.downloadFile(any)).called(1);
    });

    test('Errors should be passed to the stream', () async {
      var fileUrl = 'baseflow.com/test';

      var store = MockStore();
      when(store.getFile(fileUrl)).thenAnswer((_) => Future.value(null));

      var webHelper = MockWebHelper();
      var error = HttpExceptionWithStatus(404, 'Invalid statusCode: 404',
          uri: Uri.parse(fileUrl));
      when(webHelper.downloadFile(fileUrl)).thenThrow(error);

      var cacheManager = TestCacheManager(store, webHelper);

      var fileStream = cacheManager.getFile(fileUrl);
      await expectLater(fileStream, emitsError(error));
      verify(webHelper.downloadFile(any)).called(1);
    });
  });

  group('Testing puting files in cache', () {
    test('Check if file is written and info is stored', () async {
      var fileUrl = 'baseflow.com/test';
      var fileBytes = Uint8List(16);
      var extension = '.jpg';

      var store = MockStore();
      when(store.fileDir).thenAnswer((_) => Future.value(
          MemoryFileSystem().systemTempDirectory.createTemp('test')));

      var webHelper = MockWebHelper();
      var cacheManager = TestCacheManager(store, webHelper);

      var file = await cacheManager.putFile(fileUrl, fileBytes,
          fileExtension: extension);
      expect(await file.exists(), true);
      expect(await file.readAsBytes(), fileBytes);
      verify(store.putFile(any)).called(1);
    });
  });

  group('Testing remove files from cache', () {
    test('Remove existing file from cache', () async {
      var fileUrl = 'baseflow.com/test';

      var store = MockStore();
      when(store.retrieveCacheData(fileUrl))
          .thenAnswer((_) => Future.value(CacheObject(fileUrl)));

      var webHelper = MockWebHelper();
      var cacheManager = TestCacheManager(store, webHelper);

      await cacheManager.removeFile(fileUrl);
      verify(store.removeCachedFile(any)).called(1);
    });

    test("Don't remove files not in cache", () async {
      var fileUrl = 'baseflow.com/test';

      var store = MockStore();
      when(store.retrieveCacheData(fileUrl)).thenAnswer((_) => null);

      var webHelper = MockWebHelper();
      var cacheManager = TestCacheManager(store, webHelper);

      await cacheManager.removeFile(fileUrl);
      verifyNever(store.removeCachedFile(any));
    });
  });

  test('Download file just downloads file', () async {
    var fileUrl = 'baseflow.com/test';
    var fileInfo = FileInfo(null, FileSource.Cache, DateTime.now(), fileUrl);
    var store = MockStore();
    var webHelper = MockWebHelper();
    when(webHelper.downloadFile(fileUrl))
        .thenAnswer((_) => Stream.value(fileInfo));
    var cacheManager = TestCacheManager(store, webHelper);
    expect(await cacheManager.downloadFile(fileUrl), fileInfo);
  });

  test('test file from memory', () {
    var fileUrl = 'baseflow.com/test';
    var fileInfo = FileInfo(null, FileSource.Cache, DateTime.now(), fileUrl);

    var store = MockStore();
    when(store.getFileFromMemory(fileUrl)).thenAnswer((_) => fileInfo);

    var webHelper = MockWebHelper();
    var cacheManager = TestCacheManager(store, webHelper);
    expect(cacheManager.getFileFromMemory(fileUrl), fileInfo);
  });

  test('Empty cache empties cache in store', () async {
    var store = MockStore();
    var webHelper = MockWebHelper();
    var cacheManager = TestCacheManager(store, webHelper);
    await cacheManager.emptyCache();
    verify(store.emptyCache()).called(1);
  });
}

class TestCacheManager extends BaseCacheManager {
  TestCacheManager(CacheStore store, WebHelper webHelper)
      : super('test', cacheStore: store, webHelper: webHelper);

  @override
  Future<String> getFilePath() {
    //Not needed because we supply our own store
    throw UnimplementedError();
  }
}

class MockStore extends Mock implements CacheStore {}

class MockWebHelper extends Mock implements WebHelper {}
