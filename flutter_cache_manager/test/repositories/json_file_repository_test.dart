import 'dart:convert';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter_cache_manager/src/storage/cache_info_repositories/json_cache_info_repository.dart';
import 'package:flutter_cache_manager/src/storage/cache_object.dart';
import 'package:flutter_test/flutter_test.dart';

const String databaseName = 'test';
const String path =
    '/data/user/0/com.example.example/databases/$databaseName.db';
final directory = MemoryFileSystem().directory('database');
const String testurl = 'www.baseflow.com/test.png';
const String testurl2 = 'www.baseflow.com/test2.png';

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
      var repository = JsonCacheInfoRepository.inDirectory(
        directory: directory,
        databaseName: databaseName,
      );
      expect(repository, isNotNull);
    });

    test('Create repository without directory throws assertion error', () {
      expect(
          // ignore: missing_required_param
          () => JsonCacheInfoRepository.inDirectory(
                databaseName: databaseName,
              ),
          throwsAssertionError);
    });
    test('Create repository without databaseName throws assertion error', () {
      expect(
          // ignore: missing_required_param
          () => JsonCacheInfoRepository.inDirectory(
                directory: directory,
              ),
          throwsAssertionError);
    });
  });

  group('Open repository', () {
    test('Open repository should not throw', () async {
      var repository = JsonCacheInfoRepository.inDirectory(
        directory: directory,
        databaseName: databaseName,
      );
      await repository.open();
    });
  });

  group('Get', () {
    test('Existing key should return', () async {
      var repo = await Helpers._createRepository();
      var result = await repo.get(testurl);
      expect(result, isNotNull);
    });

    test('Non-existing key should return null', () async {
      var repo = await Helpers._createRepository();
      var result = await repo.get('not an url');
      expect(result, isNull);
    });

    test('getAllObjects should return all objects', () async {
      var repo = await Helpers._createRepository();
      var result = await repo.getAllObjects();
      expect(result.length, Helpers.cacheObjects.length);
    });
  });
}

class Helpers {
  static Future<JsonCacheInfoRepository> _createRepository() async {
    var directory = await _createDirectory();
    var repository = JsonCacheInfoRepository(
      databaseName: databaseName,
    );
    await repository.openWithFile(await _createFile(directory));
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
    return cacheObjects.map((e) => e.toMap()).toList();
  }

  static final List<CacheObject> cacheObjects = [
    CacheObject(testurl, key: testurl, id: 1),
    CacheObject(testurl, key: testurl2, id: 2),
  ];
}
