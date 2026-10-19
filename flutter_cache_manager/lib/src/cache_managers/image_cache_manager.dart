import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:file/file.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

const supportedFileNames = ['jpg', 'jpeg', 'png', 'tga', 'cur', 'ico'];

/// Signatures (magic numbers) of the image formats that can be recognized by
/// the first bytes of the file, instead of by its extension.
///
/// Gif is deliberately missing: the resizer re-encodes to png, which would turn
/// an animation into a single frame.
const _imageSignatures = <List<int>>[
  [0xFF, 0xD8], // jpeg
  [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A], // png
  [0x42, 0x4D], // bmp
  [0x00, 0x00, 0x01, 0x00], // ico
  [0x00, 0x00, 0x02, 0x00], // cur
];

/// Extensions of the formats that have no usable signature at the start of the
/// file, so the only way to recognize them is by their extension. Tga only
/// stores a signature in its footer, and wbmp starts with a two byte header
/// (`00 00`) that is too generic to match on.
const _extensionOnlyFormats = ['tga', 'wbmp'];

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

  /// Whether [file] holds an image that can be decoded and resized, based on
  /// the content of the file rather than on the extension of its url. A
  /// response can be served without a file extension, or with an extension
  /// that does not match the actual content, for example when it is served
  /// with an incorrect `Content-Type` header.
  ///
  /// Images that would lose something when they are re-encoded as png, such as
  /// an animated gif or an animated webp, are not considered an image here, so
  /// they are passed through untouched.
  Future<bool> _isImage(File file) async {
    if (!await file.exists()) {
      return false;
    }

    final header = await _readHeader(file);
    if (_imageSignatures.any((signature) => _matches(header, signature))) {
      return true;
    }
    // WebP is a RIFF container: "RIFF" + 4 bytes of length + "WEBP".
    if (_matches(header, 'RIFF'.codeUnits) &&
        _matches(header, 'WEBP'.codeUnits, 8)) {
      return !_isAnimatedWebp(header);
    }
    final extension = file.path.split('.').last.toLowerCase();
    return _extensionOnlyFormats.contains(extension);
  }

  final Map<String, Stream<FileResponse>> _runningResizes = {};

  Future<FileInfo> _resizeImageFile(
    FileInfo originalFile,
    String key,
    int? maxWidth,
    int? maxHeight,
  ) async {
    if (!await _isImage(originalFile.file)) {
      return originalFile;
    }

    final image = await _decodeImage(originalFile.file);

    final shouldResize = maxWidth != null
        ? image.width > maxWidth
        : false || maxHeight != null
        ? image.height > maxHeight
        : false;
    if (!shouldResize) return originalFile;
    if (maxWidth != null && maxHeight != null) {
      final resizeFactorWidth = image.width / maxWidth;
      final resizeFactorHeight = image.height / maxHeight;
      final resizeFactor = max(resizeFactorHeight, resizeFactorWidth);

      maxWidth = (image.width / resizeFactor).round();
      maxHeight = (image.height / resizeFactor).round();
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
      // The resized image is always encoded as png. The extension of the
      // original file cannot be used: it is derived from the url, so it can
      // be missing, or be the last segment of the path when the url has no
      // extension at all.
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

/// Reads the first bytes of [file], up to [length] bytes, which is enough to
/// hold the longest signature that is checked, including the webp flags.
Future<List<int>> _readHeader(File file, {int length = 30}) async {
  final raf = await file.open();
  try {
    return await raf.read(length);
  } finally {
    await raf.close();
  }
}

/// Whether [bytes] holds [signature] at [offset].
bool _matches(List<int> bytes, List<int> signature, [int offset = 0]) {
  if (bytes.length < offset + signature.length) {
    return false;
  }
  for (var i = 0; i < signature.length; i++) {
    if (bytes[offset + i] != signature[i]) {
      return false;
    }
  }
  return true;
}

/// Whether [header] belongs to a webp that contains an animation.
///
/// An extended webp starts with a `VP8X` chunk, whose flags byte marks the file
/// as animated. Resizing re-encodes the image to png, which keeps a single
/// frame, so an animated webp is left as it is, the same way gif is.
bool _isAnimatedWebp(List<int> header) {
  // "RIFF" + size + "WEBP" + "VP8X" + chunk size, the flags follow at 20.
  const flagsOffset = 20;
  const animationFlag = 0x02;
  return header.length > flagsOffset &&
      _matches(header, 'VP8X'.codeUnits, 12) &&
      (header[flagsOffset] & animationFlag) != 0;
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
