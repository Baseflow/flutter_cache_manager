import 'dart:ui';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_cache_manager/src/cache_store.dart';
import 'package:flutter_cache_manager/src/storage/cache_object.dart';
import 'package:flutter_cache_manager/src/web/web_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  group('Test status codes', () {
    test('200 is OK', () async {
      const imageUrl = 'baseflow.com/testimage';

      var fileDir = MemoryFileSystem().systemTempDirectory;
      final store = _createStore(fileDir);

      final fileService = MockFileService();
      when(fileService.get(imageUrl, headers: anyNamed('headers')))
          .thenAnswer((_) {
        return Future.value(MockFileFetcherResponse(
            Stream.value([0, 1, 2, 3, 4, 5]),
            0,
            'testv1',
            '.jpg',
            200,
            DateTime.now()));
      });

      var webHelper = WebHelper(store, fileService);
      var result = await webHelper
          .downloadFile(imageUrl)
          .firstWhere((r) => r is FileInfo, orElse: null);
      expect(result, isNotNull);
    });

    test('200 needs content', () async {
      const imageUrl = 'baseflow.com/testimage';

      var fileDir = MemoryFileSystem().systemTempDirectory;
      final store = _createStore(fileDir);

      final fileService = MockFileService();
      when(fileService.get(imageUrl, headers: anyNamed('headers')))
          .thenAnswer((_) {
        return Future.value(MockFileFetcherResponse(
            null, 0, 'testv1', '.jpg', 200, DateTime.now()));
      });

      var webHelper = WebHelper(store, fileService);
      expect(() async => webHelper.downloadFile(imageUrl).toList(),
          throwsA(anything));
    });

    test('404 throws', () async {
      const imageUrl = 'baseflow.com/testimage';

      var fileDir = MemoryFileSystem().systemTempDirectory;
      final store = _createStore(fileDir);

      final fileService = MockFileService();
      when(fileService.get(imageUrl, headers: anyNamed('headers')))
          .thenAnswer((_) {
        return Future.value(
            MockFileFetcherResponse(null, 0, null, '', 404, DateTime.now()));
      });

      var webHelper = WebHelper(store, fileService);

      expect(
          () async => webHelper.downloadFile(imageUrl).toList(),
          throwsA(predicate(
              (e) => e is HttpExceptionWithStatus && e.statusCode == 404)));
    });

    test('304 ignores content', () async {
      const imageUrl = 'baseflow.com/testimage';

      var fileDir = MemoryFileSystem().systemTempDirectory;
      final store = _createStore(fileDir);

      final fileService = MockFileService();
      when(fileService.get(imageUrl, headers: anyNamed('headers')))
          .thenAnswer((_) {
        return Future.value(MockFileFetcherResponse(
            null, 0, 'testv1', '.jpg', 304, DateTime.now()));
      });

      var webHelper = WebHelper(store, fileService);
      var result = await webHelper.downloadFile(imageUrl).firstWhere((r) => r is FileInfo, orElse: null);
      expect(result, isNotNull);
    });
  });

  group('Parallel logic', () {
    test('Calling webhelper twice excecutes once', () async {
      const imageUrl = 'baseflow.com/testimage';

      var fileDir = MemoryFileSystem().systemTempDirectory;
      final store = _createStore(fileDir);

      final fileService = MockFileService();
      when(fileService.get(imageUrl, headers: anyNamed('headers')))
          .thenAnswer((_) {
        return Future.value(MockFileFetcherResponse(
            Stream.value([0, 1, 2, 3, 4, 5]),
            6,
            'testv1',
            '.jpg',
            200,
            DateTime.now()));
      });

      var webHelper = WebHelper(store, fileService);

      var call1 = webHelper.downloadFile(imageUrl).toList();
      var call2 = webHelper.downloadFile(imageUrl).toList();
      await Future.wait([call1, call2]);

      verify(store.retrieveCacheData(any)).called(1);
    });

    test('Calling webhelper twice excecutes twice when memcache ignored',
        () async {
      const imageUrl = 'baseflow.com/testimage';

      var fileDir = MemoryFileSystem().systemTempDirectory;
      final store = _createStore(fileDir);

      final fileService = MockFileService();
      when(fileService.get(imageUrl, headers: anyNamed('headers')))
          .thenAnswer((_) {
        return Future.value(MockFileFetcherResponse(
            Stream.value([0, 1, 2, 3, 4, 5]),
            6,
            'testv1',
            '.jpg',
            200,
            DateTime.now()));
      });

      var webHelper = WebHelper(store, fileService);
      var call1 = webHelper.downloadFile(imageUrl).toList();
      var call2 =
          webHelper.downloadFile(imageUrl, ignoreMemCache: true).toList();
      await Future.wait([call1, call2]);

      verify(store.retrieveCacheData(any)).called(2);
    });
  });

  group('Miscellaneous', () {
    test('When not yet cached, new cacheobject should be made', () async {
      const imageUrl = 'baseflow.com/testimage';

      var fileDir = MemoryFileSystem().systemTempDirectory;
      final store = _createStore(fileDir);
      when(store.retrieveCacheData(imageUrl))
          .thenAnswer((_) => Future.value(null));

      final fileService = MockFileService();
      when(fileService.get(imageUrl, headers: anyNamed('headers')))
          .thenAnswer((_) {
        return Future.value(MockFileFetcherResponse(
            Stream.value([0, 1, 2, 3, 4, 5]),
            6,
            'testv1',
            '.jpg',
            200,
            DateTime.now()));
      });

      var webHelper = WebHelper(store, fileService);
      var result = await webHelper.downloadFile(imageUrl).firstWhere((r) => r is FileInfo, orElse: null);
      expect(result, isNotNull);
      verify(store.putFile(any)).called(1);
    });

    test('File should be removed if extension changed', () async {
      const imageUrl = 'baseflow.com/testimage';

      var imageName = 'image.png';
      var fileDir = MemoryFileSystem().systemTempDirectory;
      var file = fileDir.childFile(imageName);
      await file.create();

      final store = _createStore(fileDir);
      when(store.retrieveCacheData(imageUrl)).thenAnswer(
          (_) => Future.value(CacheObject(imageUrl, relativePath: imageName)));

      final fileService = MockFileService();
      when(fileService.get(imageUrl, headers: anyNamed('headers')))
          .thenAnswer((_) {
        return Future.value(MockFileFetcherResponse(
            Stream.value([0, 1, 2, 3, 4, 5]),
            6,
            'testv1',
            '.jpg',
            200,
            DateTime.now()));
      });

      var webHelper = WebHelper(store, fileService);

      expect(await file.exists(), true);
      var _ = await webHelper.downloadFile(imageUrl).firstWhere((r) => r is FileInfo, orElse: null);
      expect(await file.exists(), false);
    });
  });
}

MockStore _createStore(Directory fileDir) {
  final store = MockStore();
  when(store.putFile(argThat(anything)))
      .thenAnswer((_) => Future.value(VoidCallback));
  when(store.fileDir).thenAnswer((_) => Future.value(fileDir));
  when(store.retrieveCacheData(argThat(anything))).thenAnswer((invocation) =>
      Future.value(
          CacheObject(invocation.positionalArguments.first as String)));
  return store;
}

class MockStore extends Mock implements CacheStore {}

class MockFileService extends Mock implements FileService {}

class MockFileFetcherResponse implements FileServiceGetResponse {
  final Stream<List<int>> _content;
  final int _contentLength;
  final String _eTag;
  final String _fileExtension;
  final int _statusCode;
  final DateTime _validTill;

  MockFileFetcherResponse(this._content, this._contentLength, this._eTag,
      this._fileExtension, this._statusCode, this._validTill);

  @override
  Stream<List<int>> get content => _content;

  @override
  // TODO: implement eTag
  String get eTag => _eTag;

  @override
  // TODO: implement fileExtension
  String get fileExtension => _fileExtension;

  @override
  // TODO: implement statusCode
  int get statusCode => _statusCode;

  @override
  // TODO: implement validTill
  DateTime get validTill => _validTill;

  @override
  // TODO: implement contentLength
  int get contentLength => _contentLength;
}
