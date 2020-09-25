import 'dart:convert';
import 'dart:io' as io;
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter_cache_manager/src/storage/cache_info_repositories/json_cache_info_repository.dart';
import 'package:flutter_cache_manager/src/storage/cache_object.dart';
import 'package:flutter_test/flutter_test.dart';

const String databaseName = 'test';
const String path =
    '/data/user/0/com.example.example/databases/$databaseName.json';
final directory = MemoryFileSystem().directory('database');
const String testurl = 'www.baseflow.com/test.png';
const String testurl2 = 'www.baseflow.com/test2.png';
const String testurl3 = 'www.baseflow.com/test3.png';
const String testurl4 = 'www.baseflow.com/test4.png';

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

    test('Create repository with path and databaseName throws assertion error',
        () {
      expect(
          () => JsonCacheInfoRepository(
                path: path,
                databaseName: databaseName,
              ),
          throwsAssertionError);
    });

    test('Create repository with directory is successful', () {
      var repository = JsonCacheInfoRepository.withFile(io.File(path));
      expect(repository, isNotNull);
    });

    test('Create repository without file throws assertion error', () {
      expect(
          // ignore: missing_required_param
          () => JsonCacheInfoRepository.withFile(null),
          throwsAssertionError);
    });
  });

  group('Open repository', () {
    test('Open repository should not throw', () async {
      var repository = JsonCacheInfoRepository.withFile(io.File(path));
      await repository.open();
    });
  });

  group('Get', () {
    test('Existing key should return', () async {
      var repo = await Helpers.createRepository();
      var result = await repo.get(testurl);
      expect(result, isNotNull);
    });

    test('Non-existing key should return null', () async {
      var repo = await Helpers.createRepository();
      var result = await repo.get('not an url');
      expect(result, isNull);
    });

    test('getAllObjects should return all objects', () async {
      var repo = await Helpers.createRepository();
      var result = await repo.getAllObjects();
      expect(result.length, Helpers.startCacheObjects.length);
    });

    test('getObjectsOverCapacity should return oldest objects', () async {
      var repo = await Helpers.createRepository();
      var result = await repo.getObjectsOverCapacity(1);
      expect(result.length, 2);
      expectIdInList(result, 1);
      expectIdInList(result, 3);
    });

    test('getOldObjects should return only old objects', () async {
      var repo = await Helpers.createRepository();
      var result = await repo.getOldObjects(const Duration(days: 7));
      expect(result.length, 1);
    });
  });

  group('update and insert', () {
    test('insert adds new object', () async {
      var repo = await Helpers.createRepository();
      var objectToInsert = Helpers.extraCacheObject;
      var insertedObject = await repo.insert(Helpers.extraCacheObject);
      expect(insertedObject.id, Helpers.startCacheObjects.length + 1);
      expect(insertedObject.url, objectToInsert.url);
      expect(insertedObject.touched, isNotNull);

      var allObjects = await repo.getAllObjects();
      var newObject =
          allObjects.where((element) => element.id == insertedObject.id);
      expect(newObject, isNotNull);
    });

    test('insert throws when adding existing object', () async {
      var repo = await Helpers.createRepository();
      var objectToInsert = Helpers.startCacheObjects.first;
      expect(() => repo.insert(objectToInsert), throwsArgumentError);
    });

    test('update changes existing item', () async {
      var repo = await Helpers.createRepository();
      var objectToInsert = Helpers.startCacheObjects.first;
      var newUrl = 'newUrl.com';
      var updatedObject = objectToInsert.copyWith(url: newUrl);
      await repo.update(updatedObject);
      var retrievedObject = await repo.get(objectToInsert.key);
      expect(retrievedObject.url, newUrl);
    });

    test('update throws when adding new object', () async {
      var repo = await Helpers.createRepository();
      var newObject = Helpers.extraCacheObject;
      expect(() => repo.update(newObject), throwsArgumentError);
    });

    test('updateOrInsert updates existing item', () async {
      var repo = await Helpers.createRepository();
      var objectToInsert = Helpers.startCacheObjects.first;
      var newUrl = 'newUrl.com';
      var updatedObject = objectToInsert.copyWith(url: newUrl);
      await repo.updateOrInsert(updatedObject);
      var retrievedObject = await repo.get(objectToInsert.key);
      expect(retrievedObject.url, newUrl);
    });

    test('updateOrInsert inserts new item', () async {
      var repo = await Helpers.createRepository();
      var objectToInsert = Helpers.extraCacheObject;
      var insertedObject = await repo.updateOrInsert(Helpers.extraCacheObject);
      expect(insertedObject.id, Helpers.startCacheObjects.length + 1);
      expect(insertedObject.url, objectToInsert.url);
      expect(insertedObject.touched, isNotNull);

      var allObjects = await repo.getAllObjects();
      var newObject =
          allObjects.where((element) => element.id == insertedObject.id);
      expect(newObject, isNotNull);
    });
  });

  group('delete', () {
    test('delete removes item', () async {
      var removedId = 2;
      var repo = await Helpers.createRepository();
      var deleted = await repo.delete(removedId);
      expect(deleted, 1);
      var objects = await repo.getAllObjects();
      var removedObject = objects.where((element) => element.id == removedId);
      expect(removedObject.length, 0);
      expect(objects.length, Helpers.startCacheObjects.length - 1);
    });

    test('deleteAll removes all items', () async {
      var removedIds = [2, 3];
      var repo = await Helpers.createRepository();
      var deleted = await repo.deleteAll(removedIds);
      expect(deleted, 2);
      var objects = await repo.getAllObjects();
      var removedObject =
          objects.where((element) => removedIds.contains(element.id));
      expect(removedObject.length, 0);
      expect(
          objects.length, Helpers.startCacheObjects.length - removedIds.length);
    });

    test('delete does not remove non-existing items', () async {
      var removedId = 99;
      var repo = await Helpers.createRepository();
      var deleted = await repo.delete(removedId);
      expect(deleted, 0);
    });

  });

  group('storage', (){
    test('Changes should be persisted', () async {
      var repo = await Helpers.createRepository();
      await repo.insert(Helpers.extraCacheObject);
      var allObjects = await repo.getAllObjects();
      expect(allObjects.length, Helpers.startCacheObjects.length + 1);

      await repo.close();
      await repo.open();

      var allObjectsAfterOpen = await repo.getAllObjects();
      expect(allObjectsAfterOpen.length, Helpers.startCacheObjects.length + 1);

    });
  });
}

void expectIdInList(List<CacheObject> cacheObjects, int id) {
  var object = cacheObjects.singleWhere((element) => element.id == id,
      orElse: () => null);
  expect(object, isNotNull);
}

class Helpers {
  static Future<JsonCacheInfoRepository> createRepository() async {
    var directory = await _createDirectory();
    var file = await _createFile(directory);
    var repository = JsonCacheInfoRepository.withFile(file);
    await repository.open();
    return repository;
  }

  static Future<Directory> _createDirectory() async {
    var testDir =
        await MemoryFileSystem().systemTempDirectory.createTemp('testFolder');
    await testDir.create(recursive: true);
    return testDir;
  }

  static Future<File> _createFile(Directory dir) {
    var file = dir.childFile('$databaseName.json');
    var json = jsonEncode(_createCacheObjects());
    return file.writeAsString(json);
  }

  static List<Map<String, dynamic>> _createCacheObjects() {
    return startCacheObjects
        .map((e) => e.toMap(setTouchedToNow: false))
        .toList();
  }

  static final List<CacheObject> startCacheObjects = [
    // Old object
    CacheObject(
      testurl,
      key: testurl,
      id: 1,
      touched: clock.now().subtract(const Duration(days: 8)),
    ),
    // New object
    CacheObject(
      testurl2,
      key: testurl2,
      id: 2,
      touched: clock.now(),
    ),
    // A less new object
    CacheObject(
      testurl3,
      key: testurl3,
      id: 3,
      touched: clock.now().subtract(const Duration(minutes: 1)),
    ),
  ];
  static final CacheObject extraCacheObject = CacheObject(
    testurl4,
    key: testurl4,
  );
}
