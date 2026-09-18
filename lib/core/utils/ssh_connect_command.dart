import 'shell_quote.dart';

/// Where to ssh to. The OTP response carries the target IP the OTP was
/// issued for, but the address you dial may differ (port forward, dev
/// stack), so the user can edit it.
class SshTarget {
  const SshTarget({required this.user, required this.host, required this.port});

  final String user;
  final String host;
  final int port;

  String get _dest => shellQuote('${user.trim()}@${host.trim()}');
  String get _port => port == 22 ? '' : ' -p $port';
}

/// Interactive login; paste the OTP at the password prompt.
String sshOtpCommand(SshTarget t) =>
    'ssh${t._port} -o PreferredAuthentications=keyboard-interactive '
    '-o PubkeyAuthentication=no ${t._dest}';

/// Non-interactive login with the OTP fed through sshpass (env, not argv).
String sshOtpSshpassCommand(SshTarget t, String otp) =>
    'SSHPASS=${shellQuote(otp)} sshpass -e ${sshOtpCommand(t)}';

/// Login with a private key and the certificate Vault signed for it.
/// [certPath] is optional: ssh finds `<key>-cert.pub` on its own.
String sshCertCommand(SshTarget t, String keyPath, {String? certPath}) {
  final cert = certPath == null || certPath.trim().isEmpty
      ? ''
      : ' -o CertificateFile=${shellQuote(certPath.trim())}';
  return 'ssh${t._port} -i ${shellQuote(keyPath.trim())}$cert ${t._dest}';
}

/// `id_ed25519.pub` -> `id_ed25519`; anything else is returned unchanged.
String privateKeyPathFor(String publicKeyPath) => publicKeyPath.endsWith('.pub')
    ? publicKeyPath.substring(0, publicKeyPath.length - 4)
    : publicKeyPath;
