import 'dart:io';

import '../models/certificate_config.dart';

class CertificateAddressParser {
  CertificateAddressParser._();

  static const List<String> localDefaults = [
    'localhost',
    '127.0.0.1',
    '::1',
  ];

  static ParsedCertificateAddresses parse(
    String input, {
    bool includeLocalDefaults = true,
  }) {
    final rawTokens = input
        .split(RegExp(r'[\s,;]+'))
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty)
        .toList();

    final addresses = <CertificateAddress>[];
    final invalid = <String>[];
    final seen = <String>{};

    void addToken(String token, {bool isDefault = false}) {
      final normalized = _extractHost(token);
      if (normalized.isEmpty) {
        if (!isDefault) invalid.add(token);
        return;
      }

      final ip = InternetAddress.tryParse(normalized);
      if (ip != null) {
        final key = 'ip:${ip.address}';
        if (seen.add(key)) {
          addresses.add(CertificateAddress(
            value: ip.address,
            isIp: true,
            isDefault: isDefault,
          ));
        }
        return;
      }

      if (RegExp(r'^\d+(?:\.\d+){3}$').hasMatch(normalized)) {
        if (!isDefault) invalid.add(token);
        return;
      }

      final dnsName = normalized.toLowerCase();
      if (_isValidDnsName(dnsName)) {
        final key = 'dns:$dnsName';
        if (seen.add(key)) {
          addresses.add(CertificateAddress(
            value: dnsName,
            isIp: false,
            isDefault: isDefault,
          ));
        }
        return;
      }

      if (!isDefault) invalid.add(token);
    }

    if (includeLocalDefaults) {
      for (final token in localDefaults) {
        addToken(token, isDefault: true);
      }
    }

    for (final token in rawTokens) {
      addToken(token);
    }

    return ParsedCertificateAddresses(
      addresses: addresses,
      invalidTokens: invalid,
    );
  }

  static bool isValidIp(String value) {
    return InternetAddress.tryParse(value.trim()) != null;
  }

  static String _extractHost(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return '';

    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      return uri.host;
    }

    if (value.startsWith('[')) {
      final end = value.indexOf(']');
      if (end > 1) {
        return value.substring(1, end);
      }
    }

    final slash = value.indexOf('/');
    if (slash >= 0) {
      value = value.substring(0, slash);
    }

    final colonCount = ':'.allMatches(value).length;
    if (colonCount == 1) {
      final parts = value.split(':');
      if (parts.length == 2 && int.tryParse(parts.last) != null) {
        value = parts.first;
      }
    }

    return value.trim();
  }

  static bool _isValidDnsName(String value) {
    if (value.isEmpty || value.length > 253) return false;
    if (value.startsWith('.') || value.endsWith('.')) return false;

    final labels = value.split('.');
    for (final label in labels) {
      if (label.isEmpty || label.length > 63) return false;
      if (label.startsWith('-') || label.endsWith('-')) return false;
      if (!RegExp(r'^[a-z0-9-]+$').hasMatch(label)) return false;
    }
    return true;
  }
}
