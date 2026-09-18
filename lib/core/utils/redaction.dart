/// Helpers that strip secret material before anything reaches a log sink or
/// a crash report.
abstract final class Redaction {
  static const mask = '***';

  static final _sensitiveKey = RegExp(
    r'(token|password|passwd|secret|otp|private|signed_key|authorization|'
    r'credential|^key$|_key$|^data$)',
    caseSensitive: false,
  );

  static final _tokenPattern = RegExp(
    r'\b(hv[sbr]|[sbr])\.[A-Za-z0-9_\-\.]{8,}',
  );
  static final _pemPattern = RegExp(
    r'-----BEGIN [A-Z ]+-----[\s\S]*?-----END [A-Z ]+-----',
  );
  static final _sshCertPattern = RegExp(
    r'\bssh-[a-z0-9\-]+-cert-v01@openssh\.com\s+[A-Za-z0-9+/=]+',
  );

  static bool isSensitiveKey(String key) => _sensitiveKey.hasMatch(key);

  /// Masks token-like values, PEM blocks and SSH certificates in free text.
  static String text(String input) => input
      .replaceAll(_pemPattern, mask)
      .replaceAll(_sshCertPattern, mask)
      .replaceAll(_tokenPattern, mask);

  /// Returns a deep copy of [input] with every sensitive value masked.
  static Object? value(Object? input) {
    if (input is Map) {
      return input.map(
        (key, v) =>
            MapEntry(key, isSensitiveKey(key.toString()) ? mask : value(v)),
      );
    }
    if (input is Iterable) return input.map(value).toList();
    if (input is String) return text(input);
    return input;
  }

  /// Redacts an error and stack trace pair before it is handed to a crash
  /// reporter.
  static String crashReport(Object error, [StackTrace? stack]) =>
      text('$error${stack == null ? '' : '\n$stack'}');
}
