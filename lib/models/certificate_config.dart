enum CertificateUsage {
  https,
  mqtts,
  shared,
}

enum CertificateOutputFormat {
  pem,
  pkcs12,
}

class CertificateAddress {
  final String value;
  final bool isIp;
  final bool isDefault;

  const CertificateAddress({
    required this.value,
    required this.isIp,
    this.isDefault = false,
  });

  String get label => isIp ? 'IP: $value' : 'DNS: $value';
}

class ParsedCertificateAddresses {
  final List<CertificateAddress> addresses;
  final List<String> invalidTokens;

  const ParsedCertificateAddresses({
    required this.addresses,
    required this.invalidTokens,
  });

  List<CertificateAddress> get ips =>
      addresses.where((address) => address.isIp).toList();

  List<CertificateAddress> get dnsNames =>
      addresses.where((address) => !address.isIp).toList();

  bool get hasInvalid => invalidTokens.isNotEmpty;

  bool get hasValid => addresses.isNotEmpty;
}

class CertificateGenerationRequest {
  final CertificateUsage usage;
  final CertificateOutputFormat format;
  final String password;
  final String addressText;
  final String hostsBindingIp;
  final bool includeLocalDefaults;
  final int validDays;

  const CertificateGenerationRequest({
    required this.usage,
    required this.format,
    required this.password,
    required this.addressText,
    this.hostsBindingIp = '',
    this.includeLocalDefaults = true,
    this.validDays = 3650,
  });
}

class CertificatePackagePlan {
  final List<String> fileNames;
  final String envText;
  final String readmeText;
  final String hostsText;
  final String zipFileName;

  const CertificatePackagePlan({
    required this.fileNames,
    required this.envText,
    required this.readmeText,
    required this.hostsText,
    required this.zipFileName,
  });
}

class CertificateGenerationResult {
  final String zipPath;
  final CertificatePackagePlan plan;
  final ParsedCertificateAddresses parsedAddresses;

  const CertificateGenerationResult({
    required this.zipPath,
    required this.plan,
    required this.parsedAddresses,
  });
}
