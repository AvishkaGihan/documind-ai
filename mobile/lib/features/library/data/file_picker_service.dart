import 'package:documind_ai/features/library/models/document_upload_models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class PdfFilePickerService {
  Future<SelectedPdfFile?> pickPdf();
}

class NativePdfFilePickerService implements PdfFilePickerService {
  @override
  Future<SelectedPdfFile?> pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }

    final picked = result.files.single;
    return SelectedPdfFile(
      name: picked.name,
      sizeInBytes: picked.size,
      path: picked.path,
      bytes: picked.bytes,
    );
  }
}

final pdfFilePickerProvider = Provider<PdfFilePickerService>((ref) {
  return NativePdfFilePickerService();
});
