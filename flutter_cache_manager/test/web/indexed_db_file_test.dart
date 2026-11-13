@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:file/file.dart';
import 'package:flutter_cache_manager/src/storage/cache_info_repositories/indexed_db_connection_pool.dart';
import 'package:flutter_cache_manager/src/storage/cache_info_repositories/indexed_db_schema.dart';
import 'package:flutter_cache_manager/src/storage/file_system/indexed_db_file.dart';
import 'package:flutter_test/flutter_test.dart';

import 'indexed_db_test_helpers.dart';

const _db = 'indexed_db_file_test';
const _chunk = IndexedDbSchema.chunkSize;

Uint8List _pattern(int length) =>
    Uint8List.fromList(List.generate(length, (i) => i * 7 & 0xff));

void main() {
  tearDown(() => deleteDatabase(_db));

  test(
    'openWrite streams a large file into IndexedDB and reads it back',
    () async {
      final file = IndexedDbFile('large.file', _db);
      final sink = file.openWrite();
      const writeSize = 64 * 1024;
      const totalBytes = 212 * 1024 * 1024;
      final chunk = Uint8List(writeSize);
      for (var i = 0; i < writeSize; i++) {
        chunk[i] = i & 0xff;
      }
      for (var written = 0; written < totalBytes; written += writeSize) {
        sink.add(chunk);
      }
      await sink.close();

      expect(await file.length(), totalBytes);
      final bytes = await file.readAsBytes();
      expect(bytes.length, totalBytes);
      expect(bytes[writeSize + 7], 7);
      expect(bytes[totalBytes - 1], 0xff);
      await file.delete();
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('the sink writes chunks as data arrives, not on close', () async {
    final file = IndexedDbFile('streamed.file', _db);
    final sink = file.openWrite();
    sink.add(_pattern(_chunk * 2 + 10));
    await sink.flush();

    // Two full chunks are stored before close; the tail is still buffered
    // and the file is not visible yet.
    expect(await countChunks(_db, 'streamed.file'), 2);
    expect(await file.exists(), isFalse);

    await sink.close();
    expect(await countChunks(_db, 'streamed.file'), 3);
    expect(await file.exists(), isTrue);
    expect(await file.length(), _chunk * 2 + 10);
  });

  test('openRead streams chunk by chunk and honours start and end', () async {
    final data = _pattern(_chunk * 3 + 5);
    final file = IndexedDbFile('ranges.file', _db);
    await file.writeAsBytes(data);

    final pieces = await file.openRead().toList();
    expect(pieces, hasLength(4));
    expect(pieces.expand((e) => e).toList(), data);

    const start = _chunk - 3;
    const end = _chunk * 2 + 4;
    final range = await file.openRead(start, end).expand((e) => e).toList();
    expect(range, data.sublist(start, end));

    expect(await file.openRead(_chunk * 3 + 5).toList(), isEmpty);
  });

  test('exists and length do not read the contents, and a missing file '
      'reports as such', () async {
    final file = IndexedDbFile('missing.file', _db);
    expect(await file.exists(), isFalse);
    await expectLater(file.length(), throwsA(isA<FileSystemException>()));
    await expectLater(file.readAsBytes(), throwsA(isA<FileSystemException>()));
  });

  test('delete removes the header and every chunk', () async {
    final file = IndexedDbFile('deleted.file', _db);
    await file.writeAsBytes(_pattern(_chunk * 2 + 1));
    expect(await countChunks(_db, 'deleted.file'), 3);

    await file.delete();
    expect(await file.exists(), isFalse);
    expect(await countChunks(_db, 'deleted.file'), 0);
  });

  test('delete also removes the chunks of an unfinished write', () async {
    final file = IndexedDbFile('partial.file', _db);
    final sink = file.openWrite()..add(_pattern(_chunk + 1));
    await sink.flush();
    expect(await countChunks(_db, 'partial.file'), 1);

    await file.delete();
    expect(await countChunks(_db, 'partial.file'), 0);
  });

  test('writing again replaces the previous contents', () async {
    final file = IndexedDbFile('rewrite.file', _db);
    await file.writeAsBytes(_pattern(_chunk * 2));
    await file.writeAsBytes([1, 2, 3]);

    expect(await file.readAsBytes(), [1, 2, 3]);
    expect(await countChunks(_db, 'rewrite.file'), 1);
  });

  test('append mode continues after a partial last chunk', () async {
    final first = _pattern(_chunk + 3);
    final second = _pattern(_chunk);
    final file = IndexedDbFile('append.file', _db);
    await file.writeAsBytes(first);
    await file.writeAsBytes(second, mode: FileMode.append);

    expect(await file.readAsBytes(), [...first, ...second]);
  });

  test('write and writeAll encode text into the file', () async {
    final file = IndexedDbFile('text.file', _db);
    final sink = file.openWrite()
      ..write('ab')
      ..writeAll(['c', 'd'], '-')
      ..add([0x21]);
    await sink.close();

    expect(await file.readAsString(), 'abc-d!');
  });

  test('files written by the previous single-record layout stay '
      'readable', () async {
    final data = _pattern(1000);
    // Opens the database at the current version, then stores a record the
    // way schema version 2 did.
    await IndexedDbFile('other', _db).exists();
    await putRecord(
      _db,
      IndexedDbSchema.filesStore,
      <String, Object>{'path': 'legacy.file', 'data': data}.jsify()!,
    );

    final file = IndexedDbFile('legacy.file', _db);
    expect(await file.exists(), isTrue);
    expect(await file.length(), 1000);
    expect(await file.readAsBytes(), data);
    expect(
      await file.openRead(10, 20).expand((e) => e).toList(),
      data.sublist(10, 20),
    );
    await file.delete();
    expect(await file.exists(), isFalse);
  });

  test('the pool closes the connection when the last holder releases '
      'it', () async {
    final pool = IndexedDbConnectionPool.getInstance(databaseName: _db);
    await pool.acquire();
    await pool.acquire();
    pool.release();
    expect(pool.isOpen, isTrue);
    pool.release();
    expect(pool.isOpen, isFalse);

    // Files reopen it on demand.
    expect(await IndexedDbFile('x', _db).exists(), isFalse);
    expect(pool.isOpen, isTrue);
  });
}
