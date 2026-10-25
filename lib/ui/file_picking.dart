import 'package:file_picker/file_picker.dart';

/// Media the library can copy and play. MKV/WebM/Ogg play but cannot be
/// transcribed (see TranscriptionController.extensions).
const mediaExtensions = [
  'mp4',
  'mov',
  'm4v',
  'mkv',
  'webm',
  'mp3',
  'wav',
  'm4a',
  'qta',
  'aac',
  'flac',
  'ogg',
  'aiff',
  'aif',
];

/// The only ways the UI reaches outside the library. Each returns null when
/// the user cancels; errors propagate for `describeError`.
Future<String?> pickFile(List<String> extensions, {String? dialogTitle}) async {
  final result = await FilePicker.platform.pickFiles(
    dialogTitle: dialogTitle,
    type: FileType.custom,
    allowedExtensions: extensions,
    allowMultiple: false,
    withData: false,
  );
  return result?.files.single.path;
}

Future<String?> pickDirectory({String? dialogTitle}) =>
    FilePicker.platform.getDirectoryPath(dialogTitle: dialogTitle);

Future<String?> pickSaveLocation({
  required String fileName,
  String? dialogTitle,
  List<String>? extensions,
}) => FilePicker.platform.saveFile(
  dialogTitle: dialogTitle,
  fileName: fileName,
  type: extensions == null ? FileType.any : FileType.custom,
  allowedExtensions: extensions,
);
