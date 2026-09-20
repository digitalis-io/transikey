import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transikey/core/utils/home_paths.dart';

void main() {
  group('homeDirectory', () {
    test('reads HOME on POSIX platforms', () {
      if (Platform.isWindows) return;
      expect(homeDirectory({'HOME': '/Users/demo'}), '/Users/demo');
    });

    test('is null when the variable is missing or blank', () {
      expect(homeDirectory(const {}), isNull);
      expect(homeDirectory({'HOME': '  ', 'USERPROFILE': '  '}), isNull);
    });

    test('reads USERPROFILE on Windows', () {
      if (!Platform.isWindows) return;
      expect(
        homeDirectory({'USERPROFILE': r'C:\Users\demo'}),
        r'C:\Users\demo',
      );
    });
  });

  group('sshDirectory', () {
    test('appends .ssh to the home directory', () {
      if (Platform.isWindows) return;
      expect(sshDirectory({'HOME': '/Users/demo'}), '/Users/demo/.ssh');
    });

    test('is null without a home directory', () {
      expect(sshDirectory(const {}), isNull);
    });
  });

  group('existingSshDirectory', () {
    test('returns the path when it exists', () {
      final home = Directory.systemTemp.createTempSync('transikey_home');
      addTearDown(() => home.deleteSync(recursive: true));
      Directory('${home.path}${Platform.pathSeparator}.ssh').createSync();

      expect(
        existingSshDirectory({'HOME': home.path, 'USERPROFILE': home.path}),
        '${home.path}${Platform.pathSeparator}.ssh',
      );
    });

    test('is null when the directory is absent', () {
      final home = Directory.systemTemp.createTempSync('transikey_home');
      addTearDown(() => home.deleteSync(recursive: true));

      expect(
        existingSshDirectory({'HOME': home.path, 'USERPROFILE': home.path}),
        isNull,
      );
    });
  });

  group('parentDirectoryOf', () {
    test('returns the containing directory when it exists', () {
      final dir = Directory.systemTemp.createTempSync('transikey_keys');
      addTearDown(() => dir.deleteSync(recursive: true));

      expect(
        parentDirectoryOf('${dir.path}${Platform.pathSeparator}id_ed25519'),
        dir.path,
      );
    });

    test('is null for a bare file name', () {
      expect(parentDirectoryOf('id_ed25519'), isNull);
    });

    test('is null when the directory does not exist', () {
      expect(parentDirectoryOf('/no/such/place/id_ed25519'), isNull);
    });
  });
}
