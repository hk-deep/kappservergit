import 'dart:async';
import 'dart:typed_data';

import 'package:googleapis/storage/v1.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:shelf/shelf.dart';

class StorageBucket {
  static const String storageBucket =
      'gs://flutter-ecommerce-1c0b7.appspot.com';

  static Future<Response> bucketTestHandler(Request request) async {
    var client = await clientViaApplicationDefaultCredentials(
        scopes: [StorageApi.devstorageFullControlScope]);

    var storage = StorageApi(client);

    // Bucket and object details
    var bucketName = 'x-circle-416916.appspot.com';
    var objectName = 'thumbsUp.png';
    final item = await storage.objects.get(bucketName, objectName,
        downloadOptions: DownloadOptions.fullMedia) as Media;
    List<int> dataBytes = [];
    Completer<Uint8List> completer = Completer();

    item.stream.listen(
      (List<int> chunk) {
        dataBytes.addAll(chunk);
      },
      onDone: () => completer.complete(Uint8List.fromList(dataBytes)),
      onError: (e) => completer.completeError(e),
    );

    var bytes = await completer.future;
    client.close();
    // final imageBytes = item.toString();
    return Response.ok(bytes, headers: {'Content-Type': 'image/png'});
  }

  static Future<List<int>> getPic(String imageName) async {
    var client = await clientViaApplicationDefaultCredentials(
        scopes: [StorageApi.devstorageFullControlScope]);

    var storage = StorageApi(client);

    // Bucket and object details
    var bucketName = 'x-circle-416916.appspot.com';
    final item = await storage.objects.get(bucketName, imageName,
        downloadOptions: DownloadOptions.fullMedia) as Media;
    List<int> dataBytes = [];
    Completer<Uint8List> completer = Completer();

    item.stream.listen(
      (List<int> chunk) {
        dataBytes.addAll(chunk);
      },
      onDone: () => completer.complete(Uint8List.fromList(dataBytes)),
      onError: (e) => completer.completeError(e),
    );

    var bytes = await completer.future;
    return bytes;
  }
}
