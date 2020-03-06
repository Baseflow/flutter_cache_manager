import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter_cache_manager/src/cache_store.dart';
import 'package:flutter_cache_manager/src/storage/cache_info_repository.dart';
import 'package:flutter_cache_manager/src/storage/cache_object.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  group('Retrieving files from store', () {
    test('Store should return null when file not cached', () async {
      var repo = MockRepo();
      when(repo.get(any)).thenAnswer((_) => Future.value(null));

      var store = CacheStore(createDir(), 'test', 30, const Duration(days: 7),
          cacheRepoProvider: Future.value(repo));

      expect(await store.getFile('This is a test'), null);
    });

    test('Store should return FileInfo when file is cached', () async {
      var repo = MockRepo();

      var tempDir = createDir();
      await (await tempDir).childFile('testimage.png').create();

      when(repo.get('baseflow.com/test.png')).thenAnswer((_) => Future.value(
          CacheObject('baseflow.com/test.png', relativePath: 'testimage.png')));

      var store = CacheStore(tempDir, 'test', 30, const Duration(days: 7),
          cacheRepoProvider: Future.value(repo));

      expect(await store.getFile('baseflow.com/test.png'), isNotNull);
    });

    test('Store should return null when file is no longer cached', () async {
      var repo = MockRepo();

      var tempDir = createDir();

      when(repo.get('baseflow.com/test.png')).thenAnswer((_) => Future.value(
          CacheObject('baseflow.com/test.png', relativePath: 'testimage.png')));

      var store = CacheStore(tempDir, 'test', 30, const Duration(days: 7),
          cacheRepoProvider: Future.value(repo));

      expect(await store.getFile('baseflow.com/test.png'), null);
    });

    test('Store should return no CacheInfo when file not cached', () async {
      var repo = MockRepo();
      when(repo.get(any)).thenAnswer((_) => Future.value(null));

      var store = CacheStore(createDir(), 'test', 30, const Duration(days: 7),
          cacheRepoProvider: Future.value(repo));

      expect(await store.retrieveCacheData('This is a test'), null);
    });

    test('Store should return CacheInfo when file is cached', () async {
      var repo = MockRepo();

      var tempDir = createDir();
      await (await tempDir).childFile('testimage.png').create();

      when(repo.get('baseflow.com/test.png')).thenAnswer((_) => Future.value(
          CacheObject('baseflow.com/test.png', relativePath: 'testimage.png')));

      var store = CacheStore(tempDir, 'test', 30, const Duration(days: 7),
          cacheRepoProvider: Future.value(repo));

      expect(await store.retrieveCacheData('baseflow.com/test.png'), isNotNull);
    });

    test(
        'Store should return File from memcache only when file is retrieved before',
        () async {
      var repo = MockRepo();

      var tempDir = createDir();
      await (await tempDir).childFile('testimage.png').create();

      when(repo.get('baseflow.com/test.png')).thenAnswer((_) => Future.value(
          CacheObject('baseflow.com/test.png', relativePath: 'testimage.png')));

      var store = CacheStore(tempDir, 'test', 30, const Duration(days: 7),
          cacheRepoProvider: Future.value(repo));

      expect(store.getFileFromMemory('baseflow.com/test.png'), null);
      await store.getFile('baseflow.com/test.png');
      expect(store.getFileFromMemory('baseflow.com/test.png'), isNotNull);
    });
  });
}

Future<Directory> createDir() async {
  final fileSystem = MemoryFileSystem();
  return fileSystem.systemTempDirectory.createTemp('test');
}

class MockRepo extends Mock implements CacheInfoRepository {}
