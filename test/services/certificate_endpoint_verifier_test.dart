import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/models/certificate_config.dart';
import 'package:iot_devkit/services/certificate_endpoint_verifier.dart';
import 'package:iot_devkit/services/certificate_generator_service.dart';
import 'package:path/path.dart' as p;

class _FakeX509Certificate implements X509Certificate {
  @override
  final String subject;

  const _FakeX509Certificate({this.subject = '/CN=localhost/O=IoT DevKit'});

  @override
  Uint8List get der => Uint8List(0);

  @override
  DateTime get endValidity => DateTime(2036);

  @override
  String get issuer => '/CN=IoT DevKit Local Root CA/O=IoT DevKit';

  @override
  String get pem => '';

  @override
  Uint8List get sha1 => Uint8List(0);

  @override
  DateTime get startValidity => DateTime(2026);
}

void main() {
  group('CertificateEndpointVerifier', () {
    test('parses DNS and IP SAN entries from generated certificates', () async {
      final tempDir = await Directory.systemTemp.createTemp('cert_verify_');
      try {
        final outputPath = p.join(tempDir.path, 'thingsboard-test.zip');
        const service = CertificateGeneratorService();
        await service.generateZip(
          request: const CertificateGenerationRequest(
            usage: CertificateUsage.shared,
            format: CertificateOutputFormat.pem,
            password: '',
            addressText: 'tb.local,10.8.0.219',
          ),
          outputPath: outputPath,
        );

        final archive = ZipDecoder().decodeBytes(
          await File(outputPath).readAsBytes(),
        );
        final certFile =
            archive.files.firstWhere((file) => file.name == 'server.pem');
        final certText = String.fromCharCodes(certFile.content as List<int>);
        final firstCertPem = RegExp(
          r'-----BEGIN CERTIFICATE-----[\s\S]+?-----END CERTIFICATE-----',
        ).firstMatch(certText)!.group(0)!;

        final sans =
            CertificateEndpointVerifier.parseSubjectAltNames(firstCertPem);

        expect(sans, containsAll(['DNS: tb.local', 'IP: 10.8.0.219']));
        expect(sans, containsAll(['DNS: localhost', 'IP: 127.0.0.1']));
      } finally {
        await tempDir.delete(recursive: true);
      }
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('matches DNS and IP hosts against parsed SAN entries', () {
      const cert = _FakeX509Certificate(
        subject: '/CN=192.168.152.130/O=IoT DevKit',
      );
      const sans = <String>[
        'DNS: localhost',
        'DNS: *.iot.local',
        'IP: 127.0.0.1',
        'IP: ::1',
        'IP: 192.168.152.130',
      ];

      expect(
        CertificateEndpointVerifier.hostMatchesCertificate(
          '192.168.152.130',
          cert,
          sans,
        ),
        isTrue,
      );
      expect(
        CertificateEndpointVerifier.hostMatchesCertificate(
          'localhost',
          cert,
          sans,
        ),
        isTrue,
      );
      expect(
        CertificateEndpointVerifier.hostMatchesCertificate(
          'tb.iot.local',
          cert,
          sans,
        ),
        isTrue,
      );
      expect(
        CertificateEndpointVerifier.hostMatchesCertificate(
          '::1',
          cert,
          sans,
        ),
        isTrue,
      );
      expect(
        CertificateEndpointVerifier.hostMatchesCertificate(
          '[0:0:0:0:0:0:0:1]',
          cert,
          sans,
        ),
        isTrue,
      );
      expect(
        CertificateEndpointVerifier.hostMatchesCertificate(
          '192.168.152.131',
          cert,
          sans,
        ),
        isFalse,
      );
    });

    test('falls back to CN for both slash and comma DN formats when SAN is empty', () {
      const slashCert = _FakeX509Certificate(
        subject: '/CN=192.168.152.130/O=IoT DevKit',
      );
      const commaCert = _FakeX509Certificate(
        subject: 'CN=tb.local, O=IoT DevKit',
      );

      expect(
        CertificateEndpointVerifier.hostMatchesCertificate(
          '192.168.152.130',
          slashCert,
          const [],
        ),
        isTrue,
      );
      expect(
        CertificateEndpointVerifier.hostMatchesCertificate(
          'tb.local',
          commaCert,
          const [],
        ),
        isTrue,
      );
      expect(
        CertificateEndpointVerifier.hostMatchesCertificate(
          'other.local',
          slashCert,
          const [],
        ),
        isFalse,
      );
    });

    test('verifies live TLS endpoint and reports hostMatchesCertificate true', () async {
      final tempDir = await Directory.systemTemp.createTemp('cert_live_verify_');
      SecureServerSocket? server;
      StreamSubscription<SecureSocket>? subscription;
      try {
        final outputPath = p.join(tempDir.path, 'thingsboard-test.zip');
        const generator = CertificateGeneratorService();
        await generator.generateZip(
          request: const CertificateGenerationRequest(
            usage: CertificateUsage.https,
            format: CertificateOutputFormat.pem,
            password: '',
            addressText: '127.0.0.1',
          ),
          outputPath: outputPath,
        );

        final archive = ZipDecoder().decodeBytes(
          await File(outputPath).readAsBytes(),
        );
        final certBytes = archive.files
            .firstWhere((file) => file.name == 'server.pem')
            .content as List<int>;
        final keyBytes = archive.files
            .firstWhere((file) => file.name == 'server_key.pem')
            .content as List<int>;

        final context = SecurityContext()
          ..useCertificateChainBytes(certBytes)
          ..usePrivateKeyBytes(keyBytes);

        server = await SecureServerSocket.bind(
          InternetAddress.loopbackIPv4,
          0,
          context,
        );
        subscription = server.listen(
          (socket) => socket.destroy(),
          onError: (_) {},
        );

        const verifier = CertificateEndpointVerifier();
        final result = await verifier.verify(
          host: '127.0.0.1',
          port: server.port,
        );

        expect(result.tlsAvailable, isTrue);
        expect(result.hostMatchesCertificate, isTrue);
        expect(result.status, CertificateEndpointStatus.readyUntrusted);
      } finally {
        await subscription?.cancel();
        await server?.close();
        await tempDir.delete(recursive: true);
      }
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
