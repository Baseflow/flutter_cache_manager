import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_cache_manager/src/config/config.dart';
import 'package:flutter_cache_manager/src/web/file_service.dart';
import 'package:mockito/mockito.dart';

class MockFileService extends Mock implements FileService {
  MockFileService._();
  factory MockFileService(){
    var fileService = MockFileService._();
    when(fileService.get(any, headers: anyNamed('headers')))
        .thenAnswer((realInvocation) async {
          return TestResponse();
        });
    return fileService;
  }
}

class TestResponse extends FileServiceResponse{
  @override
  Stream<List<int>> get content => const Stream.empty();

  @override
  int get contentLength => 0;

  @override
  String get eTag => 'test';

  @override
  String get fileExtension => 'jpg';

  @override
  int get statusCode => 200;

  @override
  DateTime get validTill => DateTime.now();

}