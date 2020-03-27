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
      verifyNever(webHelper.downloadFile(argThat(anything),
          authHeaders: anyNamed('authHeaders')));
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
      var cacheManager = TestCacheManager(store, webHelper);

      var result = await cacheManager.getSingleFile(fileUrl);
      expect(result, isNotNull);
      verify(webHelper.downloadFile(argThat(anything),
              authHeaders: anyNamed('authHeaders')))
          .called(1);
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
      when(webHelper.downloadFile(fileUrl,
              authHeaders: anyNamed('authHeaders')))
          .thenAnswer((_) => Future.value(fileInfo));

      var cacheManager = TestCacheManager(store, webHelper);

      var result = await cacheManager.getSingleFile(fileUrl);
      expect(result, isNotNull);
      verify(webHelper.downloadFile(argThat(anything),
              authHeaders: anyNamed('authHeaders')))
          .called(1);
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
      verifyNever(webHelper.downloadFile(argThat(anything),
          authHeaders: anyNamed('authHeaders')));
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
      var downloadedInfo = FileInfo(file, FileSource.Online, DateTime.now().add(const Duration(days: 1)), fileUrl);
      when(webHelper.downloadFile(fileUrl)).thenAnswer((_) => Future.value(downloadedInfo));

      var cacheManager = TestCacheManager(store, webHelper);
      var fileStream = cacheManager.getFile(fileUrl);
      await expectLater(fileStream, emitsInOrder([cachedInfo, downloadedInfo]));

      verify(webHelper.downloadFile(argThat(anything),
          authHeaders: anyNamed('authHeaders'))).called(1);
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
      when(webHelper.downloadFile(fileUrl,
          authHeaders: anyNamed('authHeaders')))
          .thenAnswer((_) => Future.value(fileInfo));

      var cacheManager = TestCacheManager(store, webHelper);

      var fileStream = cacheManager.getFile(fileUrl);
      await expectLater(fileStream, emitsInOrder([fileInfo]));
      verify(webHelper.downloadFile(argThat(anything),
          authHeaders: anyNamed('authHeaders')))
          .called(1);
    });
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
