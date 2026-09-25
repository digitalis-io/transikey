import 'dart:io';

/// Writes [content] to [path], readable by the owner only (`0600`) on
/// macOS and Linux. The file is emptied and restricted before the content
/// goes in, so a secret is never readable by others, not even briefly.
/// Windows files inherit the ACL of the user's folder instead.
Future<void> writePrivateFile(String path, String content) async {
  final file = File(path);
  if (!Platform.isWindows) {
    await file.writeAsString('', flush: true);
    final chmod = await Process.run('chmod', ['600', path]);
    if (chmod.exitCode != 0) {
      throw FileSystemException('Cannot restrict permissions', path);
    }
  }
  await file.writeAsString(content, flush: true);
}
