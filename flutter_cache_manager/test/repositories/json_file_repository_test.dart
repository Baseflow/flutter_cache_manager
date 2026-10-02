import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:file/file.dart' as pf;
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/src/storage/cache_info_repositories/json_cache_info_repository.dart';
import 'package:flutter_cache_manager/src/storage/cache_object.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/json_repo_helpers.dart';

void main() {
  group('Create repository', () {
    test('Create repository with databasename is successful', () {
      var repository = JsonCacheInfoRepository(databaseName: databaseName);
      expect(repository, isNotNull);
    });

    test('Create repository with path is successful', () {
      var repository = JsonCacheInfoRepository(path: path);
      expect(repository, isNotNull);
    });

    test(
      'Create repository with path and databaseName throws assertion error',
      () {
        expect(
          () => JsonCacheInfoRepository(path: path, databaseName: databaseName),
          throwsAssertionError,
        );
      },
    );

    test('Create repository with directory is successful', () {
      var repository = JsonCacheInfoRepository.withFile(File(path));
      expect(repository, isNotNull);
    });
  });

  group('Open and close repository', () {
    test('Open repository should not throw', () async {
      var repository = JsonCacheInfoRepository.withFile(File(path));
      await repository.open();
    });

    test('An open repository can be closed', () async {
      var repository = await JsonRepoHelpers.createRepository();
      var isClosed = await repository.close();
      expect(isClosed, true);
    });

    test('Opening twice should close after second close', () async {
      var repository = await JsonRepoHelpers.createRepository();
      await repository.open();
      var isClosed = await repository.close();
      expect(isClosed, false);
      isClosed = await repository.close();
      expect(isClosed, true);
    });
  });

  group('Exist and delete', () {
    test('New repository does not exist', () async {
      var repository = JsonCacheInfoRepository.withFile(File(path));
      var exists = await repository.exists();
      expect(exists, false);
    });

    test('Existing repository does exists', () async {
      var repository = await JsonRepoHelpers.createRepository();
      var exists = await repository.exists();
      expect(exists, true);
    });

    test('Deleted repository does not exists', () async {
      var repository = await JsonRepoHelpers.createRepository();
      await repository.deleteDataFile();
      var exists = await repository.exists();
      expect(exists, false);
    });
  });

  group('Get', () {
    test('Existing key should return', () async {
      var repo = await JsonRepoHelpers.createRepository();
      var result = await repo.get(testurl);
      expect(result, isNotNull);
    });

    test('Non-existing key should return null', () async {
      var repo = await JsonRepoHelpers.createRepository();
      var result = await repo.get('not an url');
      expect(result, isNull);
    });

    test('getAllObjects should return all objects', () async {
      var repo = await JsonRepoHelpers.createRepository();
      var result = await repo.getAllObjects();
      expect(result.length, JsonRepoHelpers.startCacheObjects.length);
    });

    test('getObjectsOverCapacity should return oldest objects', () async {
      var repo = await JsonRepoHelpers.createRepository();
      var result = await repo.getObjectsOverCapacity(1);
      expect(result.length, 2);
      expectIdInList(result, 1);
      expectIdInList(result, 3);
    });

    test('getOldObjects should return only old objects', () async {
      var repo = await JsonRepoHelpers.createRepository();
      var result = await repo.getOldObjects(const Duration(days: 7));
      expect(result.length, 1);
    });
  });

  group('update and insert', () {
    test('insert adds new object', () async {
      var repo = await JsonRepoHelpers.createRepository();
      var objectToInsert = JsonRepoHelpers.extraCacheObject;
      var insertedObject = await repo.insert(JsonRepoHelpers.extraCacheObject);
      expect(insertedObject.id, JsonRepoHelpers.startCacheObjects.length + 1);
      expect(insertedObject.url, objectToInsert.url);
      expect(insertedObject.touched, isNotNull);

      var allObjects = await repo.getAllObjects();
      var newObject = allObjects.where(
        (element) => element.id == insertedObject.id,
      );
      expect(newObject, isNotNull);
    });

    test('insert throws when adding existing object', () async {
      var repo = await JsonRepoHelpers.createRepository();
      var objectToInsert = JsonRepoHelpers.startCacheObjects.first;
      expect(() => repo.insert(objectToInsert), throwsArgumentError);
    });

    test('update changes existing item', () async {
      var repo = await JsonRepoHelpers.createRepository();
      var objectToInsert = JsonRepoHelpers.startCacheObjects.first;
      var newUrl = 'newUrl.com';
      var updatedObject = objectToInsert.copyWith(url: newUrl);
      await repo.update(updatedObject);
      var retrievedObject = await repo.get(objectToInsert.key);
      expect(retrievedObject!.url, newUrl);
    });

    test('update throws when adding new object', () async {
      var repo = await JsonRepoHelpers.createRepository();
      var newObject = JsonRepoHelpers.extraCacheObject;
      expect(() => repo.update(newObject), throwsArgumentError);
    });

    test('updateOrInsert updates existing item', () async {
      var repo = await JsonRepoHelpers.createRepository();
      var objectToInsert = JsonRepoHelpers.startCacheObjects.first;
      var newUrl = 'newUrl.com';
      var updatedObject = objectToInsert.copyWith(url: newUrl);
      await repo.updateOrInsert(updatedObject);
      var retrievedObject = await repo.get(objectToInsert.key);
      expect(retrievedObject!.url, newUrl);
    });

    test('updateOrInsert inserts new item', () async {
      var repo = await JsonRepoHelpers.createRepository();
      var objectToInsert = JsonRepoHelpers.extraCacheObject;
      var insertedObject = await repo.updateOrInsert(
        JsonRepoHelpers.extraCacheObject,
      );
      expect(insertedObject.id, JsonRepoHelpers.startCacheObjects.length + 1);
      expect(insertedObject.url, objectToInsert.url);
      expect(insertedObject.touched, isNotNull);

      var allObjects = await repo.getAllObjects();
      var newObject = allObjects.where(
        (element) => element.id == insertedObject.id,
      );
      expect(newObject, isNotNull);
    });
  });

  group('delete', () {
    test('delete removes item', () async {
      var removedId = 2;
      var repo = await JsonRepoHelpers.createRepository();
      var deleted = await repo.delete(removedId);
      expect(deleted, 1);
      var objects = await repo.getAllObjects();
      var removedObject = objects.where((element) => element.id == removedId);
      expect(removedObject.length, 0);
      expect(objects.length, JsonRepoHelpers.startCacheObjects.length - 1);
    });

    test('deleteAll removes all items', () async {
      var removedIds = [2, 3];
      var repo = await JsonRepoHelpers.createRepository();
      var deleted = await repo.deleteAll(removedIds);
      expect(deleted, 2);
      var objects = await repo.getAllObjects();
      var removedObject = objects.where(
        (element) => removedIds.contains(element.id),
      );
      expect(removedObject.length, 0);
      expect(
        objects.length,
        JsonRepoHelpers.startCacheObjects.length - removedIds.length,
      );
    });

    test('delete does not remove non-existing items', () async {
      var removedId = 99;
      var repo = await JsonRepoHelpers.createRepository();
      var deleted = await repo.delete(removedId);
      expect(deleted, 0);
    });
  });

  group('storage', () {
    test('Changes should be persisted', () async {
      var repo = await JsonRepoHelpers.createRepository();
      await repo.insert(JsonRepoHelpers.extraCacheObject);
      var allObjects = await repo.getAllObjects();
      expect(allObjects.length, JsonRepoHelpers.startCacheObjects.length + 1);

      await repo.close();
      await repo.open();

      var allObjectsAfterOpen = await repo.getAllObjects();
      expect(
        allObjectsAfterOpen.length,
        JsonRepoHelpers.startCacheObjects.length + 1,
      );
    });

    test('Changes are persisted when the mutating future completes', () async {
      final file = await JsonRepoHelpers.createDatabaseFile();
      final repo = JsonCacheInfoRepository.withFile(file);
      await repo.open();
      await repo.insert(JsonRepoHelpers.extraCacheObject);

      // New instance reads from disk without closing the first repository.
      final repo2 = JsonCacheInfoRepository.withFile(file);
      await repo2.open();
      final allObjects = await repo2.getAllObjects();
      expect(allObjects.length, JsonRepoHelpers.startCacheObjects.length + 1);
    });

    test('Persist does not leave a temp file', () async {
      final file = await JsonRepoHelpers.createDatabaseFile();
      final repo = JsonCacheInfoRepository.withFile(file);
      await repo.open();
      await repo.insert(JsonRepoHelpers.extraCacheObject);

      final tempFile = file.fileSystem.file('${file.path}.tmp');
      expect(await tempFile.exists(), false);
      expect(await file.exists(), true);
      expect(jsonDecode(await file.readAsString()), isA<List<dynamic>>());
    });

    test('A failing write is reported and retried on close', () async {
      final file = await JsonRepoHelpers.createDatabaseFile();
      final repo = JsonCacheInfoRepository.withFile(file);
      await repo.open();

      // Writing is impossible while the containing directory is gone.
      await file.parent.delete(recursive: true);

      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = errors.add;
      await repo.insert(JsonRepoHelpers.extraCacheObject);
      FlutterError.onError = originalOnError;

      expect(errors, hasLength(1));

      await file.parent.create(recursive: true);
      expect(await repo.close(), true);

      final repo2 = JsonCacheInfoRepository.withFile(file);
      await repo2.open();
      final allObjects = await repo2.getAllObjects();
      expect(allObjects.length, JsonRepoHelpers.startCacheObjects.length + 1);
    });

    group('A rename refused by another process', () {
      Future<(JsonCacheInfoRepository, pf.File, _FlakyRenameFileSystem)>
      createRepository({required int failures, required int errorCode}) async {
        final original = await JsonRepoHelpers.createDatabaseFile();
        final fileSystem = _FlakyRenameFileSystem(
          original.fileSystem,
          failures: failures,
          errorCode: errorCode,
        );
        final file = fileSystem.file(original.path);
        final repo = JsonCacheInfoRepository.withFile(file);
        await repo.open();
        return (repo, file, fileSystem);
      }

      Future<List<FlutterErrorDetails>> insertCollectingErrors(
        JsonCacheInfoRepository repo,
      ) async {
        final errors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = errors.add;
        try {
          await repo.insert(JsonRepoHelpers.extraCacheObject);
        } finally {
          FlutterError.onError = originalOnError;
        }
        return errors;
      }

      test('is retried until it succeeds', () async {
        final (repo, file, fileSystem) = await createRepository(
          failures: 2,
          errorCode: 32,
        );

        final errors = await insertCollectingErrors(repo);

        expect(errors, isEmpty);
        expect(fileSystem.renameAttempts, 3);
        final repo2 = JsonCacheInfoRepository.withFile(file);
        await repo2.open();
        final allObjects = await repo2.getAllObjects();
        expect(allObjects.length, JsonRepoHelpers.startCacheObjects.length + 1);
      });

      test('is reported once the retries run out', () async {
        final (repo, _, fileSystem) = await createRepository(
          failures: 100,
          errorCode: 5,
        );

        final errors = await insertCollectingErrors(repo);

        expect(errors, hasLength(1));
        expect(fileSystem.renameAttempts, 5);
      });

      test('is not retried for other errors', () async {
        final (repo, _, fileSystem) = await createRepository(
          failures: 1,
          errorCode: 2,
        );

        final errors = await insertCollectingErrors(repo);

        expect(errors, hasLength(1));
        expect(fileSystem.renameAttempts, 1);
      });
    });
  });
}

/// A file system whose renames fail [failures] times, with [errorCode], before
/// working again.
class _FlakyRenameFileSystem extends pf.ForwardingFileSystem {
  _FlakyRenameFileSystem(
    super.delegate, {
    required this.failures,
    required this.errorCode,
  });

  int failures;
  final int errorCode;
  int renameAttempts = 0;

  @override
  pf.File file(dynamic path) => _FlakyRenameFile(this, delegate.file(path));
}

class _FlakyRenameFile extends pf.ForwardingFileSystemEntity<pf.File, File>
    with pf.ForwardingFile {
  _FlakyRenameFile(this.fileSystem, this.delegate);

  @override
  final _FlakyRenameFileSystem fileSystem;

  @override
  final pf.File delegate;

  @override
  Future<pf.File> rename(String newPath) async {
    fileSystem.renameAttempts++;
    if (fileSystem.failures > 0) {
      fileSystem.failures--;
      throw FileSystemException(
        'Cannot rename file to \'$newPath\'',
        path,
        OSError('Refused by the test file system', fileSystem.errorCode),
      );
    }
    return wrap(await delegate.rename(newPath));
  }

  @override
  pf.File wrapFile(File delegate) =>
      _FlakyRenameFile(fileSystem, delegate as pf.File);

  @override
  pf.Directory wrapDirectory(Directory delegate) => delegate as pf.Directory;

  @override
  pf.Link wrapLink(Link delegate) => delegate as pf.Link;
}

void expectIdInList(List<CacheObject> cacheObjects, int id) {
  var object = cacheObjects.singleWhereOrNull((element) => element.id == id);
  expect(object, isNotNull);
}
