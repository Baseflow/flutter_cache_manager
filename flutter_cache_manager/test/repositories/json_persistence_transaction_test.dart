import 'dart:io' show FileSystemException;

import 'package:file/memory.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FlutterExceptionHandler? previousHandler;
  late List<FlutterErrorDetails> errors;

  setUp(() {
    previousHandler = FlutterError.onError;
    errors = [];
    FlutterError.onError = errors.add;
  });
  tearDown(() => FlutterError.onError = previousHandler);

  test('failed insert is absent after a subsequent write and reopen', () async {
    final fixture = await _Fixture.create();
    fixture.failNextWrite = true;
    await expectLater(
      fixture.repo.insert(_object('failed')),
      throwsA(isA<FileSystemException>()),
    );
    expect(await fixture.repo.get('failed'), isNull);
    final inserted = await fixture.repo.insert(_object('later'));
    expect(inserted.id, 1);
    final reopened = await fixture.reopen();
    expect(await reopened.get('failed'), isNull);
    expect(await reopened.get('later'), isNotNull);
    expect(errors, hasLength(1));
  });

  test(
    'failed update never leaks into a later write or reopen; retry succeeds',
    () async {
      final fixture = await _Fixture.create();
      final original = await fixture.repo.insert(_object('original'));
      final replacement = original.copyWith(relativePath: 'replacement.pdf');
      fixture.failNextWrite = true;
      await expectLater(
        fixture.repo.update(replacement),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        (await fixture.repo.get('original'))!.relativePath,
        'original.pdf',
      );
      await fixture.repo.insert(_object('later'));
      var reopened = await fixture.reopen();
      expect((await reopened.get('original'))!.relativePath, 'original.pdf');
      await fixture.repo.update(replacement);
      reopened = await fixture.reopen();
      expect((await reopened.get('original'))!.relativePath, 'replacement.pdf');
      expect(errors, hasLength(1));
    },
  );

  test(
    'failed delete and deleteAll retain metadata through subsequent writes',
    () async {
      final fixture = await _Fixture.create();
      final a = await fixture.repo.insert(_object('a'));
      final b = await fixture.repo.insert(_object('b'));
      fixture.failNextWrite = true;
      await expectLater(
        fixture.repo.delete(a.id!),
        throwsA(isA<FileSystemException>()),
      );
      fixture.failNextWrite = true;
      await expectLater(
        fixture.repo.deleteAll([a.id!, b.id!]),
        throwsA(isA<FileSystemException>()),
      );
      expect(await fixture.repo.get('a'), isNotNull);
      expect(await fixture.repo.get('b'), isNotNull);
      await fixture.repo.insert(_object('later'));
      var reopened = await fixture.reopen();
      expect(await reopened.get('a'), isNotNull);
      expect(await reopened.get('b'), isNotNull);
      expect(await fixture.repo.deleteAll([a.id!, b.id!]), 2);
      reopened = await fixture.reopen();
      expect(await reopened.get('a'), isNull);
      expect(await reopened.get('b'), isNull);
      expect(await reopened.get('later'), isNotNull);
      expect(errors, hasLength(2));
    },
  );

  test('overlapping queued writes recover from the first failure', () async {
    final fixture = await _Fixture.create();
    fixture.failNextWrite = true;
    final failed = fixture.repo.insert(_object('failed'));
    final failedAssertion = expectLater(
      failed,
      throwsA(isA<FileSystemException>()),
    );
    final succeeding = fixture.repo.insert(_object('succeeding'));
    await failedAssertion;
    final inserted = await succeeding;
    expect(inserted.id, 1);
    final reopened = await fixture.reopen();
    expect(await reopened.get('failed'), isNull);
    expect((await reopened.get('succeeding'))!.id, 1);
    expect(errors, hasLength(1));
  });

  test('data-file deletion waits for an already queued write', () async {
    final fixture = await _Fixture.create();
    final pending = fixture.repo.insert(_object('queued'));
    final deletion = fixture.repo.deleteDataFile();
    await pending;
    await deletion;
    expect(await fixture.repo.exists(), isFalse);
  });

  test('queued touch uses current metadata after a replacement', () async {
    final fixture = await _Fixture.create();
    final old = await fixture.repo.insert(_object('image'));
    final replacement = old.copyWith(relativePath: 'replacement.png');
    final update = fixture.repo.update(replacement);
    final touch = fixture.repo.touch('image');
    await Future.wait([update, touch]);
    final reopened = await fixture.reopen();
    expect((await reopened.get('image'))!.relativePath, 'replacement.png');
  });
}

CacheObject _object(String key) =>
    CacheObject(key, relativePath: '$key.pdf', validTill: DateTime.utc(2030));

class _Fixture {
  _Fixture._();
  bool failNextWrite = false;
  late final MemoryFileSystem disk;
  late final JsonCacheInfoRepository repo;

  static Future<_Fixture> create() async {
    final fixture = _Fixture._();
    fixture.disk = MemoryFileSystem(
      opHandle: (path, operation) {
        if (fixture.failNextWrite &&
            operation == FileSystemOp.write &&
            path.endsWith('.tmp')) {
          fixture.failNextWrite = false;
          throw FileSystemException('injected write failure', path);
        }
      },
    );
    fixture.repo = JsonCacheInfoRepository.withFile(
      fixture.disk.file('/cache.json'),
    );
    await fixture.repo.open();
    return fixture;
  }

  Future<JsonCacheInfoRepository> reopen() async {
    final reopened = JsonCacheInfoRepository.withFile(disk.file('/cache.json'));
    await reopened.open();
    return reopened;
  }
}
