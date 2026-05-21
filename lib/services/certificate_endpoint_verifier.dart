import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class CertificateEndpointVerificationResult {
  final String host;
  final int port;
  final bool tlsAvailable;
  final bool plainHttpAvailable;
  final bool systemTrusted;
  final bool hostMatchesCertificate;
  final int? httpStatusCode;
  final X509Certificate? certificate;
  final List<String> subjectAltNames;
  final String? tlsError;
  final String? httpError;

  const CertificateEndpointVerificationResult({
    required this.host,
    required this.port,
    required this.tlsAvailable,
    required this.plainHttpAvailable,
    required this.systemTrusted,
    required this.hostMatchesCertificate,
    required this.httpStatusCode,
    required this.certificate,
    required this.subjectAltNames,
    required this.tlsError,
    required this.httpError,
  });

  bool get hasCertificate => certificate != null;

  CertificateEndpointStatus get status {
    if (tlsAvailable && hostMatchesCertificate) {
      return systemTrusted
          ? CertificateEndpointStatus.readyTrusted
          : CertificateEndpointStatus.readyUntrusted;
    }
    if (tlsAvailable && !hostMatchesCertificate) {
      return CertificateEndpointStatus.hostMismatch;
    }
    if (!tlsAvailable && plainHttpAvailable) {
      return CertificateEndpointStatus.plainHttpOnly;
    }
    return CertificateEndpointStatus.unreachable;
  }
}

enum CertificateEndpointStatus {
  readyTrusted,
  readyUntrusted,
  hostMismatch,
  plainHttpOnly,
  unreachable,
}

class CertificateEndpointVerifier {
  const CertificateEndpointVerifier();

  Future<CertificateEndpointVerificationResult> verify({
    required String host,
    required int port,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final normalizedHost = host.trim();
    var tlsAvailable = false;
    var systemTrusted = false;
    Object? tlsError;
    X509Certificate? certificate;

    try {
      final socket = await SecureSocket.connect(
        normalizedHost,
        port,
        timeout: timeout,
      );
      certificate = socket.peerCertificate;
      systemTrusted = true;
      tlsAvailable = true;
      socket.destroy();
    } catch (e) {
      tlsError = e;
      X509Certificate? untrustedCertificate;
      try {
        final socket = await SecureSocket.connect(
          normalizedHost,
          port,
          timeout: timeout,
          onBadCertificate: (cert) {
            untrustedCertificate = cert;
            return true;
          },
        );
        certificate = socket.peerCertificate ?? untrustedCertificate;
        tlsAvailable = true;
        socket.destroy();
      } catch (secondError) {
        tlsError = secondError;
      }
    }

    var plainHttpAvailable = false;
    int? httpStatusCode;
    Object? httpError;
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.get(normalizedHost, port, '/').timeout(
            timeout,
          );
      final response = await request.close().timeout(timeout);
      httpStatusCode = response.statusCode;
      plainHttpAvailable = true;
      await response.drain<void>();
    } catch (e) {
      httpError = e;
    } finally {
      client.close(force: true);
    }

    final sans = certificate == null
        ? const <String>[]
        : CertificateEndpointVerifier.parseSubjectAltNames(certificate.pem);
    final hostMatches = certificate != null &&
        CertificateEndpointVerifier.hostMatchesCertificate(
          normalizedHost,
          certificate,
          sans,
        );

    return CertificateEndpointVerificationResult(
      host: normalizedHost,
      port: port,
      tlsAvailable: tlsAvailable,
      plainHttpAvailable: plainHttpAvailable,
      systemTrusted: systemTrusted,
      hostMatchesCertificate: hostMatches,
      httpStatusCode: httpStatusCode,
      certificate: certificate,
      subjectAltNames: sans,
      tlsError: tlsError?.toString(),
      httpError: httpError?.toString(),
    );
  }

  static bool hostMatchesCertificate(
    String host,
    X509Certificate certificate,
    List<String> subjectAltNames,
  ) {
    final normalizedHost = host.trim().toLowerCase();
    if (normalizedHost.isEmpty) return false;

    if (subjectAltNames.isNotEmpty) {
      return subjectAltNames.any((name) {
        final normalizedName = name.toLowerCase();
        if (normalizedName.startsWith('ip:')) {
          return normalizedName.substring(3) == normalizedHost;
        }
        if (!normalizedName.startsWith('dns:')) return false;
        final dnsName = normalizedName.substring(4);
        return _dnsMatches(normalizedHost, dnsName);
      });
    }

    final cn = _extractCommonName(certificate.subject);
    return cn != null && _dnsMatches(normalizedHost, cn.toLowerCase());
  }

  static List<String> parseSubjectAltNames(String pem) {
    final der = _pemToDer(pem);
    if (der == null) return const [];

    final oidIndex = _indexOfBytes(der, const [0x06, 0x03, 0x55, 0x1d, 0x11]);
    if (oidIndex < 0) return const [];

    var cursor = oidIndex + 5;
    while (cursor < der.length && der[cursor] != 0x04) {
      cursor += 1;
    }
    if (cursor >= der.length) return const [];

    final octet = _readTlv(der, cursor);
    if (octet == null) return const [];

    final generalNamesBytes = der.sublist(octet.valueStart, octet.valueEnd);
    final sequence = _readTlv(generalNamesBytes, 0);
    if (sequence == null || sequence.tag != 0x30) return const [];

    final names = <String>[];
    var nameCursor = sequence.valueStart;
    while (nameCursor < sequence.valueEnd) {
      final name = _readTlv(generalNamesBytes, nameCursor);
      if (name == null) break;
      final value = generalNamesBytes.sublist(name.valueStart, name.valueEnd);
      if (name.tag == 0x82) {
        names.add('DNS: ${ascii.decode(value, allowInvalid: true)}');
      } else if (name.tag == 0x87) {
        final ip = _decodeIp(value);
        if (ip != null) names.add('IP: $ip');
      }
      nameCursor = name.nextOffset;
    }

    return names;
  }

  static bool _dnsMatches(String host, String dnsName) {
    if (!dnsName.startsWith('*.')) return host == dnsName;
    final suffix = dnsName.substring(1);
    return host.endsWith(suffix) &&
        host.substring(0, host.length - suffix.length).contains('.') == false;
  }

  static String? _extractCommonName(String subject) {
    final match = RegExp(r'CN\s*=\s*([^,]+)').firstMatch(subject);
    return match?.group(1)?.trim();
  }

  static Uint8List? _pemToDer(String pem) {
    final body = pem
        .split('\n')
        .where((line) => !line.startsWith('-----'))
        .join()
        .trim();
    if (body.isEmpty) return null;
    return Uint8List.fromList(base64.decode(body));
  }

  static int _indexOfBytes(Uint8List bytes, List<int> pattern) {
    for (var i = 0; i <= bytes.length - pattern.length; i++) {
      var matched = true;
      for (var j = 0; j < pattern.length; j++) {
        if (bytes[i + j] != pattern[j]) {
          matched = false;
          break;
        }
      }
      if (matched) return i;
    }
    return -1;
  }

  static _Tlv? _readTlv(Uint8List bytes, int offset) {
    if (offset + 2 > bytes.length) return null;
    final tag = bytes[offset];
    var lengthByte = bytes[offset + 1];
    var lengthStart = offset + 2;
    var length = 0;

    if ((lengthByte & 0x80) == 0) {
      length = lengthByte;
    } else {
      final lengthBytes = lengthByte & 0x7f;
      if (lengthBytes == 0 || lengthStart + lengthBytes > bytes.length) {
        return null;
      }
      for (var i = 0; i < lengthBytes; i++) {
        length = (length << 8) | bytes[lengthStart + i];
      }
      lengthStart += lengthBytes;
    }

    final valueEnd = lengthStart + length;
    if (valueEnd > bytes.length) return null;
    return _Tlv(
      tag: tag,
      valueStart: lengthStart,
      valueEnd: valueEnd,
      nextOffset: valueEnd,
    );
  }

  static String? _decodeIp(List<int> bytes) {
    if (bytes.length == 4) {
      return bytes.join('.');
    }
    if (bytes.length != 16) return null;

    final parts = <String>[];
    for (var i = 0; i < bytes.length; i += 2) {
      parts.add(((bytes[i] << 8) | bytes[i + 1]).toRadixString(16));
    }
    return _compressIpv6(parts);
  }

  static String _compressIpv6(List<String> parts) {
    var bestStart = -1;
    var bestLength = 0;
    var currentStart = -1;
    var currentLength = 0;

    for (var i = 0; i < parts.length; i++) {
      if (parts[i] == '0') {
        currentStart = currentStart == -1 ? i : currentStart;
        currentLength += 1;
      } else {
        if (currentLength > bestLength) {
          bestStart = currentStart;
          bestLength = currentLength;
        }
        currentStart = -1;
        currentLength = 0;
      }
    }
    if (currentLength > bestLength) {
      bestStart = currentStart;
      bestLength = currentLength;
    }

    if (bestLength < 2) return parts.join(':');

    final before = parts.take(bestStart).join(':');
    final after = parts.skip(bestStart + bestLength).join(':');
    if (before.isEmpty && after.isEmpty) return '::';
    if (before.isEmpty) return '::$after';
    if (after.isEmpty) return '$before::';
    return '$before::$after';
  }
}

class _Tlv {
  final int tag;
  final int valueStart;
  final int valueEnd;
  final int nextOffset;

  const _Tlv({
    required this.tag,
    required this.valueStart,
    required this.valueEnd,
    required this.nextOffset,
  });
}
