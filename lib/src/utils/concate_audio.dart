import 'dart:io';
import 'dart:typed_data';

Future<File> concatenateWavFiles(List<String> inputPaths, String outputPath) async {
  if (inputPaths.isEmpty) {
    throw ArgumentError('No input files provided');
  }

  // Validate and collect audio data from all files
  List<WavFileInfo> wavFiles = [];
  int totalDataSize = 0;
  int? format, channels, sampleRate, bitsPerSample;

  for (int i = 0; i < inputPaths.length; i++) {
    try {
      final fileInfo = await extractWavInfo(inputPaths[i]);

      // Ensure all files have the same audio format
      if (i == 0) {
        format = fileInfo.format;
        channels = fileInfo.channels;
        sampleRate = fileInfo.sampleRate;
        bitsPerSample = fileInfo.bitsPerSample;
      } else if (fileInfo.format != format ||
          fileInfo.channels != channels ||
          fileInfo.sampleRate != sampleRate ||
          fileInfo.bitsPerSample != bitsPerSample) {
        print('Warning: ${inputPaths[i]} has a different format - results may be unpredictable');
      }

      wavFiles.add(fileInfo);
      totalDataSize += fileInfo.dataSize;
    } catch (e) {
      print('Error processing ${inputPaths[i]}: $e');
    }
  }

  if (wavFiles.isEmpty) {
    throw Exception('No valid WAV files found to concatenate');
  }

  final firstFile = wavFiles[0];
  final blockAlign = firstFile.channels! * (firstFile.bitsPerSample! ~/ 8);
  final byteRate = firstFile.sampleRate! * blockAlign;
  final totalSampleFrames = totalDataSize ~/ blockAlign;

  // Calculate duration in seconds for metadata
  final double durationSeconds = totalSampleFrames / firstFile.sampleRate!;

  // Create INFO metadata
  final Map<String, String> infoMetadata = {
    'INAM': 'Concatenated WAV file',
    'ICMT': 'Combined from ${wavFiles.length} files',
    'ICRD': DateTime.now().toString().substring(0, 10),
    'IDUR': durationSeconds.toStringAsFixed(3), // Duration in seconds
  };

  // Calculate LIST chunk size (adding 4 for 'INFO' identifier)
  int listChunkSize = 4; // 'INFO' identifier
  infoMetadata.forEach((key, value) {
    // Each entry has: 4-byte ID + 4-byte size + data + possible padding byte
    int entrySize = 4 + 4 + value.length;
    if (entrySize % 2 != 0) entrySize++; // Padding to even size
    listChunkSize += entrySize;
  });

  // Calculate total file size including LIST chunk
  int totalFileSize = 12 + // 'RIFF' + size + 'WAVE'
      (8 + 16) + // fmt chunk header + size
      (8 + listChunkSize) + // LIST chunk header + size
      (8 + totalDataSize); // data chunk header + size

  // Create output WAV file
  final outputFile = File(outputPath);
  final outputStream = outputFile.openWrite();

  try {
    // Write WAV header
    // RIFF header
    outputStream.add(utf8Encode('RIFF'));
    outputStream.add(_uint32ToBytes(totalFileSize - 8, Endian.little)); // File size - 8
    outputStream.add(utf8Encode('WAVE'));

    // Format chunk
    outputStream.add(utf8Encode('fmt '));
    outputStream.add(_uint32ToBytes(16, Endian.little)); // Format chunk size
    outputStream.add(_uint16ToBytes(firstFile.format!, Endian.little)); // Audio format (1 = PCM)
    outputStream.add(_uint16ToBytes(firstFile.channels!, Endian.little)); // Channels
    outputStream.add(_uint32ToBytes(firstFile.sampleRate!, Endian.little)); // Sample rate
    outputStream.add(_uint32ToBytes(byteRate, Endian.little)); // Byte rate
    outputStream.add(_uint16ToBytes(blockAlign, Endian.little)); // Block align
    outputStream.add(_uint16ToBytes(firstFile.bitsPerSample!, Endian.little)); // Bits per sample

    // LIST/INFO chunk - important for duration metadata
    outputStream.add(utf8Encode('LIST'));
    outputStream.add(_uint32ToBytes(listChunkSize, Endian.little));
    outputStream.add(utf8Encode('INFO'));

    // Write each INFO sub-chunk
    infoMetadata.forEach((key, value) {
      outputStream.add(utf8Encode(key));

      // Size of the string data
      int valueSize = value.length;
      // Pad to even length if needed
      bool needsPadding = valueSize % 2 != 0;
      if (needsPadding) valueSize++;

      outputStream.add(_uint32ToBytes(valueSize, Endian.little));
      outputStream.add(utf8Encode(value));

      // Add padding byte if needed
      if (needsPadding) {
        outputStream.add([0]);
      }
    });

    // Data chunk
    outputStream.add(utf8Encode('data'));
    outputStream.add(_uint32ToBytes(totalDataSize, Endian.little)); // Data size

    // Write audio data from each file
    for (var fileInfo in wavFiles) {
      final file = File(fileInfo.filePath);
      final fileStream = file.openRead(fileInfo.dataOffset, fileInfo.dataOffset + fileInfo.dataSize);
      await for (var chunk in fileStream) {
        outputStream.add(chunk);
      }
    }
  } finally {
    await outputStream.close();
  }

  print('Successfully concatenated ${wavFiles.length} WAV files to $outputPath');
  print('Total duration: ${durationSeconds.toStringAsFixed(2)} seconds');
  return File(outputPath);
}

Future<WavFileInfo> extractWavInfo(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) {
    throw FileSystemException('File not found', filePath);
  }

  final fileBytes = await file.readAsBytes();
  final ByteData fileData = ByteData.view(fileBytes.buffer);

  // Validate WAV header
  if (String.fromCharCodes(fileBytes.getRange(0, 4)) != 'RIFF' ||
      String.fromCharCodes(fileBytes.getRange(8, 12)) != 'WAVE') {
    throw FormatException('Not a valid WAV file: $filePath');
  }

  // Find format chunk
  int formatOffset = -1;
  for (int i = 12; i < fileBytes.length - 4; i++) {
    if (String.fromCharCodes(fileBytes.getRange(i, i + 4)) == 'fmt ') {
      formatOffset = i;
      break;
    }
  }

  if (formatOffset < 0) {
    throw FormatException('Format chunk not found in: $filePath');
  }

  final formatChunkSize = fileData.getUint32(formatOffset + 4, Endian.little);
  final format = fileData.getUint16(formatOffset + 8, Endian.little);
  final channels = fileData.getUint16(formatOffset + 10, Endian.little);
  final sampleRate = fileData.getUint32(formatOffset + 12, Endian.little);
  final bitsPerSample = fileData.getUint16(formatOffset + 22, Endian.little);

  // Find data chunk
  int dataOffset = -1;
  for (int i = formatOffset + 8 + formatChunkSize; i < fileBytes.length - 4; i++) {
    if (String.fromCharCodes(fileBytes.getRange(i, i + 4)) == 'data') {
      dataOffset = i;
      break;
    }
  }

  if (dataOffset < 0) {
    throw FormatException('Data chunk not found in: $filePath');
  }

  final dataSize = fileData.getUint32(dataOffset + 4, Endian.little);

  return WavFileInfo(
      filePath: filePath,
      format: format,
      channels: channels,
      sampleRate: sampleRate,
      bitsPerSample: bitsPerSample,
      dataOffset: dataOffset + 8, // Skip 'data' marker and size
      dataSize: dataSize);
}

class WavFileInfo {
  final String filePath;
  final int? format;
  final int? channels;
  final int? sampleRate;
  final int? bitsPerSample;
  final int dataOffset;
  final int dataSize;

  WavFileInfo(
      {required this.filePath,
      required this.format,
      required this.channels,
      required this.sampleRate,
      required this.bitsPerSample,
      required this.dataOffset,
      required this.dataSize});
}

List<int> utf8Encode(String input) {
  return input.codeUnits;
}

List<int> _uint32ToBytes(int value, Endian endian) {
  final data = ByteData(4);
  data.setUint32(0, value, endian);
  return Uint8List.view(data.buffer);
}

List<int> _uint16ToBytes(int value, Endian endian) {
  final data = ByteData(2);
  data.setUint16(0, value, endian);
  return Uint8List.view(data.buffer);
}
