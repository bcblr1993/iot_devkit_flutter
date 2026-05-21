import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/models/certificate_config.dart';
import 'package:iot_devkit/services/certificate_endpoint_verifier.dart';
import 'package:iot_devkit/services/certificate_generator_service.dart';
import 'package:path/path.dart' as p;

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
  });
}
