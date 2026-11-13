@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_cache_manager/src/storage/cache_info_repositories/indexed_db_cache_info_repository.dart';
import 'package:flutter_cache_manager/src/storage/cache_info_repositories/indexed_db_connection_pool.dart';
import 'package:flutter_cache_manager/src/storage/cache_info_repositories/indexed_db_schema.dart';
import 'package:flutter_cache_manager/src/storage/file_system/indexed_db_file.dart';
import 'package:flutter_test/flutter_test.dart';

import 'indexed_db_test_helpers.dart';

const _db = 'indexed_db_repository_test';

CacheObject _object(String key, {DateTime? touched, String? path}) =>
    CacheObject(
      'https://example.com/$key',
      key: key,
      relativePath: path ?? '$key.file',
      validTill: DateTime(2030),
      touched: touched,
    );

void main() {
  late IndexedDbCacheInfoRepository repo;

  setUp(() async {
    repo = IndexedDbCacheInfoRepository(databaseName: _db);
    await repo.open();
  });

  tearDown(() async {
    await repo.close();
    await deleteDatabase(_db);
  });

  test('insert, get, update and delete a cache object', () async {
    final inserted = await repo.insert(_object('a'));
    expect(inserted.id, isNotNull);

    final read = await repo.get('a');
    expect(read!.id, inserted.id);
    expect(read.relativePath, 'a.file');

    await repo.update(read.copyWith(eTag: 'v2'));
    expect((await repo.get('a'))!.eTag, 'v2');

    await repo.delete(inserted.id!);
    expect(await repo.get('a'), isNull);
  });

  test('updateOrInsert, getAllObjects and deleteAll', () async {
    final a = await repo.updateOrInsert(_object('a')) as CacheObject;
    await repo.updateOrInsert(_object('b'));
    expect(await repo.getAllObjects(), hasLength(2));

    await repo.deleteAll([a.id!]);
    final left = await repo.getAllObjects();
    expect(left.map((o) => o.key), ['b']);
  });

  test('getObjectsOverCapacity returns the least recently used', () async {
    for (var i = 0; i < 5; i++) {
      await repo.insert(
        _object('k$i', touched: DateTime(2026, 1, 1 + i)),
        setTouchedToNow: false,
      );
    }
    final over = await repo.getObjectsOverCapacity(3);
    expect(over.map((o) => o.key), ['k0', 'k1']);
  });

  test('getOldObjects returns entries older than the max age', () async {
    final now = DateTime.now();
    await repo.insert(
      _object('old', touched: now.subtract(const Duration(days: 40))),
      setTouchedToNow: false,
    );
    await repo.insert(_object('new'));
    final old = await repo.getOldObjects(const Duration(days: 30));
    expect(old.map((o) => o.key), ['old']);
  });

  test('freeing space after a quota error removes the cache info rows and '
      'the file contents they point to', () async {
    for (var i = 0; i < 20; i++) {
      final path = 'f$i.file';
      await repo.insert(
        _object('k$i', touched: DateTime(2026, 1, 1 + i), path: path),
        setTouchedToNow: false,
      );
      await IndexedDbFile(path, _db).writeAsBytes(List.filled(1000, i));
    }

    final pool = IndexedDbConnectionPool.getInstance(databaseName: _db);
    final removed = await evictLeastRecentlyUsed(await pool.getDatabase());

    // 10% of 20 entries, oldest first.
    expect(removed, 2);
    expect(await repo.get('k0'), isNull);
    expect(await repo.get('k1'), isNull);
    expect(await repo.get('k2'), isNotNull);
    expect(await IndexedDbFile('f0.file', _db).exists(), isFalse);
    expect(await IndexedDbFile('f1.file', _db).exists(), isFalse);
    expect(await countChunks(_db, 'f0.file'), 0);
    expect(await IndexedDbFile('f2.file', _db).exists(), isTrue);
    expect(await countRecords(_db, IndexedDbSchema.filesStore), 18);
    expect(await countRecords(_db, IndexedDbSchema.chunksStore), 18);
  });

  test('close releases the shared connection', () async {
    final pool = IndexedDbConnectionPool.getInstance(databaseName: _db);
    expect(pool.isOpen, isTrue);
    await repo.close();
    expect(pool.isOpen, isFalse);
    // Reopen so tearDown's close is balanced.
    await repo.open();
  });

  test('deleteDataFile deletes the database', () async {
    await repo.insert(_object('a'));
    await repo.deleteDataFile();

    repo = IndexedDbCacheInfoRepository(databaseName: _db);
    await repo.open();
    expect(await repo.getAllObjects(), isEmpty);
  });

  test('a CacheManager stores and finds files across instances', () async {
    final config = Config(
      'cm',
      repo: IndexedDbCacheInfoRepository(databaseName: _db),
      fileSystem: IndexedDbFileSystem(_db),
    );
    final manager = CacheManager(config);
    await manager.putFile('https://example.com/x', Uint8List.fromList([1, 2]));
    await manager.dispose();

    final again = CacheManager(
      Config(
        'cm',
        repo: IndexedDbCacheInfoRepository(databaseName: _db),
        fileSystem: IndexedDbFileSystem(_db),
      ),
    );
    final info = await again.getFileFromCache('https://example.com/x');
    expect(await info!.file.readAsBytes(), [1, 2]);
    await again.dispose();
  });
}
