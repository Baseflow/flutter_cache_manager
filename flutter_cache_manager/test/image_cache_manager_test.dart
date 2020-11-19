import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'cache_manager_test.dart';
import 'helpers/config_extensions.dart';

import 'helpers/test_configuration.dart';

const fileName = 'test.jpg';
const fileUrl = 'baseflow.com/test';
void main() {
  group('Test image resizing', () {
    test('Test original image size', () async {
      final bytes = await getExampleImage();
      await verifySize(bytes, 120, 120);
    });

    test('File should not be modified when no height or width is given',
        () async {
      var cacheManager = await setupCacheManager();
      var result = await cacheManager.getImageFile(fileUrl).last as FileInfo;
      var image = await result.file.readAsBytes();
      await verifySize(image, 120, 120);
    });

    test('File should not be modified when height is given', () async {
      var cacheManager = await setupCacheManager();
      var result = await cacheManager
          .getImageFile(
            fileUrl,
            maxHeight: 100,
          )
          .last as FileInfo;
      var image = await result.file.readAsBytes();
      await verifySize(image, 100, 100);
    });

    test('File should not be modified when width is given', () async {
      var cacheManager = await setupCacheManager();
      var result = await cacheManager
          .getImageFile(
            fileUrl,
            maxWidth: 100,
          )
          .last as FileInfo;
      var image = await result.file.readAsBytes();
      await verifySize(image, 100, 100);
    });

    test('File should keep aspect ratio when both height and width are given',
        () async {
      var cacheManager = await setupCacheManager();
      var result = await cacheManager
          .getImageFile(fileUrl, maxWidth: 100, maxHeight: 80)
          .last as FileInfo;
      var image = await result.file.readAsBytes();
      await verifySize(image, 80, 80);
    });
  });
}

Future<TestCacheManager> setupCacheManager() async {
  var validTill = DateTime.now().add(const Duration(days: 1));
  var config = createTestConfig();
  await config.returnsFile(fileName, data: await getExampleImage());
  config.returnsCacheObject(fileUrl, fileName, validTill);
  return TestCacheManager(config);
}

Future verifySize(
  Uint8List image,
  int expectedWidth,
  int expectedHeight,
) async {
  var codec = await instantiateImageCodec(image);
  var frame = await codec.getNextFrame();
  var height = frame.image.height;
  var width = frame.image.width;
  expect(width, expectedWidth);
  expect(height, expectedHeight);
}

Future<Uint8List> getExampleImage() {
  return File('test/images/image-120.png').readAsBytes();
}
