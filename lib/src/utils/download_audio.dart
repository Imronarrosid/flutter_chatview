import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

Future<String?> downloadFile(String url, String fileName,
    Function(int received, int total) onReceiveProgress) async {
  try {
    Dio dio = Dio();
    Directory tempDir =
        await getApplicationDocumentsDirectory(); // Or use getApplicationDocumentsDirectory()
    String savePath = "${tempDir.path}/$fileName.m4a";

    await dio.download(url, savePath, onReceiveProgress: (received, total) {
      if (total != -1) {
        onReceiveProgress.call(received, total);
        print("Downloading: ${(received / total * 100).toStringAsFixed(0)}%");
      }
    });

    print("File saved at: $savePath");
    return savePath;
  } catch (e) {
    print("Download error: $e");
    return null;
  }
}
