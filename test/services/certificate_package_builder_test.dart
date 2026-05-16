import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/models/certificate_config.dart';
import 'package:iot_devkit/services/certificate_address_parser.dart';
import 'package:iot_devkit/services/certificate_package_builder.dart';

void main() {
  group('CertificatePackageBuilder', () {
    test('builds shared PEM package names and env config', () {
      const request = CertificateGenerationRequest(
        usage: CertificateUsage.shared,
        format: CertificateOutputFormat.pem,
        password: 'secret',
        addressText: 'tb.local,192.168.1.10',
      );
      final parsed = CertificateAddressParser.parse(request.addressText);
      final plan = CertificatePackageBuilder.buildPlan(
        request: request,
        addresses: parsed,
        now: DateTime(2026, 5, 15, 10, 30),
      );

      expect(plan.zipFileName, 'thingsboard-https-mqtts-pem-20260515.zip');
      expect(plan.fileNames,
          containsAll(['server.pem', 'server_key.pem', 'cafile.pem']));
      expect(plan.envText, contains('SSL_ENABLED=true'));
      expect(plan.envText, contains('MQTT_SSL_ENABLED=true'));
      expect(plan.envText, contains('SSL_PEM_CERT=server.pem'));
      expect(plan.envText, contains('MQTT_SSL_PEM_CERT=server.pem'));
      expect(plan.envText, isNot(contains('SSL_PEM_KEY_PASSWORD')));
      expect(plan.envText, isNot(contains('MQTT_SSL_PEM_KEY_PASSWORD')));
      expect(plan.hostsText, contains('tb.local'));
    });

    test('builds MQTTS PKCS12 package names and env config', () {
      const request = CertificateGenerationRequest(
        usage: CertificateUsage.mqtts,
        format: CertificateOutputFormat.pkcs12,
        password: 'secret',
        addressText: 'mqtt.local',
      );
      final parsed = CertificateAddressParser.parse(request.addressText);
      final plan = CertificatePackageBuilder.buildPlan(
        request: request,
        addresses: parsed,
        now: DateTime(2026, 5, 15),
      );

      expect(plan.fileNames, containsAll(['mqttserver.p12', 'cafile.pem']));
      expect(plan.envText, contains('MQTT_SSL_CREDENTIALS_TYPE=KEYSTORE'));
      expect(plan.envText, contains('MQTT_SSL_KEY_STORE_TYPE=PKCS12'));
      expect(plan.envText, contains('MQTT_SSL_KEY_ALIAS=mqttserver'));
      expect(plan.envText, isNot(contains('\nSSL_ENABLED=true')));
    });
  });
}
