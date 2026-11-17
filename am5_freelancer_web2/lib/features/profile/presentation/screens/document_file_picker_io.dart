import 'package:file_picker/file_picker.dart';

Future<String?> pickDocumentFile() async {
  try {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result.isEmpty) {
      return null;
    }

    return result.first.name;
  } catch (e) {
    return null;
  }
}
