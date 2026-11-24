import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cache_manager_test.dart';
import 'helpers/config_extensions.dart';
import 'helpers/test_configuration.dart';
import 'test_images.dart';

const fileName = 'test.jpg';
const fileUrl = 'baseflow.com/test';
final validTill = DateTime.now().add(const Duration(days: 1));

void main() {
  setUp(WidgetsFlutterBinding.ensureInitialized);

  tearDown(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  group('Test image resizing', () {
    test('Test original image size', () async {
      final bytes = exampleImage;
      await verifySize(bytes, 120, 120);
    });

    test(
      'File should not be modified when no height or width is given',
      () async {
        var cacheManager = await setupCacheManager();
        var result = await cacheManager.getImageFile(fileUrl).last as FileInfo;
        var image = await result.file.readAsBytes();
        await verifySize(image, 120, 120);
      },
    );

    test('File should not be modified when height is given', () async {
      var cacheManager = await setupCacheManager();
      var result =
          await cacheManager.getImageFile(fileUrl, maxHeight: 100).last
              as FileInfo;
      var image = await result.file.readAsBytes();
      await verifySize(image, 100, 100);
    });

    test('File should not be modified when width is given', () async {
      var cacheManager = await setupCacheManager();
      var result =
          await cacheManager.getImageFile(fileUrl, maxWidth: 100).last
              as FileInfo;
      var image = await result.file.readAsBytes();
      await verifySize(image, 100, 100);
    });

    test(
      'File should keep aspect ratio when both height and width are given',
      () async {
        var cacheManager = await setupCacheManager();
        var result =
            await cacheManager
                    .getImageFile(fileUrl, maxWidth: 100, maxHeight: 80)
                    .last
                as FileInfo;
        var image = await result.file.readAsBytes();
        await verifySize(image, 80, 80);
      },
    );
  });
  group('Test resized image caching', () {
    test('Resized image should be fetched from cache', () async {
      var config = await setupConfig(cacheKey: 'resized_w100_h80_$fileUrl');
      var cacheManager = TestCacheManager(config);
      var result =
          await cacheManager
                  .getImageFile(fileUrl, maxWidth: 100, maxHeight: 80)
                  .last
              as FileInfo;

      expect(result, isNotNull);
      config.verifyNoDownloadCall();
    });

    test('Unsized image should be fetched from cache', () async {
      var config = await setupConfig();
      config.returnsCacheObject(fileUrl, fileName, validTill);
      var cacheManager = TestCacheManager(config);
      var result =
          await cacheManager
                  .getImageFile(fileUrl, maxWidth: 100, maxHeight: 80)
                  .last
              as FileInfo;

      expect(result, isNotNull);
      config.verifyNoDownloadCall();
    });

    test('Wrongly sized image should not be fetched from cache', () async {
      var config = await setupConfig(cacheKey: 'resized_w100_h150_$fileUrl');
      var cacheManager = TestCacheManager(config);
      var result =
          await cacheManager
                  .getImageFile(fileUrl, maxWidth: 100, maxHeight: 80)
                  .last
              as FileInfo;

      expect(result, isNotNull);
      config.verifyDownloadCall();
    });

    test('Downloads should give progress', () async {
      var config = await setupConfig(cacheKey: 'resized_w100_h150_$fileUrl');
      var cacheManager = TestCacheManager(config);
      var results = await cacheManager
          .getImageFile(
            fileUrl,
            maxWidth: 100,
            maxHeight: 80,
            withProgress: true,
          )
          .toList();
      var progress = results.whereType<DownloadProgress>().toList();
      config.verifyDownloadCall();
      expect(progress, isNotEmpty);
    });
  });

  group('Test image detection', () {
    test('Image without file extension should be resized', () async {
      const urlWithoutExtension = 'baseflow.com/avatar/123456';
      var config = createTestConfig();
      await config.returnsFile('avatar', data: exampleImage);
      config.returnsCacheObject(urlWithoutExtension, 'avatar', validTill);

      var cacheManager = TestCacheManager(config);
      var result =
          await cacheManager
                  .getImageFile(urlWithoutExtension, maxWidth: 100)
                  .last
              as FileInfo;

      var image = await result.file.readAsBytes();
      await verifySize(image, 100, 100);
    });

    test('Image with a non-image extension should be resized', () async {
      // The stored file's extension does not come from the url, but from the
      // Content-Type header of the response. A generic type such as
      // application/octet-stream stores the file as .bin, even when the
      // payload is an image.
      const urlWithBinaryExtension = 'baseflow.com/image.bin';
      var config = createTestConfig();
      await config.returnsFile('image.bin', data: exampleImage);
      config.returnsCacheObject(urlWithBinaryExtension, 'image.bin', validTill);

      var cacheManager = TestCacheManager(config);
      var result =
          await cacheManager
                  .getImageFile(urlWithBinaryExtension, maxWidth: 100)
                  .last
              as FileInfo;

      var image = await result.file.readAsBytes();
      await verifySize(image, 100, 100);
      expect(result.file.path.endsWith('.png'), isTrue);
    });

    test('Static webp should be resized', () async {
      const urlWithWebpExtension = 'baseflow.com/image.webp';
      var config = createTestConfig();
      await config.returnsFile('image.webp', data: exampleWebp);
      config.returnsCacheObject(urlWithWebpExtension, 'image.webp', validTill);

      var cacheManager = TestCacheManager(config);
      var result =
          await cacheManager
                  .getImageFile(urlWithWebpExtension, maxWidth: 100)
                  .last
              as FileInfo;

      var image = await result.file.readAsBytes();
      await verifySize(image, 100, 100);
    });

    test('Bmp should be resized', () async {
      const urlWithBmpExtension = 'baseflow.com/image.bmp';
      var config = createTestConfig();
      await config.returnsFile('image.bmp', data: exampleBmp);
      config.returnsCacheObject(urlWithBmpExtension, 'image.bmp', validTill);

      var cacheManager = TestCacheManager(config);
      var result =
          await cacheManager
                  .getImageFile(urlWithBmpExtension, maxWidth: 100)
                  .last
              as FileInfo;

      var image = await result.file.readAsBytes();
      await verifySize(image, 100, 100);
    });

    test('Non image should not be resized', () async {
      const urlWithImageExtension = 'baseflow.com/image.png';
      var payload = utf8.encode('{"message":"not an image"}');
      var config = createTestConfig();
      await config.returnsFile('image.png', data: payload);
      config.returnsCacheObject(urlWithImageExtension, 'image.png', validTill);

      var cacheManager = TestCacheManager(config);
      var result =
          await cacheManager
                  .getImageFile(urlWithImageExtension, maxWidth: 100)
                  .last
              as FileInfo;

      expect(await result.file.readAsBytes(), payload);
    });

    test('Animated gif should not be resized', () async {
      const urlOfAnimatedGif = 'baseflow.com/animation.gif';
      var payload = animatedGif;
      var config = createTestConfig();
      await config.returnsFile('animation.gif', data: payload);
      config.returnsCacheObject(urlOfAnimatedGif, 'animation.gif', validTill);

      var cacheManager = TestCacheManager(config);
      var result =
          await cacheManager.getImageFile(urlOfAnimatedGif, maxWidth: 100).last
              as FileInfo;

      expect(await result.file.readAsBytes(), payload);
    });

    test('Animated webp should not be resized', () async {
      const urlOfAnimatedWebp = 'baseflow.com/animation.webp';
      var payload = animatedWebp;
      var config = createTestConfig();
      await config.returnsFile('animation.webp', data: payload);
      config.returnsCacheObject(urlOfAnimatedWebp, 'animation.webp', validTill);

      var cacheManager = TestCacheManager(config);
      var result =
          await cacheManager.getImageFile(urlOfAnimatedWebp, maxWidth: 100).last
              as FileInfo;

      expect(await result.file.readAsBytes(), payload);
    });

    test('Animated png should not be resized', () async {
      const urlOfAnimatedPng = 'baseflow.com/animation.png';
      var payload = animatedApng;
      var config = createTestConfig();
      await config.returnsFile('animation.png', data: payload);
      config.returnsCacheObject(urlOfAnimatedPng, 'animation.png', validTill);

      var cacheManager = TestCacheManager(config);
      var result =
          await cacheManager.getImageFile(urlOfAnimatedPng, maxWidth: 100).last
              as FileInfo;

      expect(await result.file.readAsBytes(), payload);
    });
  });
}

Future<TestCacheManager> setupCacheManager() async {
  return TestCacheManager(await setupConfig());
}

Future<Config> setupConfig({String? cacheKey}) async {
  var validTill = DateTime.now().add(const Duration(days: 1));
  var config = createTestConfig();
  await config.returnsFile(fileName, data: exampleImage);
  config.returnsCacheObject(fileUrl, fileName, validTill, key: cacheKey);
  return config;
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

final Uint8List exampleImage = base64Decode(imagePng120);
final Uint8List exampleWebp = base64Decode(imageWebp120);
final Uint8List exampleBmp = base64Decode(imageBmp120);
final Uint8List animatedGif = base64Decode(animatedGif120);
final Uint8List animatedWebp = base64Decode(animatedWebp120);
final Uint8List animatedApng = base64Decode(animatedApng120);
