import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_cache_manager/src/web/interlaced/progressive_jpeg_decoder.dart';

class InterlacedData {
  final Uint8List data;
  InterlacedData(this.data);
}

class InterlacedConverter extends Converter<List<int>, InterlacedData> {
  const InterlacedConverter();

  @override
  InterlacedData convert(List<int> input) =>
      InterlacedData(Uint8List.fromList(input));

  @override
  Sink<Uint8List> startChunkedConversion(Sink<InterlacedData> sink) =>
      InterlacedByteConversionSink(sink);
}

class InterlacedByteConversionSink implements ChunkedConversionSink<Uint8List> {
  final Sink<InterlacedData> _output;

  // Buffer to accumulate chunks
  BytesBuilder? _buffer = BytesBuilder();

  InterlacedDecoder? _decoder;

  InterlacedByteConversionSink(this._output);

  @override
  void add(List<int> chunk) {
    // Ensure buffer is not null (should not happen in normal flow)
    final buffer = _buffer;
    if (buffer == null) {
      throw StateError('Sink has been closed and cannot accept new data.');
    }

    _decoder ??= resolveDecoder();

    if (_decoder == null) {
      return _buffer!.add(chunk);
    }

    final interlacedData = _decoder?.addChunk(chunk);
    if (interlacedData != null) {
      _output.add(interlacedData);
    }
  }

  @override
  void close() {
    _buffer?.clear();
    _buffer = null;
    _decoder = null;
    _output.close();
  }

  InterlacedDecoder? resolveDecoder() {
    if (ProgressiveJPEGDecoder.isProgressiveJPEG(_buffer)) {
      return ProgressiveJPEGDecoder(_buffer!);
    }
    return null;
  }
}

// Base class for interlaced format decoders
abstract class InterlacedDecoder {
  final BytesBuilder buffer;

  InterlacedDecoder(this.buffer);

  InterlacedData? addChunk(List<int> chunk);
}
