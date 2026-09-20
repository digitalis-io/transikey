import 'dart:io';

/// The user's home directory, or null when the environment does not say.
String? homeDirectory([Map<String, String>? environment]) {
  final env = environment ?? Platform.environment;
  final home = Platform.isWindows
      ? (env['USERPROFILE'] ??
            (env['HOMEDRIVE'] != null && env['HOMEPATH'] != null
                ? '${env['HOMEDRIVE']}${env['HOMEPATH']}'
                : null))
      : env['HOME'];
  final trimmed = home?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// `~/.ssh`, or null when there is no home directory.
///
/// Native file dialogs hide dotfiles by default (macOS `NSOpenPanel`, GTK),
/// so `.ssh` is invisible when the dialog starts in the home directory.
/// Opening the dialog *inside* `.ssh` sidesteps that: its contents are
/// listed normally.
String? sshDirectory([Map<String, String>? environment]) {
  final home = homeDirectory(environment);
  return home == null ? null : '$home${Platform.pathSeparator}.ssh';
}

/// [sshDirectory] when it exists on disk, otherwise null so the dialog
/// falls back to its own default location.
String? existingSshDirectory([Map<String, String>? environment]) {
  final path = sshDirectory(environment);
  if (path == null) return null;
  return Directory(path).existsSync() ? path : null;
}

/// The directory holding [filePath], or null when [filePath] carries no
/// directory part or that directory does not exist.
String? parentDirectoryOf(String filePath) {
  final index = filePath.lastIndexOf(RegExp(r'[\\/]'));
  if (index <= 0) return null;
  final dir = filePath.substring(0, index);
  return Directory(dir).existsSync() ? dir : null;
}
