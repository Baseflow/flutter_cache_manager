import 'dart:async';

import 'package:clock/clock.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter_cache_manager/src/cache_store.dart';
import 'package:flutter_cache_manager/src/logger.dart';
import 'package:flutter_cache_manager/src/storage/cache_object.dart';
import 'package:flutter_cache_manager/src/storage/file_system/file_system.dart'
    as cache_file_system;
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'helpers/config_extensions.dart';
import 'helpers/mock_cache_info_repository.dart';
import 'helpers/test_configuration.dart';

void main() {
  late int fileId;
  late String fileName;
  late String fileUrl;
  late DateTime validTill;

  late CacheObject cacheObject;

  setUp(() {
    fileId = 666;
    fileName = 'testimage.png';
    fileUrl = 'baseflow.com/test.png';
    validTill = DateTime(2017, 9, 7, 17, 30);

    cacheObject = CacheObject(
      fileUrl,
      relativePath: fileName,
      id: fileId,
      validTill: validTill,
    );
  });

  group('Retrieving files from store', () {
    test('Store should return null when file not cached', () async {
      var repo = MockCacheInfoRepository();
      when(repo.get(any)).thenAnswer((_) => Future.value(null));
      var store = CacheStore(createTestConfig());

      expect(await store.getFile('This is a test'), null);
    });

    test('Store should return FileInfo when file is cached', () async {
      var config = createTestConfig();
      await config.returnsFile(fileName);
      config.returnsCacheObject(fileUrl, fileName, DateTime.now());

      var tempDir = createDir();
      await (await tempDir).childFile('testimage.png').create();

      var store = CacheStore(config);

      expect(await store.getFile('baseflow.com/test.png'), isNotNull);
    });

    test(
      'Store should return FileInfo and handle error when database update fails on cache hit',
      () async {
        final testLogger = setUpTestLogger();

        var config = createTestConfig();
        await config.returnsFile(fileName);
        config.returnsCacheObject(
          fileUrl,
          fileName,
          DateTime.now(),
          id: fileId,
        );
        when(
          config.mockRepo.updateOrInsert(any),
        ).thenAnswer((_) => Future.error(Exception('Database update failed')));

        var store = CacheStore(config);

        final fileInfo = await store.getFile(fileUrl);
        expect(fileInfo, isNotNull);

        await untilCalled(config.mockRepo.updateOrInsert(any));
        verify(config.mockRepo.updateOrInsert(any)).called(1);
        await testLogger.waitForLog('Failed to update cache metadata');
      },
    );

    test(
      'Store should treat failed database read as cache miss and clean up pending cache',
      () async {
        final testLogger = setUpTestLogger();

        var config = createTestConfig();
        when(
          config.mockRepo.get(any),
        ).thenAnswer((_) => Future.error(Exception('Database read failed')));

        var store = CacheStore(config);

        final result1 = await store.retrieveCacheData('failed-key');
        expect(result1, isNull);

        final result2 = await store.retrieveCacheData('failed-key');
        expect(result2, isNull);

        verify(config.mockRepo.get(any)).called(2);
        await testLogger.waitForLog('Failed to read cache metadata');
      },
    );

    test(
      'Store cleanup error should be handled without unhandled async error',
      () async {
        final testLogger = setUpTestLogger();

        var config = createTestConfig();
        var store = CacheStore(config);
        store.cleanupRunMinInterval = const Duration(milliseconds: 1);
        await config.returnsFile(fileName);
        config.returnsCacheObject(fileUrl, fileName, validTill, id: fileId);

        when(
          config.mockRepo.getObjectsOverCapacity(any),
        ).thenAnswer((_) => Future.error(Exception('Cleanup failure')));

        expect(await store.getFile(fileUrl), isNotNull);

        await untilCalled(config.mockRepo.getObjectsOverCapacity(any));
        verify(config.mockRepo.getObjectsOverCapacity(any)).called(1);

        await testLogger.waitForLog('Failed to cleanup cache');
      },
    );

    test('Store should return null if file is not cached', () async {
      var config = createTestConfig();
      await config.returnsFile(fileName);
      config.returnsCacheObject(
        fileUrl,
        fileName,
        validTill,
        id: fileId,
        key: fileUrl,
      );

      var tempDir = createDir();
      await (await tempDir).childFile('testimage.png').create();

      final store = CacheStore(config);

      final results = Future.wait([
        store.removeCachedFile(cacheObject),
        store.removeCachedFile(cacheObject),
      ]);

      expect(() => results, returnsNormally);
    });

    test('Store should return null when file is no longer cached', () async {
      var repo = MockCacheInfoRepository();

      when(repo.get('baseflow.com/test.png')).thenAnswer(
        (_) => Future.value(
          CacheObject(
            'baseflow.com/test.png',
            relativePath: 'testimage.png',
            validTill: clock.now().add(const Duration(days: 7)),
          ),
        ),
      );
      var store = CacheStore(createTestConfig());

      expect(await store.getFile('baseflow.com/test.png'), null);
    });

    test('Store should return no CacheInfo when file not cached', () async {
      var repo = MockCacheInfoRepository();
      when(repo.get(any)).thenAnswer((_) => Future.value(null));
      var store = CacheStore(createTestConfig());

      expect(await store.retrieveCacheData('This is a test'), null);
    });

    test('Store should return CacheInfo when file is cached', () async {
      var config = createTestConfig();
      await config.returnsFile(fileName);
      config.returnsCacheObject(fileUrl, fileName, DateTime.now(), id: 1);

      var store = CacheStore(config);
      final cacheObject = await store.retrieveCacheData(fileUrl);
      expect(cacheObject, isNotNull);
      expect(cacheObject!.id, isNotNull);
    });

    test(
      'Store should return CacheInfo from memory when asked twice',
      () async {
        var validTill = DateTime.now();
        var config = createTestConfig();

        await config.returnsFile(fileName);
        config.returnsCacheObject(fileUrl, fileName, validTill, id: 1);
        var store = CacheStore(config);

        var result = await store.retrieveCacheData(fileUrl);
        expect(result, isNotNull);
        expect(result!.id, isNotNull);

        var otherResult = await store.retrieveCacheData(fileUrl);
        expect(otherResult!.id, isNotNull);

        verify(config.mockRepo.get(any)).called(1);
      },
    );

    test(
      'Store should return File from memcache only when file is retrieved before',
      () async {
        var validTill = DateTime.now();
        var config = createTestConfig();

        await config.returnsFile(fileName);
        config.returnsCacheObject(fileUrl, fileName, validTill);

        var store = CacheStore(config);

        expect(await store.getFileFromMemory(fileUrl), null);
        await store.getFile(fileUrl);
        expect(await store.getFileFromMemory(fileUrl), isNotNull);
      },
    );

    test(
      'Store.memoryCacheContainsKey should return true if the key is present in the memory cache',
      () async {
        var config = createTestConfig();
        var store = CacheStore(config);

        var cacheObject = CacheObject(
          'baseflow.com/test.png',
          relativePath: 'testimage.png',
          validTill: clock.now().add(const Duration(days: 7)),
        );
        await store.putFile(cacheObject);

        expect(store.memoryCacheContainsKey('baseflow.com/test.png'), true);
        expect(store.memoryCacheContainsKey('unseen-file'), false);
      },
    );
  });

  group('Storing files in store', () {
    test('Store should store fileinfo in repo', () async {
      var config = createTestConfig();
      var store = CacheStore(config);

      var cacheObject = CacheObject(
        'baseflow.com/test.png',
        relativePath: 'testimage.png',
        validTill: clock.now().add(const Duration(days: 7)),
      );
      await store.putFile(cacheObject);

      verify(config.repo.updateOrInsert(cacheObject)).called(1);
    });

    test(
      'Store should store fileinfo in repo and id should be available afterwards',
      () async {
        var config = createTestConfig();

        var cacheObject = CacheObject(
          'baseflow.com/test.png',
          relativePath: 'testimage.png',
          validTill: clock.now().add(const Duration(days: 7)),
        );

        await config.returnsFile(cacheObject.relativePath);
        when(
          config.mockRepo.updateOrInsert(cacheObject),
        ).thenAnswer((realInvocation) async => cacheObject.copyWith(id: 1));

        var store = CacheStore(config);
        await store.putFile(cacheObject);

        verify(config.repo.updateOrInsert(cacheObject)).called(1);

        final result = await store.retrieveCacheData(cacheObject.key);
        expect(result!.id, isNotNull);
      },
    );

    test(
      'putFile restores or removes memory cache entry when updateOrInsert fails',
      () async {
        var config = createTestConfig();
        var store = CacheStore(config);

        var initialObject = CacheObject(
          'baseflow.com/test.png',
          relativePath: 'testimage_old.png',
          validTill: clock.now().add(const Duration(days: 7)),
        );
        var newObject = CacheObject(
          'baseflow.com/test.png',
          relativePath: 'testimage_new.png',
          validTill: clock.now().add(const Duration(days: 7)),
        );

        // Case 1: Nothing was in memory cache before, putFile fails
        when(
          config.mockRepo.updateOrInsert(newObject),
        ).thenAnswer((_) => Future.error(Exception('DB error')));

        await expectLater(
          () => store.putFile(newObject),
          throwsA(isA<Exception>()),
        );
        expect(store.memoryCacheContainsKey(newObject.key), isFalse);

        // Case 2: initialObject succeeded, then updating to newObject fails
        when(
          config.mockRepo.updateOrInsert(initialObject),
        ).thenAnswer((_) => Future.value(initialObject));
        await store.putFile(initialObject);
        expect(store.memoryCacheContainsKey(initialObject.key), isTrue);

        await expectLater(
          () => store.putFile(newObject),
          throwsA(isA<Exception>()),
        );
        // Should have restored initialObject, not left pointing at newObject
        expect(store.memoryCacheContainsKey(initialObject.key), isTrue);
        expect(
          (await store.getFileFromMemory(initialObject.key))?.file.path,
          contains('testimage_old.png'),
        );
      },
    );
  });

  group('Removing files in store', () {
    test('Store should remove fileinfo from repo on delete', () async {
      var validTill = DateTime.now();
      var config = createTestConfig();

      await config.returnsFile(fileName);
      config.returnsCacheObject(fileUrl, fileName, validTill);

      var store = CacheStore(config);
      store.cleanupRunMinInterval = const Duration(milliseconds: 1);

      var cacheObject = CacheObject(
        fileUrl,
        relativePath: fileName,
        id: 1,
        validTill: clock.now().add(const Duration(days: 7)),
      );
      await store.removeCachedFile(cacheObject);

      verify(
        config.mockRepo.deleteAll(argThat(contains(cacheObject.id))),
      ).called(1);
    });

    test('Store should remove file over capacity', () async {
      var config = createTestConfig();
      var store = CacheStore(config);
      store.cleanupRunMinInterval = const Duration(milliseconds: 1);

      var cacheObject = CacheObject(
        'baseflow.com/test.png',
        relativePath: 'testimage.png',
        id: 1,
        validTill: clock.now().add(const Duration(days: 7)),
      );
      await config.returnsFile('testimage.png');

      when(
        config.mockRepo.getObjectsOverCapacity(any),
      ).thenAnswer((_) => Future.value([cacheObject]));
      when(
        config.mockRepo.getOldObjects(any),
      ).thenAnswer((_) => Future.value([]));
      when(
        config.mockRepo.get('baseflow.com/test.png'),
      ).thenAnswer((_) => Future.value(cacheObject));

      expect(await store.getFile('baseflow.com/test.png'), isNotNull);

      await untilCalled(config.mockRepo.deleteAll(any));

      verify(config.mockRepo.getObjectsOverCapacity(any)).called(1);
      verify(
        config.mockRepo.deleteAll(argThat(contains(cacheObject.id))),
      ).called(1);
    });

    test('Store should remove file over that are too old', () async {
      var config = createTestConfig();
      var store = CacheStore(config);
      store.cleanupRunMinInterval = const Duration(milliseconds: 1);
      await config.returnsFile('testimage.png');

      var cacheObject = CacheObject(
        'baseflow.com/test.png',
        relativePath: 'testimage.png',
        id: 1,
        validTill: clock.now().add(const Duration(days: 7)),
      );

      when(
        config.mockRepo.getObjectsOverCapacity(any),
      ).thenAnswer((_) => Future.value([]));
      when(
        config.mockRepo.getOldObjects(any),
      ).thenAnswer((_) => Future.value([cacheObject]));
      when(
        config.mockRepo.get('baseflow.com/test.png'),
      ).thenAnswer((_) => Future.value(cacheObject));

      expect(await store.getFile('baseflow.com/test.png'), isNotNull);

      await untilCalled(config.mockRepo.deleteAll(any));

      verify(config.mockRepo.getOldObjects(any)).called(1);
      verify(
        config.mockRepo.deleteAll(argThat(contains(cacheObject.id))),
      ).called(1);
    });

    test('Store should remove file old and over capacity', () async {
      var config = createTestConfig();
      var store = CacheStore(config);
      store.cleanupRunMinInterval = const Duration(milliseconds: 1);
      await config.returnsFile('testimage.png');

      var cacheObject = CacheObject(
        'baseflow.com/test.png',
        relativePath: 'testimage.png',
        id: 1,
        validTill: clock.now().add(const Duration(days: 7)),
      );

      when(
        config.mockRepo.getObjectsOverCapacity(any),
      ).thenAnswer((_) => Future.value([cacheObject]));
      when(
        config.mockRepo.getOldObjects(any),
      ).thenAnswer((_) => Future.value([cacheObject]));
      when(
        config.mockRepo.get('baseflow.com/test.png'),
      ).thenAnswer((_) => Future.value(cacheObject));

      expect(await store.getFile('baseflow.com/test.png'), isNotNull);

      await untilCalled(config.mockRepo.deleteAll(any));
      await Future.delayed(const Duration(milliseconds: 5));

      verify(config.mockRepo.getObjectsOverCapacity(any)).called(1);
      verify(config.mockRepo.getOldObjects(any)).called(1);
      verify(
        config.mockRepo.deleteAll(argThat(contains(cacheObject.id))),
      ).called(1);
    });

    test(
      'Store should not remove cache info before the cached file is removed',
      () async {
        var config = createTestConfig();
        var store = CacheStore(config);
        store.cleanupRunMinInterval = const Duration(milliseconds: 1);
        var file = await config.returnsFile('testimage.png');

        var cacheObject = CacheObject(
          'baseflow.com/test.png',
          relativePath: 'testimage.png',
          id: 1,
          validTill: clock.now().add(const Duration(days: 7)),
        );

        when(
          config.mockRepo.getObjectsOverCapacity(any),
        ).thenAnswer((_) => Future.value([]));
        when(
          config.mockRepo.getOldObjects(any),
        ).thenAnswer((_) => Future.value([cacheObject]));
        when(
          config.mockRepo.get('baseflow.com/test.png'),
        ).thenAnswer((_) => Future.value(cacheObject));

        expect(await store.getFile('baseflow.com/test.png'), isNotNull);

        // From here on, getting to the file takes a while, like a slow disk.
        final fileAvailable = Completer<void>();
        store.fileSystem = _DelayedFileSystem(
          store.fileSystem,
          fileAvailable.future,
        );

        // Give the cleanup time to run. It must not delete the cache info
        // while the file is still on disk.
        await Future.delayed(const Duration(milliseconds: 50));
        verifyNever(config.mockRepo.deleteAll(any));
        expect(file.existsSync(), isTrue);

        fileAvailable.complete();
        await untilCalled(config.mockRepo.deleteAll(any));

        expect(file.existsSync(), isFalse);
        verify(
          config.mockRepo.deleteAll(argThat(contains(cacheObject.id))),
        ).called(1);
      },
    );

    test(
      'Store should keep cache info of a file that cannot be removed',
      () async {
        final fileSystem = _FailingDeleteFileSystem('broken.png');
        final config = createTestConfig();
        final store = CacheStore(config);
        store.cleanupRunMinInterval = const Duration(milliseconds: 1);
        store.fileSystem = fileSystem;
        await fileSystem.createFileWithData('ok.png');
        await fileSystem.createFileWithData('broken.png');

        final okObject = CacheObject(
          'baseflow.com/ok.png',
          relativePath: 'ok.png',
          id: 1,
          validTill: clock.now().add(const Duration(days: 7)),
        );
        final brokenObject = CacheObject(
          'baseflow.com/broken.png',
          relativePath: 'broken.png',
          id: 2,
          validTill: clock.now().add(const Duration(days: 7)),
        );

        when(
          config.mockRepo.getObjectsOverCapacity(any),
        ).thenAnswer((_) => Future.value([]));
        when(
          config.mockRepo.getOldObjects(any),
        ).thenAnswer((_) => Future.value([okObject, brokenObject]));
        when(
          config.mockRepo.get('baseflow.com/ok.png'),
        ).thenAnswer((_) => Future.value(okObject));

        // The failed removal is still reported as a logged cleanup failure.
        final logger = setUpTestLogger();
        expect(await store.getFile('baseflow.com/ok.png'), isNotNull);
        final log = await logger.waitForLog('Failed to cleanup cache');
        expect(log, contains('Cannot delete'));
        verify(
          config.mockRepo.deleteAll(
            argThat(allOf(contains(okObject.id), isNot(contains(2)))),
          ),
        ).called(1);
      },
    );

    test('Store should recheck cache info when file is removed', () async {
      var config = createTestConfig();
      var store = CacheStore(config);
      store.cleanupRunMinInterval = const Duration(milliseconds: 1);
      var file = await config.returnsFile('testimage.png');

      var cacheObject = CacheObject(
        'baseflow.com/test.png',
        relativePath: 'testimage.png',
        id: 1,
        validTill: clock.now().add(const Duration(days: 7)),
      );

      when(
        config.mockRepo.getObjectsOverCapacity(any),
      ).thenAnswer((_) => Future.value([]));
      when(
        config.mockRepo.getOldObjects(any),
      ).thenAnswer((_) => Future.value([]));
      when(
        config.mockRepo.get('baseflow.com/test.png'),
      ).thenAnswer((_) => Future.value(cacheObject));

      expect(await store.getFile('baseflow.com/test.png'), isNotNull);
      await file.delete();
      expect(await store.getFile('baseflow.com/test.png'), isNull);
    });

    test(
      'Store should not remove files that are not old or over capacity',
      () async {
        var config = createTestConfig();
        var store = CacheStore(config);
        store.cleanupRunMinInterval = const Duration(milliseconds: 1);
        await config.returnsFile('testimage.png');

        var cacheObject = CacheObject(
          'baseflow.com/test.png',
          relativePath: 'testimage.png',
          id: 1,
          validTill: clock.now().add(const Duration(days: 7)),
        );

        when(
          config.mockRepo.getObjectsOverCapacity(any),
        ).thenAnswer((_) => Future.value([]));
        when(
          config.mockRepo.getOldObjects(any),
        ).thenAnswer((_) => Future.value([]));
        when(
          config.mockRepo.get('baseflow.com/test.png'),
        ).thenAnswer((_) => Future.value(cacheObject));

        expect(await store.getFile('baseflow.com/test.png'), isNotNull);

        await untilCalled(config.mockRepo.deleteAll(any));

        verify(config.mockRepo.getOldObjects(any)).called(1);
        verifyNever(
          config.mockRepo.deleteAll(argThat(contains(cacheObject.id))),
        );
      },
    );

    test('Store should remove all files when emptying cache', () async {
      var config = createTestConfig();
      var store = CacheStore(config);
      store.cleanupRunMinInterval = const Duration(milliseconds: 1);
      await config.returnsFile('testimage.png');

      var co1 = CacheObject(
        'baseflow.com/test.png',
        relativePath: 'testimage1.png',
        id: 1,
        validTill: clock.now().add(const Duration(days: 7)),
      );
      var co2 = CacheObject(
        'baseflow.com/test.png',
        relativePath: 'testimage2.png',
        id: 2,
        validTill: clock.now().add(const Duration(days: 7)),
      );
      var co3 = CacheObject(
        'baseflow.com/test.png',
        relativePath: 'testimage3.png',
        id: 3,
        validTill: clock.now().add(const Duration(days: 7)),
      );

      when(
        config.mockRepo.getAllObjects(),
      ).thenAnswer((_) => Future.value([co1, co2, co3]));

      await store.emptyCache();

      verify(
        config.mockRepo.deleteAll(
          argThat(containsAll([co1.id, co2.id, co3.id])),
        ),
      ).called(1);
    });

    test('Store should delete file when remove cached file', () async {
      var config = createTestConfig();
      var store = CacheStore(config);

      await config.returnsFile(fileName);
      config.returnsCacheObject(fileUrl, fileName, validTill, id: 1);

      var cacheObject = await store.retrieveCacheData(fileUrl);

      expect(cacheObject, isNotNull);
      var fileInfo = await store.getFile(cacheObject!.key);
      expect(await fileInfo?.file.exists(), isTrue);

      await store.removeCachedFile(cacheObject);

      expect(await fileInfo?.file.exists(), isFalse);
    });
  });
}

Future<Directory> createDir() async {
  final fileSystem = MemoryFileSystem();
  return fileSystem.systemTempDirectory.createTemp('test');
}

class TestCacheLogger extends CacheLogger {
  final logs = <String>[];
  Completer<String>? _nextLogCompleter;

  Future<String> waitForLog([Pattern? pattern]) async {
    while (true) {
      if (pattern != null) {
        final existing = logs.where((l) => l.contains(pattern)).firstOrNull;
        if (existing != null) return existing;
      } else if (logs.isNotEmpty) {
        return logs.first;
      }
      _nextLogCompleter ??= Completer<String>();
      await _nextLogCompleter!.future;
    }
  }

  @override
  void log(String message, CacheManagerLogLevel level) {
    logs.add(message);
    final c = _nextLogCompleter;
    _nextLogCompleter = null;
    c?.complete(message);
  }
}

TestCacheLogger setUpTestLogger() {
  final originalLogger = cacheLogger;
  final testLogger = TestCacheLogger();
  cacheLogger = testLogger;
  addTearDown(() => cacheLogger = originalLogger);
  return testLogger;
}

/// A file system that only hands out files once [_available] has completed.
class _DelayedFileSystem extends cache_file_system.FileSystem {
  _DelayedFileSystem(this._inner, this._available);

  final cache_file_system.FileSystem _inner;
  final Future<void> _available;

  @override
  Future<File> createFile(String name) async {
    await _available;
    return _inner.createFile(name);
  }
}

/// A file system in which deleting the file called [undeletableName] fails.
class _FailingDeleteFileSystem extends cache_file_system.FileSystem {
  _FailingDeleteFileSystem(String undeletableName)
    : _fileSystem = MemoryFileSystem(
        opHandle: (path, operation) {
          if (operation == FileSystemOp.delete &&
              path.endsWith(undeletableName)) {
            throw FileSystemException('Cannot delete', path);
          }
        },
      );

  final MemoryFileSystem _fileSystem;
  late final Directory _directory = _fileSystem.systemTempDirectory
      .createTempSync('test');

  @override
  Future<File> createFile(String name) async => _directory.childFile(name);

  Future<void> createFileWithData(String name) async {
    await (await createFile(name)).writeAsBytes([1, 3]);
  }
}
