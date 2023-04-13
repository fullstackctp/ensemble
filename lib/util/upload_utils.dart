import 'dart:async';
import 'dart:convert';

import 'package:ensemble/ensemble_app.dart';
import 'package:ensemble/framework/data_context.dart' hide MediaType;
import 'package:ensemble/util/http_utils.dart';
import 'package:ensemble/util/notification_utils.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:workmanager/workmanager.dart';

typedef ProgressCallback = void Function(double progress);
typedef OnDoneCallback = void Function();
typedef OnErrorCallback = void Function(dynamic error);

class UploadUtils {
  static Future<Response?> uploadFiles({
    required String method,
    required String url,
    required Map<String, String> headers,
    required List<File> files,
    required String fieldName,
    bool isBackgroundTask = false,
    ProgressCallback? progressCallback,
    OnDoneCallback? onDone,
    OnErrorCallback? onError,
  }) async {
    final request = MultipartRequest(
      method,
      Uri.parse(url),
      onProgress: isBackgroundTask
          ? (int bytes, int total) {
              final progress = bytes / total;
              notificationUtils
                  .showProgressNotification((progress * 100).toInt());
            }
          : progressCallback == null
              ? null
              : (int bytes, int total) {
                  final progress = bytes / total;
                  progressCallback.call(progress);
                },
    );
    request.headers.addAll(headers);
    final multipartFiles = <http.MultipartFile>[];

    for (var file in files) {
      http.MultipartFile? multipartFile;
      final mimeType =
          lookupMimeType(file.path ?? '', headerBytes: file.bytes) ??
              'application/octet-stream';
      if (file.path != null) {
        multipartFile = await http.MultipartFile.fromPath(fieldName, file.path!,
            filename: file.name, contentType: MediaType.parse(mimeType));
      } else if (file.bytes != null) {
        multipartFile = http.MultipartFile.fromBytes(fieldName, file.bytes!,
            filename: file.name, contentType: MediaType.parse(mimeType));
      } else {
        continue;
      }

      multipartFiles.add(multipartFile);
    }

    request.files.addAll(multipartFiles);

    try {
      final response = await request.send();

      if (response.statusCode >= 200 && response.statusCode <= 300) {
        final res = await http.Response.fromStream(response);
        return Response(res);
      } else {
        throw Exception('Failed to upload file');
      }
    } catch (error) {
      onError?.call(error);
    }
    return null;
  }

  static Future<void> setBackgroundUploadTask({
    required String method,
    required String url,
    required Map<String, String> headers,
    required String fieldName,
    required List<File> files,
  }) async {
    await Workmanager().registerOneOffTask(
      'uploadTask',
      backgroundUploadTask,
      inputData: {
        'fieldName': fieldName,
        'files': files.map((e) => json.encode(e.toJson())).toList(),
        'headers': json.encode(headers),
        'method': method,
        'url': url,
      },
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
}

class MultipartRequest extends http.MultipartRequest {
  MultipartRequest(
    String method,
    Uri url, {
    this.onProgress,
  }) : super(method, url);

  final void Function(int bytes, int totalBytes)? onProgress;

  @override
  http.ByteStream finalize() {
    final byteStream = super.finalize();
    if (onProgress == null) return byteStream;

    final total = contentLength;
    int bytes = 0;

    final t = StreamTransformer.fromHandlers(
      handleData: (List<int> data, EventSink<List<int>> sink) {
        bytes += data.length;
        if (total >= bytes) {
          sink.add(data);
          onProgress?.call(bytes, total);
        }
      },
    );
    final stream = byteStream.transform(t);
    return http.ByteStream(stream);
  }
}
