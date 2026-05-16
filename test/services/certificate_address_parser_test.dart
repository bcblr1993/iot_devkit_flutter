import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/services/certificate_address_parser.dart';

void main() {
  group('CertificateAddressParser', () {
    test('parses IPs, domains, URLs, and removes duplicates', () {
      final parsed = CertificateAddressParser.parse(
        'https://tb.local:443, mqtt.local 192.168.1.10 [::1]:8883 tb.local',
        includeLocalDefaults: false,
      );

      expect(parsed.invalidTokens, isEmpty);
      expect(
        parsed.dnsNames.map((address) => address.value),
        ['tb.local', 'mqtt.local'],
      );
      expect(
        parsed.ips.map((address) => address.value),
        ['192.168.1.10', '::1'],
      );
    });

    test('includes local defaults when requested', () {
      final parsed =
          CertificateAddressParser.parse('', includeLocalDefaults: true);

      expect(parsed.invalidTokens, isEmpty);
      expect(parsed.dnsNames.map((address) => address.value), ['localhost']);
      expect(parsed.ips.map((address) => address.value), ['127.0.0.1', '::1']);
    });

    test('reports invalid address tokens', () {
      final parsed = CertificateAddressParser.parse(
        'tb.local bad_host 192.168.1.300',
        includeLocalDefaults: false,
      );

      expect(parsed.dnsNames.map((address) => address.value), ['tb.local']);
      expect(parsed.invalidTokens, ['bad_host', '192.168.1.300']);
    });
  });
}
