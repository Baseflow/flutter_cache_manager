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

/// Represents a decoder check function and its corresponding decoder constructor
class DecoderCheck {
  final bool? Function(BytesBuilder) check;
  final InterlacedDecoder Function(BytesBuilder) createDecoder;

  const DecoderCheck({
    required this.check,
    required this.createDecoder,
  });
}

class InterlacedByteConversionSink implements ChunkedConversionSink<Uint8List> {
  final Sink<InterlacedData> _output;

  // Buffer to accumulate chunks
  BytesBuilder? _buffer = BytesBuilder();

  InterlacedDecoder? _decoder;

  static final _decoderChecks = [
    DecoderCheck(
      check: ProgressiveJPEGDecoder.isProgressiveJPEG,
      createDecoder: (buffer) => ProgressiveJPEGDecoder(buffer),
    ),
  ];

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
    // Try each decoder check
    for (final decoderCheck in _decoderChecks) {
      final result = decoderCheck.check(_buffer!);
      if (result == true) {
        return decoderCheck.createDecoder(_buffer!);
      }
    }

    // Check if all decoders returned false
    if (_decoderChecks.every(
      (check) => check.check(_buffer!) == false,
    )) {
      return DumbDecoder(_buffer!);
    }

    return null;
  }
}

class DumbDecoder extends InterlacedDecoder {
  DumbDecoder(super.buffer);

  @override
  InterlacedData? addChunk(List<int> chunk) {
    buffer.add(chunk);
    return null;
  }
}

// Base class for interlaced format decoders
abstract class InterlacedDecoder {
  final BytesBuilder buffer;

  InterlacedDecoder(this.buffer);

  InterlacedData? addChunk(List<int> chunk);
}
