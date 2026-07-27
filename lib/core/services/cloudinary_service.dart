import 'dart:convert';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import '../config/cloudinary_config.dart';
import '../errors/exceptions.dart';

abstract class CloudinaryService {
  Future<String> uploadImage(File file);
}

class CloudinaryServiceImpl implements CloudinaryService {
  CloudinaryServiceImpl({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<String> uploadImage(File file) async {
    final compressed = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      quality: 75,
      minWidth: 1280,
      minHeight: 1280,
    );
    if (compressed == null) {
      throw StorageException('Failed to compress image');
    }

    final request = http.MultipartRequest('POST', Uri.parse(CloudinaryConfig.uploadUrl))
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        compressed,
        filename: '${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StorageException('Cloudinary upload failed: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final secureUrl = body['secure_url'] as String?;
    if (secureUrl == null) {
      throw StorageException('Cloudinary response missing secure_url');
    }
    return secureUrl;
  }
}
