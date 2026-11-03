import 'dart:async';
import 'dart:io' show File;

import 'package:file/memory.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'helpers/mock_cache_info_repository.dart';
import 'helpers/mock_file_service.dart';
import 'helpers/test_configuration.dart';

void main() {
  test(
    'replacement retains the old file if JSON metadata cannot persist',
    () async {
      final disk = MemoryFileSystem();
      final repo = JsonCacheInfoRepository.withFile(
        disk.file('/metadata.json'),
      );
      final manager = CacheManager(
        Config(
          'repro',
          repo: repo,
          fileSystem: TestFileSystem(),
          fileService: MockFileService(),
        ),
      );
      const url = 'https://example.test/report.pdf';
      final old = (await manager.webHelper.downloadFile(url).toList())
          .whereType<FileInfo>()
          .single
          .file;
      await disk.directory('/metadata.json.tmp').create();
      final originalHandler = FlutterError.onError;
      final errors = <FlutterErrorDetails>[];
      FlutterError.onError = errors.add;
      try {
        Object? error;
        try {
          await manager.webHelper
              .downloadFile(url, ignoreMemCache: true)
              .toList();
        } on Object catch (e) {
          error = e;
        }
        expect(
          await old.exists(),
          isTrue,
          reason:
              'a failed metadata write must not delete the previous cached file',
        );
        expect(
          error,
          isNotNull,
          reason: 'persistence failures must be reported',
        );
        expect(errors, hasLength(1));
        final originalMetadata = await repo.get(url);
        expect(old.path, endsWith(originalMetadata!.relativePath));
        expect((await manager.getFileFromCache(url))!.file.path, old.path);
        expect((await old.parent.list().toList()).length, 1);
        await disk.directory('/metadata.json.tmp').delete();
        await repo.insert(
          CacheObject(
            'unrelated',
            relativePath: 'other.file',
            validTill: DateTime.now(),
          ),
        );
        final reloaded = JsonCacheInfoRepository.withFile(
          disk.file('/metadata.json'),
        );
        await reloaded.open();
        expect(
          (await reloaded.get(url))!.relativePath,
          originalMetadata.relativePath,
        );
        expect(await old.exists(), isTrue);
        await reloaded.close();
        final replacement =
            (await manager.webHelper
                    .downloadFile(url, ignoreMemCache: true)
                    .toList())
                .whereType<FileInfo>()
                .single
                .file;
        expect(await replacement.exists(), isTrue);
        expect(await old.exists(), isFalse);
        final finalRepo = JsonCacheInfoRepository.withFile(
          disk.file('/metadata.json'),
        );
        await finalRepo.open();
        expect(
          (await finalRepo.get(url))!.relativePath,
          isNot(originalMetadata.relativePath),
        );
        expect(await finalRepo.get('unrelated'), isNotNull);
        await finalRepo.close();
      } finally {
        FlutterError.onError = originalHandler;
      }
    },
  );
  test(
    'failed extension-changing replacement preserves old file and metadata',
    () async {
      final disk = MemoryFileSystem();
      final repo = JsonCacheInfoRepository.withFile(
        disk.file('/metadata.json'),
      );
      final fileSystem = TestFileSystem();
      final manager = CacheManager(
        Config(
          'extension-change',
          repo: repo,
          fileSystem: fileSystem,
          fileService: MockFileService(),
        ),
      );
      const key = 'stable-key';
      const newUrl = 'https://example.test/new.jpg';
      final old = await fileSystem.createFile('old.png');
      final oldBytes = await File('test/images/image-120.png').readAsBytes();
      await old.writeAsBytes(oldBytes);
      await manager.store.putFile(
        CacheObject(
          'https://example.test/old.png',
          key: key,
          relativePath: 'old.png',
          validTill: DateTime.utc(2030),
          eTag: 'old-tag',
        ),
      );
      final before = await repo.get(key);
      await disk.directory('/metadata.json.tmp').create();
      final previousHandler = FlutterError.onError;
      final errors = <FlutterErrorDetails>[];
      FlutterError.onError = errors.add;
      try {
        await expectLater(
          manager.webHelper.downloadFile(newUrl, key: key).toList(),
          throwsA(anything),
        );
        expect(errors, hasLength(1));
        expect(await old.exists(), isTrue);
        expect(await old.readAsBytes(), oldBytes);
        final after = await repo.get(key);
        expect(
          after!.toMap(setTouchedToNow: false),
          before!.toMap(setTouchedToNow: false),
        );
        expect((await manager.getFileFromCache(key))!.file.path, old.path);
        final reloaded = JsonCacheInfoRepository.withFile(
          disk.file('/metadata.json'),
        );
        await reloaded.open();
        expect(
          (await reloaded.get(key))!.toMap(setTouchedToNow: false),
          before.toMap(setTouchedToNow: false),
        );
        await reloaded.close();
        expect((await old.parent.list().toList()).length, 1);
      } finally {
        FlutterError.onError = previousHandler;
      }
    },
  );
  test(
    'extension-changing replacement retains old file until persisted',
    () async {
      final config = createTestConfig();
      final manager = CacheManager(config);
      const key = 'stable-key';
      final old = await config.fileSystem.createFile('old.png');
      final oldBytes = await File('test/images/image-120.png').readAsBytes();
      await old.writeAsBytes(oldBytes);
      await manager.store.putFile(
        CacheObject(
          'https://example.test/old.png',
          key: key,
          relativePath: 'old.png',
          validTill: DateTime.utc(2030),
        ),
      );
      final started = Completer<void>();
      final release = Completer<dynamic>();
      when(
        (config.repo as MockCacheInfoRepository).updateOrInsert(any),
      ).thenAnswer((_) {
        started.complete();
        return release.future;
      });
      final pending = manager.webHelper
          .downloadFile('https://example.test/new.jpg', key: key)
          .toList();
      await started.future;
      expect(await old.exists(), isTrue);
      expect(await old.readAsBytes(), oldBytes);
      final files = await old.parent.list().toList();
      expect(files.length, 2);
      release.complete();
      final result = (await pending).whereType<FileInfo>().single;
      expect(await result.file.exists(), isTrue);
      expect(result.file.path, endsWith('.jpg'));
      expect(await old.exists(), isFalse);
    },
  );
}
