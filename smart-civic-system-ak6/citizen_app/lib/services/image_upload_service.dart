import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ImageUploadService {
  static const String _imgbbApiKey = "482424c79135f8ee4607c86bc95c7b98";

  /// Uploads an image to ImgBB.
  /// Returns the URL of the uploaded image, or null on failure.
  static Future<String?> uploadImage({
    required File file,
    String? name,
    void Function(double)? onProgress,
  }) async {
    try {
      debugPrint("---- IMGBB UPLOAD ----");
      debugPrint("File: ${file.path}");

      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);
      onProgress?.call(0.3);

      final uri = Uri.parse("https://api.imgbb.com/1/upload");
      final request = http.MultipartRequest("POST", uri);

      request.fields['key'] = _imgbbApiKey;
      request.fields['image'] = base64Image;

      if (name != null && name.isNotEmpty) {
        request.fields['name'] = name.replaceAll('/', '_');
      }

      onProgress?.call(0.5);

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      debugPrint("ImgBB Response: $responseBody");
      onProgress?.call(0.8);

      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        final url = data['data']?['url'] as String?;

        if (url != null) {
          debugPrint("Upload success: $url");
          onProgress?.call(1.0);
          return url;
        }
        debugPrint("URL null in response");
        return null;
      } else {
        debugPrint("ImgBB Error [${response.statusCode}]: $responseBody");
        return null;
      }
    } catch (e) {
      debugPrint("Upload Exception: $e");
      return null;
    }
  }
}
