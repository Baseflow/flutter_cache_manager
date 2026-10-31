import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:file/file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Formats that used to be recognized by the extension of the file.
///
/// Whether a file can be resized is now decided by the image engine, based on
/// the content of the file, so this list no longer reflects which files are
/// resized. It is kept only for backwards compatibility.
@Deprecated(
  'Image formats are detected from the file content instead of the file '
  'extension. This list is no longer used and will be removed in a future '
  'version.',
)
const supportedFileNames = ['jpg', 'jpeg', 'png', 'tga', 'cur', 'ico'];

mixin ImageCacheManager on BaseCacheManager {
  /// Returns a resized image file to fit within maxHeight and maxWidth. It
  /// tries to keep the aspect ratio. It stores the resized image by adding
  /// the size to the key or url. For example when resizing
  /// https://via.placeholder.com/150 to max width 100 and height 75 it will
  /// store it with cacheKey resized_w100_h75_https://via.placeholder.com/150.
  ///
  /// When the resized file is not found in the cache the original is fetched
  /// from the cache or online and stored in the cache. Then it is resized
  /// and returned to the caller.
  Stream<FileResponse> getImageFile(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
    int? maxHeight,
    int? maxWidth,
  }) async* {
    if (maxHeight == null && maxWidth == null) {
      yield* getFileStream(
        url,
        key: key,
        headers: headers,
        withProgress: withProgress,
      );
      return;
    }
    key ??= url;
    var resizedKey = 'resized';
    if (maxWidth != null) resizedKey += '_w$maxWidth';
    if (maxHeight != null) resizedKey += '_h$maxHeight';
    resizedKey += '_$key';

    final fromCache = await getFileFromCache(resizedKey);
    if (fromCache != null) {
      yield fromCache;
      if (fromCache.validTill.isAfter(DateTime.now())) {
        return;
      }
      withProgress = false;
    }
    var runningResize = _runningResizes[resizedKey];
    if (runningResize == null) {
      runningResize = _fetchedResizedFile(
        url,
        key,
        resizedKey,
        headers,
        withProgress,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      ).asBroadcastStream();
      _runningResizes[resizedKey] = runningResize;
    }
    yield* runningResize;
    _runningResizes.remove(resizedKey);
  }

  final Map<String, Stream<FileResponse>> _runningResizes = {};

  Future<FileInfo> _resizeImageFile(
    FileInfo originalFile,
    String key,
    int? maxWidth,
    int? maxHeight,
  ) async {
    final info = await _imageInfo(originalFile.file);
    if (info == null) {
      // The engine cannot decode this file, so it is not a resizable image.
      // The original file is returned untouched instead of erroring the
      // stream.
      return originalFile;
    }
    final (frameCount, imageWidth, imageHeight) = info;

    // Resizing re-encodes the image as png, which keeps a single frame, so
    // animated images (gif, apng, animated webp, ...) are passed through
    // untouched.
    if (frameCount > 1) {
      return originalFile;
    }

    final shouldResize =
        (maxWidth != null && imageWidth > maxWidth) ||
        (maxHeight != null && imageHeight > maxHeight);
    if (!shouldResize) return originalFile;
    if (maxWidth != null && maxHeight != null) {
      final resizeFactorWidth = imageWidth / maxWidth;
      final resizeFactorHeight = imageHeight / maxHeight;
      final resizeFactor = max(resizeFactorHeight, resizeFactorWidth);

      maxWidth = (imageWidth / resizeFactor).round();
      maxHeight = (imageHeight / resizeFactor).round();
    }

    final resized = await _decodeImage(
      originalFile.file,
      width: maxWidth,
      height: maxHeight,
    );
    final resizedFile = (await resized.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    final maxAge = originalFile.validTill.difference(DateTime.now());

    final file = await putFile(
      originalFile.originalUrl,
      resizedFile,
      key: key,
      maxAge: maxAge,
      // The resized image is always encoded as png, so it is stored with a
      // png extension. The extension of the original file cannot be reused:
      // it comes from the Content-Type header of the response, which can be
      // something generic like `application/octet-stream` instead of the
      // format the image is actually encoded in.
      fileExtension: 'png',
    );

    return FileInfo(
      file,
      originalFile.source,
      originalFile.validTill,
      originalFile.originalUrl,
    );
  }

  Stream<FileResponse> _fetchedResizedFile(
    String url,
    String originalKey,
    String resizedKey,
    Map<String, String>? headers,
    bool withProgress, {
    int? maxWidth,
    int? maxHeight,
  }) async* {
    await for (final response in getFileStream(
      url,
      key: originalKey,
      headers: headers,
      withProgress: withProgress,
    )) {
      if (response is DownloadProgress) {
        yield response;
      }
      if (response is FileInfo) {
        yield await _resizeImageFile(response, resizedKey, maxWidth, maxHeight);
      }
    }
  }
}

/// Describes the image in [file], or `null` when the engine cannot decode it.
///
/// Whether a file is a resizable image is decided entirely by the engine: it
/// knows every format Flutter can decode, including platform specific ones
/// like heif, so there is no list of signatures or extensions to maintain.
/// The returned record holds the frame count of the image, which is how
/// animated images are recognized, and its width and height.
Future<(int frameCount, int width, int height)?> _imageInfo(File file) async {
  if (!await file.exists()) {
    return null;
  }
  final buffer = await _bufferFor(file);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    codec = await descriptor.instantiateCodec();
    // `descriptor.width` and `descriptor.height` are not supported on web
    // (they throw), so the size is taken from the first frame instead. This
    // fully decodes that frame, which costs the same as the decode the
    // resize performs anyway.
    final frame = await codec.getNextFrame();
    try {
      return (codec.frameCount, frame.image.width, frame.image.height);
    } finally {
      frame.image.dispose();
    }
  } on Object {
    return null;
  } finally {
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}

/// Creates the buffer for [file].
///
/// On web there is no file path to read from, so the bytes are read into
/// memory. On IO the path is preferred, so the bytes are not copied into
/// memory before we know whether the file is an image at all (it can be a
/// large video or pdf). Tests run against a mocked file system where the
/// path does not exist on the real file system, so reading the bytes is the
/// fallback there.
Future<ui.ImmutableBuffer> _bufferFor(File file) async {
  if (kIsWeb) {
    return ui.ImmutableBuffer.fromUint8List(await file.readAsBytes());
  }
  try {
    return await ui.ImmutableBuffer.fromFilePath(file.path);
  } on Object {
    return ui.ImmutableBuffer.fromUint8List(await file.readAsBytes());
  }
}

Future<ui.Image> _decodeImage(
  File file, {
  int? width,
  int? height,
  bool allowUpscaling = false,
}) {
  final shouldResize = width != null || height != null;
  final fileImage = FileImage(file);
  final image = shouldResize
      ? ResizeImage(
          fileImage,
          width: width,
          height: height,
          allowUpscaling: allowUpscaling,
        )
      : fileImage as ImageProvider;

  final completer = Completer<ui.Image>();
  final stream = image.resolve(ImageConfiguration.empty);

  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      if (completer.isCompleted) return;

      stream.removeListener(listener);
      image.evict();
      completer.complete(info.image);
    },
    onError: (Object error, StackTrace? stackTrace) {
      if (completer.isCompleted) return;

      stream.removeListener(listener);
      completer.completeError(error, stackTrace);
    },
  );

  stream.addListener(listener);
  return completer.future;
}
