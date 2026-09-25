import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transikey/core/utils/private_file.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('transikey-private-');
    addTearDown(() => dir.delete(recursive: true));
  });

  String mode(String path) =>
      (File(path).statSync().mode & 0x1FF).toRadixString(8);

  test('writes the content', () async {
    final path = '${dir.path}/kubeconfig.yaml';
    await writePrivateFile(path, 'token: x\n');
    expect(await File(path).readAsString(), 'token: x\n');
  });

  test(
    'a new file is readable by the owner only',
    () async {
      final path = '${dir.path}/kubeconfig.yaml';
      await writePrivateFile(path, 'token: x\n');
      expect(mode(path), '600');
    },
    skip: Platform.isWindows ? 'POSIX permissions only' : null,
  );

  test(
    'an existing world-readable file is restricted and replaced',
    () async {
      final path = '${dir.path}/kubeconfig.yaml';
      await File(path).writeAsString('old content that is longer\n');
      await Process.run('chmod', ['644', path]);
      await writePrivateFile(path, 'new\n');
      expect(mode(path), '600');
      expect(await File(path).readAsString(), 'new\n');
    },
    skip: Platform.isWindows ? 'POSIX permissions only' : null,
  );

  test('a missing directory fails loudly', () async {
    await expectLater(
      writePrivateFile('${dir.path}/missing/kubeconfig.yaml', 'x'),
      throwsA(isA<FileSystemException>()),
    );
  });
}
