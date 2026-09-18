import 'package:flutter_test/flutter_test.dart';
import 'package:transikey/core/utils/ssh_connect_command.dart';

void main() {
  const dev = SshTarget(user: 'ubuntu', host: '127.0.0.1', port: 2222);
  const prod = SshTarget(user: 'ops', host: 'bastion.example', port: 22);

  test('the OTP command forces keyboard-interactive and skips keys', () {
    expect(
      sshOtpCommand(dev),
      "ssh -p 2222 -o PreferredAuthentications=keyboard-interactive "
      "-o PubkeyAuthentication=no 'ubuntu@127.0.0.1'",
    );
  });

  test('port 22 is left implicit', () {
    expect(sshOtpCommand(prod), isNot(contains('-p ')));
    expect(sshCertCommand(prod, '~/.ssh/id_ed25519'), isNot(contains('-p ')));
  });

  test('the sshpass form keeps the OTP out of argv', () {
    expect(
      sshOtpSshpassCommand(dev, "otp'1"),
      startsWith("SSHPASS='otp'\\''1' sshpass -e ssh -p 2222"),
    );
  });

  test('the certificate command names key and certificate', () {
    expect(
      sshCertCommand(dev, '~/.ssh/id_ed25519', certPath: '/tmp/id-cert.pub'),
      "ssh -p 2222 -i '~/.ssh/id_ed25519' -o CertificateFile='/tmp/id-cert.pub' "
      "'ubuntu@127.0.0.1'",
    );
    expect(
      sshCertCommand(dev, '~/.ssh/id_ed25519', certPath: ' '),
      isNot(contains('CertificateFile')),
    );
  });

  test('the private key path is derived from the public key path', () {
    expect(
      privateKeyPathFor('/home/a/.ssh/id_ed25519.pub'),
      '/home/a/.ssh/id_ed25519',
    );
    expect(
      privateKeyPathFor('/home/a/.ssh/id_ed25519'),
      '/home/a/.ssh/id_ed25519',
    );
  });
}
