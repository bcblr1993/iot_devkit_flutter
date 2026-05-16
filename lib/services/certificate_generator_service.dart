import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:path/path.dart' as p;
import 'package:pointycastle/asn1.dart';

import '../models/certificate_config.dart';
import 'certificate_address_parser.dart';
import 'certificate_package_builder.dart';

class CertificateGenerationException implements Exception {
  final String message;

  const CertificateGenerationException(this.message);

  @override
  String toString() => message;
}

class CertificateGeneratorService {
  const CertificateGeneratorService();

  Future<CertificateGenerationResult> generateZip({
    required CertificateGenerationRequest request,
    required String outputPath,
  }) async {
    _validateRequest(request);

    final parsedAddresses = CertificateAddressParser.parse(
      request.addressText,
      includeLocalDefaults: request.includeLocalDefaults,
    );

    if (parsedAddresses.hasInvalid) {
      throw CertificateGenerationException(
        '证书绑定地址无效: ${parsedAddresses.invalidTokens.join(', ')}',
      );
    }
    if (!parsedAddresses.hasValid) {
      throw const CertificateGenerationException('至少需要一个 IP 或域名。');
    }

    final tempDir = await Directory.systemTemp.createTemp('iot_devkit_cert_');
    try {
      final plan = CertificatePackageBuilder.buildPlan(
        request: request,
        addresses: parsedAddresses,
        now: DateTime.now(),
      );
      final files = CertificatePackageBuilder.fileNamesFor(request);

      final caCertPath = p.join(tempDir.path, files['ca']!);
      final caPair = CryptoUtils.generateRSAKeyPair();
      final caPrivateKey = caPair.privateKey as RSAPrivateKey;
      final caPublicKey = caPair.publicKey as RSAPublicKey;
      final caSubject = {
        'CN': 'IoT DevKit Local Root CA',
        'O': 'IoT DevKit',
      };
      final caCertPem = _generateCertificatePem(
        issuer: caSubject,
        subject: caSubject,
        subjectPublicKey: caPublicKey,
        signerPrivateKey: caPrivateKey,
        serialNumber: BigInt.from(DateTime.now().microsecondsSinceEpoch),
        validDays: request.validDays,
        isCa: true,
      );

      final serverPair = CryptoUtils.generateRSAKeyPair();
      final serverPrivateKey = serverPair.privateKey as RSAPrivateKey;
      final serverPublicKey = serverPair.publicKey as RSAPublicKey;
      final serverPrivateKeyPem =
          CryptoUtils.encodeRSAPrivateKeyToPem(serverPrivateKey);
      final serverSubject = {
        'CN': _commonName(parsedAddresses),
        'O': 'IoT DevKit',
      };
      final serverCertPem = _generateCertificatePem(
        issuer: caSubject,
        subject: serverSubject,
        subjectPublicKey: serverPublicKey,
        signerPrivateKey: caPrivateKey,
        serialNumber: BigInt.from(DateTime.now().microsecondsSinceEpoch + 1),
        validDays: request.validDays,
        isCa: false,
        addresses: parsedAddresses.addresses,
      );

      await File(caCertPath).writeAsString(caCertPem);

      if (request.format == CertificateOutputFormat.pem) {
        final certFilePath = p.join(tempDir.path, files['certificate']!);
        final keyFilePath = p.join(tempDir.path, files['privateKey']!);
        final certChain = StringBuffer()
          ..write(serverCertPem)
          ..write('\n')
          ..write(caCertPem);
        await File(certFilePath).writeAsString(certChain.toString());
        await File(keyFilePath).writeAsString(serverPrivateKeyPem);
      } else {
        final storePath = p.join(tempDir.path, files['keystore']!);
        final pkcs12Bytes = Pkcs12Utils.generatePkcs12(
          serverPrivateKeyPem,
          [serverCertPem, caCertPem],
          password: request.password,
          friendlyName: _keyAlias(request.usage),
        );
        await File(storePath).writeAsBytes(pkcs12Bytes, flush: true);
      }

      await File(p.join(tempDir.path, 'thingsboard.env'))
          .writeAsString(plan.envText);
      await File(p.join(tempDir.path, 'hosts.example.txt'))
          .writeAsString(plan.hostsText);
      await File(p.join(tempDir.path, 'README.md'))
          .writeAsString(plan.readmeText);

      await _writeZip(
        sourceDir: tempDir,
        fileNames: plan.fileNames,
        outputPath: outputPath,
      );

      return CertificateGenerationResult(
        zipPath: outputPath,
        plan: plan,
        parsedAddresses: parsedAddresses,
      );
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {
        // Best-effort cleanup only.
      }
    }
  }

  void _validateRequest(CertificateGenerationRequest request) {
    if (request.format == CertificateOutputFormat.pkcs12 &&
        request.password.trim().isEmpty) {
      throw const CertificateGenerationException('证书密码不能为空。');
    }
    if (request.hostsBindingIp.trim().isNotEmpty &&
        !CertificateAddressParser.isValidIp(request.hostsBindingIp.trim())) {
      throw const CertificateGenerationException('hosts 绑定 IP 不是有效 IP。');
    }
    if (request.validDays < 1) {
      throw const CertificateGenerationException('证书有效期必须大于 0 天。');
    }
  }

  Future<void> _writeZip({
    required Directory sourceDir,
    required List<String> fileNames,
    required String outputPath,
  }) async {
    final archive = Archive();
    for (final fileName in fileNames) {
      final file = File(p.join(sourceDir.path, fileName));
      if (!await file.exists()) continue;

      final bytes = await file.readAsBytes();
      archive.addFile(ArchiveFile(
        fileName,
        bytes.length,
        bytes,
      ));
    }

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw const CertificateGenerationException('ZIP 包生成失败。');
    }

    await File(outputPath).writeAsBytes(zipBytes, flush: true);
  }

  String _generateCertificatePem({
    required Map<String, String> issuer,
    required Map<String, String> subject,
    required RSAPublicKey subjectPublicKey,
    required RSAPrivateKey signerPrivateKey,
    required BigInt serialNumber,
    required int validDays,
    required bool isCa,
    List<CertificateAddress> addresses = const [],
  }) {
    final algorithm = _algorithmIdentifier();
    final tbs = ASN1Sequence()
      ..add(_explicitVersion())
      ..add(ASN1Integer(serialNumber))
      ..add(algorithm)
      ..add(X509Utils.encodeDN(issuer))
      ..add(_validity(validDays))
      ..add(X509Utils.encodeDN(subject))
      ..add(_subjectPublicKeyInfo(subjectPublicKey))
      ..add(_extensions(isCa: isCa, addresses: addresses));

    final signer = Signer('SHA-256/RSA')
      ..init(true, PrivateKeyParameter<RSAPrivateKey>(signerPrivateKey));
    final signature = signer.generateSignature(tbs.encode()) as RSASignature;
    final certificate = ASN1Sequence()
      ..add(tbs)
      ..add(algorithm)
      ..add(ASN1BitString(stringValues: signature.bytes));

    return _pem('CERTIFICATE', certificate.encode());
  }

  ASN1Object _explicitVersion() {
    final version = ASN1Object(tag: 0xA0);
    version.valueBytes = ASN1Integer.fromtInt(2).encode();
    return version;
  }

  ASN1Sequence _algorithmIdentifier() {
    return ASN1Sequence()
      ..add(ASN1ObjectIdentifier.fromIdentifierString('1.2.840.113549.1.1.11'))
      ..add(ASN1Null());
  }

  ASN1Sequence _validity(int validDays) {
    final now = DateTime.now().toUtc();
    return ASN1Sequence()
      ..add(ASN1UtcTime(now))
      ..add(ASN1UtcTime(now.add(Duration(days: validDays))));
  }

  ASN1Sequence _subjectPublicKeyInfo(RSAPublicKey publicKey) {
    final encryption = ASN1Sequence()
      ..add(ASN1ObjectIdentifier.fromIdentifierString('1.2.840.113549.1.1.1'))
      ..add(ASN1Null());
    final key = ASN1Sequence()
      ..add(ASN1Integer(publicKey.modulus))
      ..add(ASN1Integer(publicKey.exponent));
    return ASN1Sequence()
      ..add(encryption)
      ..add(ASN1BitString(stringValues: key.encode()));
  }

  ASN1Object _extensions({
    required bool isCa,
    required List<CertificateAddress> addresses,
  }) {
    final extensions = ASN1Sequence()
      ..add(_extension(
        oid: '2.5.29.19',
        critical: true,
        value: _basicConstraints(isCa).encode(),
      ))
      ..add(_extension(
        oid: '2.5.29.15',
        critical: true,
        value: _keyUsage(isCa ? [5, 6] : [0, 2]).encode(),
      ));

    if (!isCa) {
      extensions
        ..add(_extension(
          oid: '2.5.29.37',
          value: _extendedKeyUsage().encode(),
        ))
        ..add(_extension(
          oid: '2.5.29.17',
          value: _subjectAltName(addresses).encode(),
        ));
    }

    final wrapper = ASN1Object(tag: 0xA3);
    wrapper.valueBytes = extensions.encode();
    return wrapper;
  }

  ASN1Sequence _extension({
    required String oid,
    required Uint8List value,
    bool critical = false,
  }) {
    final extension = ASN1Sequence()
      ..add(ASN1ObjectIdentifier.fromIdentifierString(oid));
    if (critical) {
      extension.add(ASN1Boolean(true));
    }
    extension.add(ASN1OctetString(octets: value));
    return extension;
  }

  ASN1Sequence _basicConstraints(bool isCa) {
    final sequence = ASN1Sequence();
    if (isCa) {
      sequence
        ..add(ASN1Boolean(true))
        ..add(ASN1Integer(BigInt.zero));
    }
    return sequence;
  }

  ASN1BitString _keyUsage(List<int> bitIndexes) {
    var valueBytes = 1;
    for (final index in bitIndexes) {
      valueBytes |= int.parse('8000', radix: 16) >> index;
    }
    return ASN1BitString.fromBytes(Uint8List.fromList([
      3,
      3,
      1,
      (valueBytes & int.parse('ff00', radix: 16)) >> 8,
      valueBytes & int.parse('00ff', radix: 16),
    ]));
  }

  ASN1Sequence _extendedKeyUsage() {
    return ASN1Sequence()
      ..add(ASN1ObjectIdentifier.fromIdentifierString('1.3.6.1.5.5.7.3.1'));
  }

  ASN1Sequence _subjectAltName(List<CertificateAddress> addresses) {
    final sequence = ASN1Sequence();
    for (final address in addresses) {
      if (address.isIp) {
        final ipAddress = ASN1Object(tag: 0x87);
        ipAddress.valueBytes =
            Uint8List.fromList(InternetAddress(address.value).rawAddress);
        sequence.add(ipAddress);
      } else {
        sequence.add(ASN1IA5String(stringValue: address.value, tag: 0x82));
      }
    }
    return sequence;
  }

  String _commonName(ParsedCertificateAddresses addresses) {
    if (addresses.dnsNames.isNotEmpty) {
      return addresses.dnsNames.first.value;
    }
    return addresses.ips.first.value;
  }

  String _pem(String label, List<int> derBytes) {
    final encoded = base64.encode(derBytes);
    final lines = <String>[];
    for (var index = 0; index < encoded.length; index += 64) {
      lines.add(encoded.substring(
        index,
        index + 64 > encoded.length ? encoded.length : index + 64,
      ));
    }
    return '-----BEGIN $label-----\n${lines.join('\n')}\n-----END $label-----\n';
  }

  String _keyAlias(CertificateUsage usage) {
    return switch (usage) {
      CertificateUsage.https => 'tomcat',
      CertificateUsage.mqtts => 'mqttserver',
      CertificateUsage.shared => 'thingsboard',
    };
  }
}
