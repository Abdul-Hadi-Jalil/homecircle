import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../../../core/errors/app_exception.dart';

Future<Uint8List?> pickTaskPhoto() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 2400,
    maxHeight: 2400,
    imageQuality: 85,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  if (bytes.length > 5 * 1024 * 1024) throw const AppException('invalid_photo');
  return bytes;
}
