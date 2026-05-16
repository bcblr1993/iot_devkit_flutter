import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/models/certificate_config.dart';
import 'package:iot_devkit/services/certificate_generator_service.dart';
import 'package:path/path.dart' as p;

void main() {
  group('CertificateGeneratorService', () {
    test('generates a shared PEM zip package without external OpenSSL',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('cert_test_');
      try {
        final outputPath = p.join(tempDir.path, 'thingsboard-test.zip');
        const service = CertificateGeneratorService();
        final result = await service.generateZip(
          request: const CertificateGenerationRequest(
            usage: CertificateUsage.shared,
            format: CertificateOutputFormat.pem,
            password: 'thingsboard',
            addressText: 'tb.local, mqtt.local, 127.0.0.1',
            hostsBindingIp: '127.0.0.1',
          ),
          outputPath: outputPath,
        );

        expect(result.zipPath, outputPath);
        expect(await File(outputPath).exists(), isTrue);

        final archive = ZipDecoder().decodeBytes(
          await File(outputPath).readAsBytes(),
        );
        final names = archive.files.map((file) => file.name).toList();

        expect(
          names,
          containsAll([
            'server.pem',
            'server_key.pem',
            'cafile.pem',
            'thingsboard.env',
            'hosts.example.txt',
            'README.md',
          ]),
        );

        final envFile =
            archive.files.firstWhere((file) => file.name == 'thingsboard.env');
        final envText = String.fromCharCodes(envFile.content as List<int>);
        expect(envText, contains('SSL_ENABLED=true'));
        expect(envText, contains('MQTT_SSL_ENABLED=true'));
        expect(envText, isNot(contains('SSL_PEM_KEY_PASSWORD')));
        expect(envText, isNot(contains('MQTT_SSL_PEM_KEY_PASSWORD')));

        final certFile =
            archive.files.firstWhere((file) => file.name == 'server.pem');
        final certText = String.fromCharCodes(certFile.content as List<int>);
        final firstCertPem = RegExp(
          r'-----BEGIN CERTIFICATE-----[\s\S]+?-----END CERTIFICATE-----',
        ).firstMatch(certText)!.group(0)!;
        final certData = X509Utils.x509CertificateFromPem(firstCertPem);
        expect(certData.tbsCertificate?.extensions?.subjectAlternativNames,
            containsAll(['tb.local', 'mqtt.local', '127.0.0.1']));
        expect(certData.tbsCertificate?.extensions?.extKeyUsage,
            contains(ExtendedKeyUsage.SERVER_AUTH));
      } finally {
        await tempDir.delete(recursive: true);
      }
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('generates a password protected PKCS12 package', () async {
      final tempDir = await Directory.systemTemp.createTemp('cert_test_');
      try {
        final outputPath = p.join(tempDir.path, 'thingsboard-p12-test.zip');
        const service = CertificateGeneratorService();
        await service.generateZip(
          request: const CertificateGenerationRequest(
            usage: CertificateUsage.mqtts,
            format: CertificateOutputFormat.pkcs12,
            password: 'thingsboard',
            addressText: 'mqtt.local, 10.0.0.8',
          ),
          outputPath: outputPath,
        );

        final archive = ZipDecoder().decodeBytes(
          await File(outputPath).readAsBytes(),
        );
        final names = archive.files.map((file) => file.name).toList();
        expect(names, containsAll(['mqttserver.p12', 'cafile.pem']));

        final store =
            archive.files.firstWhere((file) => file.name == 'mqttserver.p12');
        final pems = Pkcs12Utils.parsePkcs12(
          Uint8List.fromList(store.content as List<int>),
          password: 'thingsboard',
        );
        expect(pems.any((pem) => pem.contains('BEGIN PRIVATE KEY')), isTrue);
        expect(pems.where((pem) => pem.contains('BEGIN CERTIFICATE')).length,
            greaterThanOrEqualTo(1));
      } finally {
        await tempDir.delete(recursive: true);
      }
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
