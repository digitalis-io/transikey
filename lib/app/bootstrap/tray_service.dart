/// System tray integration (lock, show window, quit).
///
/// TODO(tray): wire `tray_manager` once tray icon assets exist for each
/// platform (`.png` for macOS/Linux, `.ico` for Windows):
/// `trayManager.setIcon(...)`, `trayManager.setContextMenu(Menu(items: [...]))`
/// and a `TrayListener` that calls `windowManager.show()` and the session
/// notifier's `lock()`.
class TrayService {
  TrayService._();

  static final instance = TrayService._();

  Future<void> init() async {}

  Future<void> dispose() async {}
}
