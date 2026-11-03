import 'package:file/memory.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
