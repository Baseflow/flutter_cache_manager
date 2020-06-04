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

    test('Store should return CacheInfo from memory when asked twice',
        () async {
      var repo = MockRepo();

      var tempDir = createDir();
      await (await tempDir).childFile('testimage.png').create();

      when(repo.get('baseflow.com/test.png')).thenAnswer((_) => Future.value(
          CacheObject('baseflow.com/test.png', relativePath: 'testimage.png')));

      var store = CacheStore(tempDir, 'test', 30, const Duration(days: 7),
          cacheRepoProvider: Future.value(repo));

      var result = await store.retrieveCacheData('baseflow.com/test.png');
      expect(result, isNotNull);
      var _ = await store.retrieveCacheData('baseflow.com/test.png');
      verify(repo.get(any)).called(1);
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

  group('Storing files in store', () {
    test('Store should store fileinfo in repo', () async {
      var repo = MockRepo();

      var tempDir = createDir();

      var store = CacheStore(tempDir, 'test', 30, const Duration(days: 7),
          cacheRepoProvider: Future.value(repo));

      var cacheObject =
          CacheObject('baseflow.com/test.png', relativePath: 'testimage.png');
      await store.putFile(cacheObject);

      verify(repo.updateOrInsert(cacheObject)).called(1);
    });
  });

  group('Removing files in store', () {
    test('Store should remove fileinfo from repo on delete', () async {
      var repo = MockRepo();

      var tempDir = createDir();

      var store = CacheStore(tempDir, 'test', 30, const Duration(days: 7),
          cacheRepoProvider: Future.value(repo));

      var cacheObject = CacheObject('baseflow.com/test.png',
          relativePath: 'testimage.png', id: 1);
      await store.removeCachedFile(cacheObject);

      verify(repo.deleteAll(argThat(contains(cacheObject.id)))).called(1);
    });

    test('Store should remove file over capacity', () async {
      var repo = MockRepo();
      var directory = createDir();

      var store = CacheStore(directory, 'test', 2, const Duration(days: 7),
          cacheRepoProvider: Future.value(repo),
          cleanupRunMinInterval: const Duration());

      var cacheObject = CacheObject('baseflow.com/test.png',
          relativePath: 'testimage.png', id: 1);
      await (await directory).childFile('testimage.png').create();

      when(repo.getObjectsOverCapacity(any))
          .thenAnswer((_) => Future.value([cacheObject]));
      when(repo.getOldObjects(any)).thenAnswer((_) => Future.value([]));
      when(repo.get('baseflow.com/test.png'))
          .thenAnswer((_) => Future.value(cacheObject));

      expect(await store.getFile('baseflow.com/test.png'), isNotNull);

      await untilCalled(repo.deleteAll(any));

      verify(repo.getObjectsOverCapacity(any)).called(1);
      verify(repo.deleteAll(argThat(contains(cacheObject.id)))).called(1);
    });

    test('Store should remove file over that are too old', () async {
      var repo = MockRepo();
      var directory = createDir();

      var store = CacheStore(directory, 'test', 2, const Duration(days: 7),
          cacheRepoProvider: Future.value(repo),
          cleanupRunMinInterval: const Duration());

      var cacheObject = CacheObject('baseflow.com/test.png',
          relativePath: 'testimage.png', id: 1);
      await (await directory).childFile('testimage.png').create();

      when(repo.getObjectsOverCapacity(any))
          .thenAnswer((_) => Future.value([]));
      when(repo.getOldObjects(any))
          .thenAnswer((_) => Future.value([cacheObject]));
      when(repo.get('baseflow.com/test.png'))
          .thenAnswer((_) => Future.value(cacheObject));

      expect(await store.getFile('baseflow.com/test.png'), isNotNull);

      await untilCalled(repo.deleteAll(any));

      verify(repo.getOldObjects(any)).called(1);
      verify(repo.deleteAll(argThat(contains(cacheObject.id)))).called(1);
    });



    test('Store should remove file old and over capacity', () async {
      var repo = MockRepo();
      var directory = createDir();

      var store = CacheStore(directory, 'test', 2, const Duration(days: 7),
          cacheRepoProvider: Future.value(repo),
          cleanupRunMinInterval: const Duration());

      var cacheObject = CacheObject('baseflow.com/test.png',
          relativePath: 'testimage.png', id: 1);
      var file = await (await directory).childFile('testimage.png').create();

      when(repo.getObjectsOverCapacity(any))
          .thenAnswer((_) => Future.value([cacheObject]));
      when(repo.getOldObjects(any))
          .thenAnswer((_) => Future.value([cacheObject]));
      when(repo.get('baseflow.com/test.png'))
          .thenAnswer((_) => Future.value(cacheObject));

      expect(await store.getFile('baseflow.com/test.png'), isNotNull);

      await untilCalled(repo.deleteAll(any));
      await Future.delayed(const Duration(milliseconds: 5));

      verify(repo.getObjectsOverCapacity(any)).called(1);
      verify(repo.getOldObjects(any)).called(1);
      verify(repo.deleteAll(argThat(contains(cacheObject.id)))).called(1);
    });

    test('Store should not remove files that are not old or over capacity',
        () async {
      var repo = MockRepo();
      var directory = createDir();

      var store = CacheStore(directory, 'test', 2, const Duration(days: 7),
          cacheRepoProvider: Future.value(repo),
          cleanupRunMinInterval: const Duration());

      var cacheObject = CacheObject('baseflow.com/test.png',
          relativePath: 'testimage.png', id: 1);
      await (await directory).childFile('testimage.png').create();

      when(repo.getObjectsOverCapacity(any))
          .thenAnswer((_) => Future.value([]));
      when(repo.getOldObjects(any)).thenAnswer((_) => Future.value([]));
      when(repo.get('baseflow.com/test.png'))
          .thenAnswer((_) => Future.value(cacheObject));

      expect(await store.getFile('baseflow.com/test.png'), isNotNull);

      await untilCalled(repo.deleteAll(any));

      verify(repo.getOldObjects(any)).called(1);
      verifyNever(repo.deleteAll(argThat(contains(cacheObject.id))));
    });

    test('Store should remove all files when emptying cache', () async {
      var repo = MockRepo();
      var directory = createDir();

      var store = CacheStore(directory, 'test', 2, const Duration(days: 7),
          cacheRepoProvider: Future.value(repo),
          cleanupRunMinInterval: const Duration());

      var co1 = CacheObject('baseflow.com/test.png',
          relativePath: 'testimage1.png', id: 1);
      var co2 = CacheObject('baseflow.com/test.png',
          relativePath: 'testimage2.png', id: 2);
      var co3 = CacheObject('baseflow.com/test.png',
          relativePath: 'testimage3.png', id: 3);

      when(repo.getAllObjects())
          .thenAnswer((_) => Future.value([co1, co2, co3]));

      await store.emptyCache();

      verify(repo.deleteAll(argThat(containsAll([co1.id, co2.id, co3.id]))))
          .called(1);
    });
  });
}

Future<Directory> createDir() async {
  final fileSystem = MemoryFileSystem();
  return fileSystem.systemTempDirectory.createTemp('test');
}

class MockRepo extends Mock implements CacheInfoRepository {}
