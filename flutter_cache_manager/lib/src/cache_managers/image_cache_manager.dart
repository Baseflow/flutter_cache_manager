import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/foundation.dart';
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
      runningResize = _trackResizeStream(
        resizedKey,
        _fetchedResizedFile(
          url,
          key,
          resizedKey,
          headers,
          withProgress,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        ),
      );
      _runningResizes[resizedKey] = runningResize;
    }
    yield* runningResize;
  }

  final Map<String, Stream<FileResponse>> _runningResizes = {};

  /// Keys whose original file is known not to be resizable: it is not an
  /// image the engine can decode, it is animated, or it already fits within
  /// the requested size. Probing a file reads it and decodes a frame, so the
  /// outcome is remembered to avoid repeating that work on every call.
  ///
  /// The entries are not invalidated when the original file is re-downloaded
  /// with different content; they are reset when a resize does succeed or
  /// when the manager instance is recreated.
  final Set<String> _notResizableKeys = {};

  Stream<FileResponse> _trackResizeStream(
    String resizedKey,
    Stream<FileResponse> stream,
  ) {
    // Clear the in-flight entry on both success and error so failures can be
    // retried by a later request.
    late final Stream<FileResponse> trackedStream;
    trackedStream = stream
        .transform(
          StreamTransformer<FileResponse, FileResponse>.fromHandlers(
            handleError: (Object error, StackTrace stackTrace, sink) {
              if (identical(_runningResizes[resizedKey], trackedStream)) {
                _runningResizes.remove(resizedKey);
              }
              sink.addError(error, stackTrace);
            },
            handleDone: (sink) {
              if (identical(_runningResizes[resizedKey], trackedStream)) {
                _runningResizes.remove(resizedKey);
              }
              sink.close();
            },
          ),
        )
        .asBroadcastStream();
    return trackedStream;
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
        if (_notResizableKeys.contains(resizedKey)) {
          yield response;
        } else {
          yield await _resizeImageFile(
            response,
            resizedKey,
            maxWidth: maxWidth,
            maxHeight: maxHeight,
          );
        }
      }
    }
  }

  Future<FileInfo> _resizeImageFile(
    FileInfo originalFile,
    String resizedKey, {
    int? maxWidth,
    int? maxHeight,
  }) async {
    final file = originalFile.file;
    final probe = await _probeImage(file);
    if (probe == null) {
      return _notResizable(originalFile, resizedKey);
    }
    final (descriptor, frameCount, imageWidth, imageHeight) = probe;

    // Resizing re-encodes the image as png, which keeps a single frame, so
    // animated images (gif, apng, animated webp, ...) are passed through
    // untouched.
    if (frameCount > 1) {
      descriptor.dispose();
      return _notResizable(originalFile, resizedKey);
    }

    final shouldResize =
        (maxWidth != null && imageWidth > maxWidth) ||
        (maxHeight != null && imageHeight > maxHeight);
    if (!shouldResize) {
      descriptor.dispose();
      return _notResizable(originalFile, resizedKey);
    }

    if (maxWidth != null && maxHeight != null) {
      final resizeFactorWidth = imageWidth / maxWidth;
      final resizeFactorHeight = imageHeight / maxHeight;
      final resizeFactor = max(resizeFactorHeight, resizeFactorWidth);

      maxWidth = (imageWidth / resizeFactor).round();
      maxHeight = (imageHeight / resizeFactor).round();
    }

    try {
      final resizedFile = await _decodeResized(
        descriptor,
        width: maxWidth,
        height: maxHeight,
      );
      final maxAge = originalFile.validTill.difference(DateTime.now());

      final resized = await putFile(
        originalFile.originalUrl,
        resizedFile,
        key: resizedKey,
        maxAge: maxAge,
        // The resized image is always encoded as png, so it is stored with a
        // png extension. The extension of the original file cannot be reused:
        // it comes from the Content-Type header of the response, which can be
        // something generic like `application/octet-stream` instead of the
        // format the image is actually encoded in.
        fileExtension: 'png',
      );

      _notResizableKeys.remove(resizedKey);
      return FileInfo(
        resized,
        originalFile.source,
        originalFile.validTill,
        originalFile.originalUrl,
      );
    } on Object catch (error) {
      _logResizeWarning(file, error);
      return _notResizable(originalFile, resizedKey);
    } finally {
      descriptor.dispose();
    }
  }

  /// Remembers that the file of [originalFile] does not need to be probed
  /// again for [resizedKey] and returns it untouched.
  FileInfo _notResizable(FileInfo originalFile, String resizedKey) {
    if (_notResizableKeys.length > 512) _notResizableKeys.clear();
    _notResizableKeys.add(resizedKey);
    return originalFile;
  }
}

/// Probes [file] with the image engine.
///
/// Returns the encoded image descriptor together with its frame count and
/// size, or `null` when the engine cannot decode the file. Whether a file is
/// a resizable image is decided entirely by the engine: it knows every format
/// Flutter can decode, including platform specific ones like heif, so there
/// is no list of signatures or extensions to maintain.
///
/// The returned descriptor is not disposed and has to be disposed by the
/// caller; it can be used to decode a resized frame without reading the file
/// again. When `null` is returned everything is cleaned up here.
Future<(ui.ImageDescriptor, int frameCount, int width, int height)?>
_probeImage(File file) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  try {
    buffer = await _bufferFor(file);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    codec = await descriptor.instantiateCodec();
    final frameCount = codec.frameCount;
    int width;
    int height;
    if (kIsWeb) {
      // `descriptor.width` and `descriptor.height` are not supported on web
      // (they throw), so the size is taken from the first frame. This fully
      // decodes that frame, which is only paid on web.
      final frame = await codec.getNextFrame();
      width = frame.image.width;
      height = frame.image.height;
      frame.image.dispose();
    } else {
      width = descriptor.width;
      height = descriptor.height;
    }
    return (descriptor, frameCount, width, height);
  } on Object catch (error) {
    descriptor?.dispose();
    _logResizeWarning(file, error);
    return null;
  } finally {
    codec?.dispose();
    buffer?.dispose();
  }
}

/// Creates the buffer for [file].
///
/// The path is only used when the file is known to be backed by the real file
/// system: `ImmutableBuffer.fromFilePath` reads `file.path` directly from
/// disk, which would bypass a custom `Config.fileSystem` whose bytes might
/// not be readable at their path (encrypted or in-memory file systems). On
/// web there is no file path to read from either.
Future<ui.ImmutableBuffer> _bufferFor(File file) async {
  if (!kIsWeb && file.fileSystem is LocalFileSystem) {
    return ui.ImmutableBuffer.fromFilePath(file.path);
  }
  return ui.ImmutableBuffer.fromUint8List(await file.readAsBytes());
}

/// Decodes the image described by [descriptor] into a png-encoded
/// [Uint8List] that fits within [width] and [height].
///
/// Decoding with a target size straight from the descriptor reads the file
/// once; no separate resize provider is needed.
Future<Uint8List> _decodeResized(
  ui.ImageDescriptor descriptor, {
  int? width,
  int? height,
}) async {
  final codec = await descriptor.instantiateCodec(
    targetWidth: width,
    targetHeight: height,
  );
  final frame = await codec.getNextFrame();
  try {
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    frame.image.dispose();
    codec.dispose();
  }
}

void _logResizeWarning(File file, Object error) {
  cacheLogger.log(
    'ImageCacheManager: could not resize "${file.path}", '
    'returning the original file ($error)',
    CacheManagerLogLevel.warning,
  );
}
