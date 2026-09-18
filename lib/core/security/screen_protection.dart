/// Blocks screenshots and screen recording of the application window.
///
/// TODO(platform): implement through a platform channel —
/// `NSWindow.sharingType = .none` (macOS) and
/// `SetWindowDisplayAffinity(WDA_EXCLUDEFROMCAPTURE)` (Windows). Linux
/// compositors expose no equivalent API.
abstract class ScreenProtection {
  Future<bool> isSupported();
  Future<void> setEnabled(bool enabled);
}

class NoopScreenProtection implements ScreenProtection {
  const NoopScreenProtection();

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<void> setEnabled(bool enabled) async {}
}
