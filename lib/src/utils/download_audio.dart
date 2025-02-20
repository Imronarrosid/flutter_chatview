import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

Future<String?> downloadFile(String url, String fileName,
    Function(int received, int total) onReceiveProgress) async {
  try {
    Dio dio = Dio();
    Directory appDir =
        await getApplicationDocumentsDirectory(); // Or use getApplicationDocumentsDirectory()
    String savePath = "${appDir.path}/$fileName.m4a";

    await dio.download(url, savePath, onReceiveProgress: (received, total) {
      if (total != -1) {
        onReceiveProgress.call(received, total);
      }
    });

    return savePath;
  } catch (e) {
    return null;
  }
}

Future<(bool, String)> isFileDownloaded(String fileName) async {
  Directory appDir =
      await getApplicationDocumentsDirectory(); // Or use getApplicationDocumentsDirectory()
  String path = "${appDir.path}/$fileName.m4a";

  return (File(path).existsSync(), path); // Check if the file exists
}
