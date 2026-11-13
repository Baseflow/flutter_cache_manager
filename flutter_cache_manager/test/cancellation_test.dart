import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_cache_manager/src/cache_store.dart';
import 'package:flutter_cache_manager/src/web/web_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'helpers/mock_cache_info_repository.dart';
import 'helpers/test_configuration.dart';
import 'test_images.dart';

void main() {
  late ControlledFileService fileService;
  late MockCacheInfoRepository repo;
  late TestFileSystem fileSystem;
  late Config config;

  setUp(() {
    fileService = ControlledFileService();
    repo = MockCacheInfoRepository();
    fileSystem = TestFileSystem();
    config = Config(
      'test',
      fileSystem: fileSystem,
      repo: repo,
      fileService: fileService,
    );
  });

  Future<List<String>> filesOnDisk() async {
    final dir = await fileSystem.directoryFuture;
    return dir.listSync().map((e) => e.basename).toList();
  }

  group('WebHelper', () {
    test('mid-stream cancellation stops the response and removes the '
        'partial file', () async {
      final response = StreamingResponse();
      fileService.handler = (_) async => response;
      final webHelper = WebHelper(CacheStore(config), fileService);
      final token = CancellationToken();

      final events = webHelper
          .downloadFile('https://a.test/image', cancellationToken: token)
          .toList();
      final failure = expectLater(events, throwsA(isA<CancelledException>()));

      await pumpEventQueue();
      response.controller.add([1, 2, 3]);
      await pumpEventQueue();
      expect(await filesOnDisk(), hasLength(1));

      token.cancel();
      await failure;
      await pumpEventQueue();

      expect(response.listenerCancelled, isTrue);
      expect(fileService.tokens.single!.isCancelled, isTrue);
      expect(await filesOnDisk(), isEmpty);
    });

    test('a failing response stream closes the download and removes the '
        'partial file', () async {
      final response = StreamingResponse();
      fileService.handler = (_) async => response;
      final webHelper = WebHelper(CacheStore(config), fileService);

      final failure = expectLater(
        webHelper.downloadFile('https://a.test/image').toList(),
        throwsA(isA<StateError>()),
      );
      await pumpEventQueue();
      response.controller.add([1, 2, 3]);
      response.controller.addError(StateError('connection reset'));
      await failure;
      await pumpEventQueue();

      expect(await filesOnDisk(), isEmpty);
      verifyNever(repo.updateOrInsert(any));
    });

    test('cancelling a refresh keeps the previously cached file and its '
        'cache info', () async {
      final existing = CacheObject(
        'https://a.test/image',
        key: 'https://a.test/image',
        relativePath: 'existing.jpg',
        validTill: clock.now().subtract(const Duration(days: 1)),
        id: 7,
      );
      when(repo.get(any)).thenAnswer((_) async => existing);
      final old = await fileSystem.createFile('existing.jpg');
      await old.writeAsBytes([9, 9, 9]);

      final response = StreamingResponse(fileExtension: '.jpg');
      fileService.handler = (_) async => response;
      final webHelper = WebHelper(CacheStore(config), fileService);
      final token = CancellationToken();

      final failure = expectLater(
        webHelper
            .downloadFile('https://a.test/image', cancellationToken: token)
            .toList(),
        throwsA(isA<CancelledException>()),
      );
      await pumpEventQueue();
      response.controller.add([1]);
      await pumpEventQueue();
      token.cancel();
      await failure;
      await pumpEventQueue();

      expect(await filesOnDisk(), ['existing.jpg']);
      verifyNever(repo.deleteAll(any));
      verifyNever(repo.delete(any));
    });

    test('one caller cancelling does not affect another caller of the same '
        'url', () async {
      final response = StreamingResponse();
      fileService.handler = (_) async => response;
      final webHelper = WebHelper(CacheStore(config), fileService);
      final tokenA = CancellationToken();

      final a = webHelper
          .downloadFile('https://a.test/image', cancellationToken: tokenA)
          .toList();
      final b = webHelper.downloadFile('https://a.test/image').toList();
      final aFails = expectLater(a, throwsA(isA<CancelledException>()));

      await pumpEventQueue();
      tokenA.cancel();
      await aFails;

      response.controller.add([1, 2, 3]);
      await response.controller.close();
      final bEvents = await b;

      expect(bEvents.whereType<FileInfo>(), hasLength(1));
      expect(fileService.requests, hasLength(1));
      expect(fileService.tokens.single!.isCancelled, isFalse);
    });

    test('a caller without a token is not affected by, and does not ignore, '
        'a later caller cancelling', () async {
      final response = StreamingResponse();
      fileService.handler = (_) async => response;
      final webHelper = WebHelper(CacheStore(config), fileService);
      final tokenB = CancellationToken();

      final a = webHelper.downloadFile('https://a.test/image').toList();
      final b = webHelper
          .downloadFile('https://a.test/image', cancellationToken: tokenB)
          .toList();
      final bFails = expectLater(b, throwsA(isA<CancelledException>()));

      await pumpEventQueue();
      tokenB.cancel();
      await bFails;

      response.controller.add([1, 2, 3]);
      await response.controller.close();
      expect((await a).whereType<FileInfo>(), hasLength(1));
    });

    test('the shared download stops once every caller has cancelled', () async {
      final response = StreamingResponse();
      fileService.handler = (_) async => response;
      final webHelper = WebHelper(CacheStore(config), fileService);
      final tokenA = CancellationToken();
      final tokenB = CancellationToken();

      final a = webHelper
          .downloadFile('https://a.test/image', cancellationToken: tokenA)
          .toList();
      final b = webHelper
          .downloadFile('https://a.test/image', cancellationToken: tokenB)
          .toList();
      final aFails = expectLater(a, throwsA(isA<CancelledException>()));
      final bFails = expectLater(b, throwsA(isA<CancelledException>()));
      await pumpEventQueue();

      tokenA.cancel();
      await aFails;
      expect(fileService.tokens.single!.isCancelled, isFalse);

      tokenB.cancel();
      await bFails;
      await pumpEventQueue();
      expect(fileService.tokens.single!.isCancelled, isTrue);
      expect(response.listenerCancelled, isTrue);

      // A new caller starts a fresh download instead of joining the dead one.
      final next = StreamingResponse();
      fileService.handler = (_) async => next;
      final c = webHelper.downloadFile('https://a.test/image').toList();
      await pumpEventQueue();
      next.controller.add([1]);
      await next.controller.close();
      expect((await c).whereType<FileInfo>(), hasLength(1));
      expect(fileService.requests, hasLength(2));
    });

    test('cancelling a queued request removes it from the queue', () async {
      fileService.concurrentFetches = 1;
      final first = StreamingResponse();
      fileService.handler = (_) async => first;
      final webHelper = WebHelper(CacheStore(config), fileService);
      final token = CancellationToken();

      final running = webHelper.downloadFile('https://a.test/first').toList();
      final queued = webHelper
          .downloadFile('https://a.test/second', cancellationToken: token)
          .toList();
      final queuedFails = expectLater(
        queued,
        throwsA(isA<CancelledException>()),
      );
      await pumpEventQueue();
      expect(fileService.requests, ['https://a.test/first']);

      token.cancel();
      await queuedFails;

      first.controller.add([1]);
      await first.controller.close();
      await running;
      await pumpEventQueue();
      expect(fileService.requests, ['https://a.test/first']);
    });

    test('an already cancelled token never starts a download', () async {
      fileService.handler = (_) async => StreamingResponse();
      final webHelper = WebHelper(CacheStore(config), fileService);
      final token = CancellationToken()..cancel();

      await expectLater(
        webHelper
            .downloadFile('https://a.test/image', cancellationToken: token)
            .toList(),
        throwsA(isA<CancelledException>()),
      );
      expect(fileService.requests, isEmpty);
    });

    test(
      'a file service that ignores the token is abandoned on cancel',
      () async {
        final pending = Completer<FileServiceResponse>();
        fileService.handler = (_) => pending.future;
        final webHelper = WebHelper(CacheStore(config), fileService);
        final token = CancellationToken();

        final failure = expectLater(
          webHelper
              .downloadFile('https://a.test/image', cancellationToken: token)
              .toList(),
          throwsA(isA<CancelledException>()),
        );
        await pumpEventQueue();
        token.cancel();
        await failure;

        // The late response is discarded: its body is never read into a file.
        final late = StreamingResponse();
        pending.complete(late);
        await pumpEventQueue();
        expect(late.listenerCancelled, isTrue);
        expect(await filesOnDisk(), isEmpty);
      },
    );
  });

  group('CacheManager', () {
    test('getFileStream passes the token to the download', () async {
      final response = StreamingResponse();
      fileService.handler = (_) async => response;
      final cacheManager = TestImageCacheManager(config);
      final token = CancellationToken();

      final failure = expectLater(
        cacheManager
            .getFileStream('https://a.test/image', cancellationToken: token)
            .toList(),
        throwsA(isA<CancelledException>()),
      );
      await pumpEventQueue();
      expect(fileService.tokens.single, isNotNull);

      token.cancel();
      await failure;
      expect(fileService.tokens.single!.isCancelled, isTrue);
    });

    test('getSingleFile with a cancelled token throws without '
        'downloading', () async {
      fileService.handler = (_) async => StreamingResponse();
      final cacheManager = TestImageCacheManager(config);

      await expectLater(
        cacheManager.getSingleFile(
          'https://a.test/image',
          cancellationToken: CancellationToken()..cancel(),
        ),
        throwsA(isA<CancelledException>()),
      );
      expect(fileService.requests, isEmpty);
    });

    test('downloadFile passes the token to the download', () async {
      final response = StreamingResponse();
      fileService.handler = (_) async => response;
      final cacheManager = TestImageCacheManager(config);
      final token = CancellationToken();

      final failure = expectLater(
        cacheManager.downloadFile(
          'https://a.test/image',
          cancellationToken: token,
        ),
        throwsA(isA<CancelledException>()),
      );
      await pumpEventQueue();
      token.cancel();
      await failure;
      expect(fileService.tokens.single!.isCancelled, isTrue);
    });
  });

  group('ImageCacheManager', () {
    test('getImageFile without resizing passes the token through', () async {
      final response = StreamingResponse();
      fileService.handler = (_) async => response;
      final cacheManager = TestImageCacheManager(config);
      final token = CancellationToken();

      final failure = expectLater(
        cacheManager
            .getImageFile('https://a.test/image', cancellationToken: token)
            .toList(),
        throwsA(isA<CancelledException>()),
      );
      await pumpEventQueue();
      token.cancel();
      await failure;
      expect(fileService.tokens.single!.isCancelled, isTrue);
    });

    test('a resize shared by two callers keeps running for the caller that '
        'did not cancel', () async {
      final response = StreamingResponse(fileExtension: '.png');
      fileService.handler = (_) async => response;
      final cacheManager = TestImageCacheManager(config);
      final token = CancellationToken();

      final a = cacheManager
          .getImageFile(
            'https://a.test/image',
            maxWidth: 10,
            cancellationToken: token,
          )
          .toList();
      final b = cacheManager
          .getImageFile('https://a.test/image', maxWidth: 10)
          .toList();
      final aFails = expectLater(a, throwsA(isA<CancelledException>()));
      await pumpEventQueue();

      token.cancel();
      await aFails;
      expect(fileService.tokens.single!.isCancelled, isFalse);

      response.controller.add(base64Decode(imagePng120));
      await response.controller.close();
      expect((await b).whereType<FileInfo>(), hasLength(1));
    });

    test('a resize stops its download once its only caller cancels', () async {
      final response = StreamingResponse(fileExtension: '.png');
      fileService.handler = (_) async => response;
      final cacheManager = TestImageCacheManager(config);
      final token = CancellationToken();

      final failure = expectLater(
        cacheManager
            .getImageFile(
              'https://a.test/image',
              maxWidth: 10,
              cancellationToken: token,
            )
            .toList(),
        throwsA(isA<CancelledException>()),
      );
      await pumpEventQueue();
      token.cancel();
      await failure;
      await pumpEventQueue();
      expect(fileService.tokens.single!.isCancelled, isTrue);
    });
  });
}

class TestImageCacheManager extends CacheManager with ImageCacheManager {
  TestImageCacheManager(super.config) : super.custom();
}

/// A file service whose responses the test controls. Records each request
/// and the [CancellationToken.current] it ran with.
class ControlledFileService extends FileService {
  final requests = <String>[];
  final tokens = <CancellationToken?>[];
  late Future<FileServiceResponse> Function(String url) handler;

  @override
  Future<FileServiceResponse> get(String url, {Map<String, String>? headers}) {
    requests.add(url);
    tokens.add(CancellationToken.current);
    return handler(url);
  }
}

class StreamingResponse implements FileServiceResponse {
  StreamingResponse({this.fileExtension = '.bin'}) {
    controller.onCancel = () => listenerCancelled = true;
  }

  final controller = StreamController<List<int>>();
  bool listenerCancelled = false;

  @override
  Stream<List<int>> get content => controller.stream;

  @override
  int? get contentLength => null;

  @override
  String? get eTag => null;

  @override
  final String fileExtension;

  @override
  int get statusCode => 200;

  @override
  DateTime get validTill => clock.now().add(const Duration(days: 1));
}
