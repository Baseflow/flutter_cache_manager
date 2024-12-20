import 'dart:typed_data';

import 'package:flutter_cache_manager/src/web/interlaced/interlaced_transformer.dart';

// Decoder for progressive JPEG images
class ProgressiveJPEGDecoder extends InterlacedDecoder {
  static bool isProgressiveJPEG(BytesBuilder? buffer) {
    if (buffer == null) return false;

    final data = buffer.toBytes();

    if (data.length < 4) return false;

    // Check for the SOI (Start of Image)
    if (data[0] == 0xFF && data[1] == 0xD8) {
      // Check for the first SOF marker
      for (int i = 2; i < data.length - 1; i++) {
        if (data[i] == 0xFF && data[i + 1] >= 0xC0 && data[i + 1] <= 0xCF) {
          return data[i + 1] == 0xC2;
        }
      }
    }

    return false;
  }

  // List of valid offsets
  final List<int> _validOffsets = [];

  ProgressiveJPEGDecoder(super.buffer);

  @override
  InterlacedData? addChunk(List<int> chunk) {
    // Calculate startOffset before adding the new chunk
    int startOffset =
        (buffer.length - 1).clamp(0, buffer.length); // Ensure valid bounds

    // Add the new chunk to the buffer
    buffer.add(chunk);

    _updateOffsets(buffer.toBytes(), startOffset);

    return _getBestData();
  }

  InterlacedData? _getBestData() {
    // Get the best valid data using the latest valid offset
    if (_validOffsets.isNotEmpty) {
      final data =
          Uint8List.sublistView(buffer.toBytes(), 0, _validOffsets.last);

      data[data.length - 1] = 0xd9; // Fix the last byte as EOI
      return InterlacedData(data);
    }

    return null;
  }

  void _updateOffsets(Uint8List data, int startOffset) {
    // Iterate through data starting from the adjusted offset
    for (int i = startOffset; i < data.length - 1; i++) {
      if (data[i] == 0xFF && _isMarker(data[i + 1])) {
        // Add offset of the marker's end
        _validOffsets.add(i + 2);
      }
    }
  }

  bool _isMarker(int byte) {
    // Check for JPEG markers: 0xDA (Start of Scan) or 0xD9 (End of Image)
    return byte == 0xDA || byte == 0xD9;
  }
}
