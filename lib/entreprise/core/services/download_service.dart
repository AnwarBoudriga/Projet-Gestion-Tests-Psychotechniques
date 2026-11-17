import 'dart:js_interop';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:web/web.dart' as web;

import 'api_client.dart';

/// Télécharge un fichier protégé par le JWT (CSV / PDF) puis le propose
/// au téléchargement dans le navigateur (Flutter Web).
class DownloadService {
  DownloadService._();

  static Future<void> download(String path, String fileName, String mime) async {
    final r = await ApiClient.dio.get<List<int>>(
      path,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = Uint8List.fromList(r.data ?? const <int>[]);
    final parts = <web.BlobPart>[bytes.toJS].toJS;
    final blob = web.Blob(parts, web.BlobPropertyBag(type: mime));
    final url = web.URL.createObjectURL(blob);
    final a = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName;
    a.click();
    web.URL.revokeObjectURL(url);
  }
}
