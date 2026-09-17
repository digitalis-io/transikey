import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Biometric / device credential prompt (Touch ID, Windows Hello).
abstract class BiometricAuth {
  Future<bool> isAvailable();
  Future<bool> authenticate(String reason);
}

class LocalBiometricAuth implements BiometricAuth {
  LocalBiometricAuth([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false; // Linux has no local_auth implementation.
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(stickyAuth: true),
      );
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
