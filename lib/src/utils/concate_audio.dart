import 'dart:io';
import 'dart:typed_data';

Future<File> concatenateWavFiles(List<String> inputPaths, String outputPath) async {
  if (inputPaths.isEmpty) {
    throw ArgumentError('No input files provided');
  }

  // Read the first file to get the format
  final firstFile = await File(inputPaths[0]).readAsBytes();
  final ByteData firstFileData = ByteData.view(firstFile.buffer);

  // Verify it's a WAV file
  if (String.fromCharCodes(firstFile.getRange(0, 4)) != 'RIFF' ||
      String.fromCharCodes(firstFile.getRange(8, 12)) != 'WAVE') {
    throw FormatException('First file is not a valid WAV file');
  }

  // Extract format information from the first file
  int formatOffset = _findChunk(firstFile, 'fmt ');
  if (formatOffset < 0) {
    throw FormatException('Format chunk not found in first file');
  }

  final formatChunkSize = firstFileData.getUint32(formatOffset + 4, Endian.little);
  final audioFormat = firstFileData.getUint16(formatOffset + 8, Endian.little);
  final numChannels = firstFileData.getUint16(formatOffset + 10, Endian.little);
  final sampleRate = firstFileData.getUint32(formatOffset + 12, Endian.little);
  final byteRate = firstFileData.getUint32(formatOffset + 16, Endian.little);
  final blockAlign = firstFileData.getUint16(formatOffset + 20, Endian.little);
  final bitsPerSample = firstFileData.getUint16(formatOffset + 22, Endian.little);

  // Collect audio data from all files
  List<Uint8List> audioDataChunks = [];
  int totalAudioDataSize = 0;

  for (String filePath in inputPaths) {
    final fileBytes = await File(filePath).readAsBytes();
    final ByteData fileData = ByteData.view(fileBytes.buffer);

    // Verify file format matches the first file
    if (String.fromCharCodes(fileBytes.getRange(0, 4)) != 'RIFF' ||
        String.fromCharCodes(fileBytes.getRange(8, 12)) != 'WAVE') {
      print('Warning: $filePath is not a valid WAV file - skipping');
      continue;
    }

    int dataOffset = _findChunk(fileBytes, 'data');
    if (dataOffset < 0) {
      print('Warning: Data chunk not found in $filePath - skipping');
      continue;
    }

    int dataSize = fileData.getUint32(dataOffset + 4, Endian.little);
    audioDataChunks.add(fileBytes.sublist(dataOffset + 8, dataOffset + 8 + dataSize));
    totalAudioDataSize += dataSize;
  }

  // Create the output file
  final outputFile = File(outputPath);
  final outputBuffer = BytesBuilder();

  // Write WAV header
  // RIFF header
  outputBuffer.add(utf8Encode('RIFF'));
  outputBuffer.add(_uint32ToBytes(36 + totalAudioDataSize, Endian.little)); // File size - 8
  outputBuffer.add(utf8Encode('WAVE'));

  // Format chunk
  outputBuffer.add(utf8Encode('fmt '));
  outputBuffer.add(_uint32ToBytes(16, Endian.little)); // Format chunk size
  outputBuffer.add(_uint16ToBytes(audioFormat, Endian.little)); // Audio format
  outputBuffer.add(_uint16ToBytes(numChannels, Endian.little)); // Num channels
  outputBuffer.add(_uint32ToBytes(sampleRate, Endian.little)); // Sample rate
  outputBuffer.add(_uint32ToBytes(byteRate, Endian.little)); // Byte rate
  outputBuffer.add(_uint16ToBytes(blockAlign, Endian.little)); // Block align
  outputBuffer.add(_uint16ToBytes(bitsPerSample, Endian.little)); // Bits per sample

  // Data chunk
  outputBuffer.add(utf8Encode('data'));
  outputBuffer.add(_uint32ToBytes(totalAudioDataSize, Endian.little)); // Data size

  // Add all audio data
  for (Uint8List chunk in audioDataChunks) {
    outputBuffer.add(chunk);
  }

  // Write the output file
  await outputFile.writeAsBytes(outputBuffer.toBytes());
  print('Successfully concatenated ${inputPaths.length} WAV files to $outputPath');
  return File(outputPath);
}

int _findChunk(Uint8List fileBytes, String chunkId) {
  final chunkIdBytes = utf8Encode(chunkId);
  for (int i = 0; i < fileBytes.length - 4; i++) {
    if (fileBytes[i] == chunkIdBytes[0] &&
        fileBytes[i + 1] == chunkIdBytes[1] &&
        fileBytes[i + 2] == chunkIdBytes[2] &&
        fileBytes[i + 3] == chunkIdBytes[3]) {
      return i;
    }
  }
  return -1;
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
