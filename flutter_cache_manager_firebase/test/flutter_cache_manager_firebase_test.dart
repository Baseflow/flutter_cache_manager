import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_cache_manager_firebase/flutter_cache_manager_firebase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fcm_firebase_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          return tempDir.path;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('FirebaseCacheManager key is set', () {
    expect(FirebaseCacheManager.key, 'firebaseCache');
  });

  test('FirebaseCacheManager returns separate instances per bucket', () {
    final bucketA = FirebaseCacheManager(bucket: 'bucket-a');
    final bucketAAgain = FirebaseCacheManager(bucket: 'bucket-a');
    final bucketB = FirebaseCacheManager(bucket: 'bucket-b');
    final defaultInstance = FirebaseCacheManager();

    expect(identical(bucketA, bucketAAgain), isTrue);
    expect(identical(bucketA, bucketB), isFalse);
    expect(identical(bucketA, defaultInstance), isFalse);

    expect(bucketA.config.cacheKey, 'bucket-a');
    expect(
      (bucketA.config.fileService as FirebaseHttpFileService).bucket,
      'bucket-a',
    );
    expect(bucketB.config.cacheKey, 'bucket-b');
    expect(
      (bucketB.config.fileService as FirebaseHttpFileService).bucket,
      'bucket-b',
    );
    expect(defaultInstance.config.cacheKey, FirebaseCacheManager.key);
    expect(
      (defaultInstance.config.fileService as FirebaseHttpFileService).bucket,
      isNull,
    );
  });
}
