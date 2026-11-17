import 'package:file_picker/file_picker.dart';

Future<PlatformFile?> pickDocumentFile() async {
  try {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result.isEmpty) return null;

    return result.first;
  } catch (_) {
    return null;
  }
}
